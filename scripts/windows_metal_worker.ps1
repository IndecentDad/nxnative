[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InputDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [int]$Jobs = [Environment]::ProcessorCount,
    [string]$MetalExe,
    [string]$MetallibExe
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
function Find-MetalTool([string]$Name, [string]$Explicit) {
    if ($Explicit) { return (Resolve-Path -LiteralPath $Explicit).Path }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $roots = @($env:METAL_DEVELOPER_TOOLS, (Join-Path $env:ProgramFiles 'Apple\Metal Developer Tools 6.2'), (Join-Path $env:ProgramFiles 'Metal Developer Tools 6.2'), (Join-Path $env:ProgramFiles 'Apple\Metal Developer Tools'), (Join-Path $env:ProgramFiles 'Metal Developer Tools')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    foreach ($root in $roots) {
        $found = Get-ChildItem -LiteralPath $root -Filter $Name -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    throw "$Name not found. Set METAL_DEVELOPER_TOOLS or pass its full path."
}
$metal = Find-MetalTool 'metal.exe' $MetalExe
$metallib = Find-MetalTool 'metallib.exe' $MetallibExe
$metalVersion = (& $metal '--version' 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $metalVersion) { throw 'Could not query the selected Metal compiler version.' }
if ($metalVersion -notmatch '32023\.850') { throw "Expected the verified Metal Developer Tools 6.2 compiler build 32023.850; found: $metalVersion. Set METAL_DEVELOPER_TOOLS or pass -MetalExe/-MetallibExe." }
$metalExeSha = (Get-FileHash -LiteralPath $metal -Algorithm SHA256).Hash.ToLowerInvariant()
$metallibExeSha = (Get-FileHash -LiteralPath $metallib -Algorithm SHA256).Hash.ToLowerInvariant()
if (-not ('NXNativeShortPath' -as [type])) {
    Add-Type -TypeDefinition 'using System; using System.Text; using System.Runtime.InteropServices; public static class NXNativeShortPath { [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)] public static extern uint GetShortPathName(string longPath, StringBuilder shortPath, uint bufferSize); }'
}
$tempRoot = Join-Path $env:TEMP 'NXNativeMetal62'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$shortBuffer = New-Object System.Text.StringBuilder 1024
$shortLength = [NXNativeShortPath]::GetShortPathName($tempRoot,$shortBuffer,[uint32]$shortBuffer.Capacity)
if ($shortLength -eq 0 -or $shortLength -ge $shortBuffer.Capacity) { throw 'Could not resolve a local short path for the Metal work directory.' }
$tempRootShort = $shortBuffer.ToString()
if ($tempRootShort -match '\s') { throw "Metal work path contains spaces: $tempRootShort. Set TEMP to a local path without spaces and rerun." }
$manifest = Join-Path $InputDirectory 'manifest.csv'
if (-not (Test-Path -LiteralPath $manifest)) { throw "Missing $manifest" }
$rows = @(Import-Csv -LiteralPath $manifest)
if ($rows.Count -eq 0) { throw 'The compile manifest is empty.' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$resultsDir = Join-Path $OutputDirectory 'results'
$logsDir = Join-Path $OutputDirectory 'logs'
New-Item -ItemType Directory -Force -Path $resultsDir,$logsDir | Out-Null
Remove-Item -LiteralPath (Join-Path $OutputDirectory 'worker-results.jsonl'),(Join-Path $OutputDirectory 'worker-failures.log') -Force -ErrorAction SilentlyContinue
$pool = [RunspaceFactory]::CreateRunspacePool(1,[Math]::Max(1,$Jobs)); $pool.Open()
$pending = [System.Collections.Generic.List[object]]::new()
$worker = {
    param($row,$sourceRoot,$resultsRoot,$logsRoot,$metalPath,$libPath,$metalVersion,$metalExeSha,$metallibExeSha,$tempRootShort)
    $ErrorActionPreference = 'Stop'
    $jsonParser=New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $src = Join-Path $sourceRoot $row.filename
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Source missing: $src" }
    $sha = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($row.source_sha256 -and $sha -ne $row.source_sha256.ToLowerInvariant()) { throw "Source SHA-256 mismatch for $($row.filename)" }
    $srcLocal = Join-Path $tempRootShort ($sha + '.metal'); $air = Join-Path $tempRootShort ($sha + '.air'); $libLocal = Join-Path $tempRootShort ($sha + '.metallib'); $lib = Join-Path $resultsRoot ($sha + '.metallib'); $log = Join-Path $logsRoot ($sha + '.log')
    $flags = @(); if ($row.metal_flags_json) { $flags = @(ConvertFrom-Json -InputObject $row.metal_flags_json) }
    $receiptPath=Join-Path $resultsRoot ($sha+'.json')
    if ((Test-Path -LiteralPath $receiptPath) -and (Test-Path -LiteralPath $lib)) {
        try {
            $old=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
            $bytes=[IO.File]::ReadAllBytes($lib)
            $oldHash=(Get-FileHash -LiteralPath $lib -Algorithm SHA256).Hash.ToLowerInvariant()
            $wantedKeys=[string[]]$jsonParser.DeserializeObject([string]$row.shader_keys)
            $oldKeys=@(); foreach ($entry in @($old.shader_keys)) { if ($entry -is [pscustomobject] -and ($entry.PSObject.Properties.Name -contains 'value')) {$oldKeys += @($entry.value)} else {$oldKeys += $entry} }
            $hasKeys=($wantedKeys.Count -eq 0) -or (@($wantedKeys | Where-Object {$oldKeys -notcontains $_}).Count -eq 0)
            if ($old.status -eq 'ok' -and $old.source_sha256 -eq $sha -and $old.target -eq 'ios18' -and $old.air_target -match '^air64_v\d+-apple-ios18\.0\.0$' -and $old.metal_flags_json -eq $row.metal_flags_json -and $old.reflection_metadata_json -eq $row.reflection_metadata_json -and $old.reflection_files_json -eq $row.reflection_files_json -and $old.compiler_version -eq $metalVersion -and $old.compiler_executable_sha256 -eq $metalExeSha -and $old.metallib_executable_sha256 -eq $metallibExeSha -and $hasKeys -and $bytes.Length -ge 16 -and [Text.Encoding]::ASCII.GetString($bytes,0,4) -eq 'MTLB' -and $oldHash -eq $old.metallib_sha256) {
                return [pscustomobject]@{source_sha256=$sha;shader_keys=$wantedKeys;status='reused';elapsed_seconds=$old.elapsed_seconds;compiler_version=$old.compiler_version;compiler_executable_sha256=$metalExeSha;metallib_executable_sha256=$metallibExeSha;metallib_sha256=$oldHash}
            }
        } catch {}
    }
    Copy-Item -LiteralPath $src -Destination $srcLocal -Force
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $metalArgs = @('-c') + $flags + @($srcLocal,'-o',$air)
    $savedPreference=$ErrorActionPreference
    $haveAir=$false
    if (Test-Path -LiteralPath $air -PathType Leaf) {
        try { $priorAir=[IO.File]::ReadAllBytes($air); $priorTarget=[regex]::Match([Text.Encoding]::ASCII.GetString($priorAir),'air64_v\d+-apple-ios18\.0\.0').Value; if ($priorAir.Length -gt 64 -and $priorTarget) {$haveAir=$true} } catch {}
    }
    if (-not $haveAir) {
        try {
            $ErrorActionPreference='Continue'
            $metalOutput = & $metalPath @metalArgs 2>&1
            $metalExit = $LASTEXITCODE
            [IO.File]::WriteAllLines($log,[string[]]@($metalOutput | ForEach-Object { $_.ToString() }),[Text.UTF8Encoding]::new($false))
        } finally { $ErrorActionPreference=$savedPreference }
        if ($metalExit -ne 0) { throw "metal.exe exit $metalExit; see $log" }
    } else {
        [IO.File]::WriteAllText($log,'Reusing the existing valid iOS 18 AIR intermediate.'+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
    }
    try {
        $ErrorActionPreference='Continue'
        $libOutput = & $libPath $air '-o' $libLocal 2>&1
        $libExit = $LASTEXITCODE
        if ($libOutput) { [IO.File]::AppendAllLines($log,[string[]]@($libOutput | ForEach-Object { $_.ToString() }),[Text.UTF8Encoding]::new($false)) }
    } finally { $ErrorActionPreference=$savedPreference }
    if ($libExit -ne 0 -and $haveAir) {
        try {
            $ErrorActionPreference='Continue'
            $metalOutput = & $metalPath @metalArgs 2>&1
            $metalExit = $LASTEXITCODE
            [IO.File]::AppendAllLines($log,[string[]]@('Existing AIR failed metallib conversion; recompiling this single source.')+@($metalOutput | ForEach-Object { $_.ToString() }),[Text.UTF8Encoding]::new($false))
        } finally { $ErrorActionPreference=$savedPreference }
        if ($metalExit -ne 0) { throw "metal.exe exit $metalExit; see $log" }
        try {
            $ErrorActionPreference='Continue'
            $libOutput = & $libPath $air '-o' $libLocal 2>&1
            $libExit = $LASTEXITCODE
            if ($libOutput) { [IO.File]::AppendAllLines($log,[string[]]@($libOutput | ForEach-Object { $_.ToString() }),[Text.UTF8Encoding]::new($false)) }
        } finally { $ErrorActionPreference=$savedPreference }
    }
    if ($libExit -ne 0) { throw "metallib.exe exit $libExit; see $log" }
    $timer.Stop()
    $airBytes = [IO.File]::ReadAllBytes($air); $airText = [Text.Encoding]::ASCII.GetString($airBytes)
    $target = [regex]::Match($airText,'air64_v\d+-apple-ios18\.0\.0').Value
    if (-not $target) { throw "AIR target is not iOS 18: $($row.filename); see $log" }
    $libBytes = [IO.File]::ReadAllBytes($libLocal)
    if ($libBytes.Length -lt 16 -or [Text.Encoding]::ASCII.GetString($libBytes,0,4) -ne 'MTLB') { throw "Output is not an MTLB library: $($row.filename)" }
    $libSha = (Get-FileHash -LiteralPath $libLocal -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::Copy($libLocal,$lib,$true)
    if ((Get-FileHash -LiteralPath $lib -Algorithm SHA256).Hash.ToLowerInvariant() -ne $libSha) { throw "Network copy hash mismatch for $($row.filename)" }
    $version = $metalVersion
    $shaderKeys = [string[]]$jsonParser.DeserializeObject([string]$row.shader_keys)
    $receipt = [ordered]@{schema=1;shader_keys=$shaderKeys;shader_source=$row.shader_source;stage=$row.stage;source_file=$row.filename;source_sha256=$sha;reflection_metadata_json=$row.reflection_metadata_json;reflection_files_json=$row.reflection_files_json;target='ios18';metal_flags_json=$row.metal_flags_json;compiler='Apple Metal Developer Tools for Windows';compiler_version=$version;compiler_executable_sha256=$metalExeSha;metallib_executable_sha256=$metallibExeSha;air_target=$target;metallib_sha256=$libSha;elapsed_seconds=[Math]::Round($timer.Elapsed.TotalSeconds,3);status='ok'}
    Remove-Item -LiteralPath $srcLocal,$air,$libLocal -Force -ErrorAction SilentlyContinue
    $receiptPath=Join-Path $resultsRoot ($sha+'.json'); [IO.File]::WriteAllText(($receiptPath+'.tmp'),($receipt | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false)); Move-Item -LiteralPath ($receiptPath+'.tmp') -Destination $receiptPath -Force
    [pscustomobject]@{source_sha256=$sha;shader_keys=$shaderKeys;status='ok';elapsed_seconds=$receipt.elapsed_seconds;compiler_version=$version;compiler_executable_sha256=$metalExeSha;metallib_executable_sha256=$metallibExeSha;metallib_sha256=$libSha}
}
try {
    foreach ($row in $rows) {
        $ps=[powershell]::Create(); $ps.RunspacePool=$pool
        [void]$ps.AddScript($worker).AddArgument($row).AddArgument($InputDirectory).AddArgument($resultsDir).AddArgument($logsDir).AddArgument($metal).AddArgument($metallib).AddArgument($metalVersion).AddArgument($metalExeSha).AddArgument($metallibExeSha).AddArgument($tempRootShort)
        $pending.Add([pscustomobject]@{PowerShell=$ps;Handle=$ps.BeginInvoke();Row=$row})
        while ($pending.Count -ge [Math]::Max(1,$Jobs)) {
            $done=$pending | Where-Object {$_.Handle.IsCompleted} | Select-Object -First 1
            if (-not $done) { Start-Sleep -Milliseconds 100; continue }
            try {$done.PowerShell.EndInvoke($done.Handle) | ForEach-Object { $_ | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $OutputDirectory 'worker-results.jsonl') -Encoding UTF8 }}
            catch {"FAILED,$($done.Row.filename),$($_.Exception.Message)" | Add-Content -LiteralPath (Join-Path $OutputDirectory 'worker-failures.log') -Encoding UTF8}
            finally {$done.PowerShell.Dispose();$pending.Remove($done)}
        }
    }
    while ($pending.Count) {
        $done=$pending | Where-Object {$_.Handle.IsCompleted} | Select-Object -First 1
        if (-not $done) {Start-Sleep -Milliseconds 100;continue}
        try {$done.PowerShell.EndInvoke($done.Handle) | ForEach-Object { $_ | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $OutputDirectory 'worker-results.jsonl') -Encoding UTF8}}
        catch {"FAILED,$($done.Row.filename),$($_.Exception.Message)" | Add-Content -LiteralPath (Join-Path $OutputDirectory 'worker-failures.log') -Encoding UTF8}
        finally {$done.PowerShell.Dispose();$pending.Remove($done)}
    }
} finally {$pool.Close();$pool.Dispose()}
$ok=@(Get-Content -LiteralPath (Join-Path $OutputDirectory 'worker-results.jsonl') -ErrorAction SilentlyContinue | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
$failLog=Join-Path $OutputDirectory 'worker-failures.log'
if (Test-Path -LiteralPath $failLog) {throw "Some shaders failed. See $failLog; successful outputs remain in $resultsDir"}
if ($ok.Count -ne $rows.Count) {throw "Expected $($rows.Count) results; got $($ok.Count). Successful outputs remain in $resultsDir"}
if (@($ok | Select-Object -ExpandProperty compiler_executable_sha256 -Unique).Count -ne 1 -or @($ok | Select-Object -ExpandProperty compiler_version -Unique).Count -ne 1 -or @($ok | Select-Object -ExpandProperty metallib_executable_sha256 -Unique).Count -ne 1) { throw 'Results contain mixed Windows Metal compiler configurations.' }
Write-Host "Verified $($ok.Count)/$($rows.Count) iOS Metal libraries with one Windows compiler ($metalVersion; metal SHA-256 $metalExeSha; metallib SHA-256 $metallibExeSha), using $Jobs workers. Results: $resultsDir"
