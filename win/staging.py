"""Local workspace staging for game files on SMB shares."""
import ctypes, hashlib, json, os, re, shutil, sys, tempfile, uuid, zipfile
from pathlib import Path, PureWindowsPath

GAME_EXT = ('.nsp', '.xci', '.nsz', '.xcz')


def is_network_path(path):
    """Recognize UNC paths and mapped Windows network drives."""
    value = os.fspath(path)
    if value.startswith(('\\\\', '//')): return True
    if os.name != 'nt': return False
    drive = PureWindowsPath(value).drive
    if not drive: return False
    try: return ctypes.windll.kernel32.GetDriveTypeW(drive + '\\') == 4  # DRIVE_REMOTE
    except (AttributeError, OSError): return False


def application_root(executable=None, frozen=None):
    """Use the SSD workspace when available, with the existing override and platform fallbacks."""
    frozen = getattr(sys, 'frozen', False) if frozen is None else frozen
    if not frozen and os.environ.get('NXNATIVE_WORKSPACE'):
        return Path(os.environ['NXNATIVE_WORKSPACE']).resolve()
    ssd = Path(r'F:\Temp')
    if ssd.is_dir(): return ssd / 'NXNative' / 'SMB'
    if frozen:
        return Path(executable or sys.executable).resolve().parent
    fallback = Path(os.environ.get('LOCALAPPDATA') or tempfile.gettempdir()) / 'NXNative' / 'SMB'
    return fallback


def local_workspace_root():
    """Use the exe's directory for persistent inputs and build caches, and reject network roots."""
    root = application_root()
    if is_network_path(root): raise OSError(f'workspace root must be on a local disk: {root}')
    try: root.mkdir(parents=True, exist_ok=True)
    except OSError as e: raise OSError(f'cannot create local build workspace at {root}: {e}') from e
    return root


def base_title_id(files):
    ids = []
    for f in files:
        name = Path(f).name
        m = re.search(r'\[([0-9A-Fa-f]{16})\]', name)
        if m: ids.append(m.group(1).upper())
    return next((x for x in ids if x.endswith('000')), ids[0] if ids else None)


def local_build_folder(files):
    """A per-title build/cache folder on the local workspace SSD when available."""
    files = [Path(f) for f in files]
    if not files: raise ValueError('select at least one game file')
    tid = base_title_id(files)
    key = tid or hashlib.sha256(str(files[0].parent).casefold().encode()).hexdigest()[:16]
    return local_workspace_root() / key / 'build'


def local_split_data_folder(files, ipa_output):
    """Place split data under the same local root as the SMB build workspace."""
    files = [Path(f) for f in files]
    tid = base_title_id(files) or hashlib.sha256(str(files[0].parent).casefold().encode()).hexdigest()[:16]
    return local_workspace_root() / tid / 'outputs' / (Path(ipa_output).stem + '-data')


def _sha256(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()


def local_ipa_output(files, ipa_destination):
    """Put the IPA under this game's persistent local SMB workspace."""
    files = [Path(f) for f in files]
    tid = base_title_id(files) or hashlib.sha256(str(files[0].parent).casefold().encode()).hexdigest()[:16]
    return local_workspace_root() / tid / 'outputs' / PureWindowsPath(os.fspath(ipa_destination)).name


def prepare_output_destination(destination):
    """Create and write-probe the final output directory before starting a build."""
    parent = Path(destination).parent
    parent.mkdir(parents=True, exist_ok=True)
    fd, probe = tempfile.mkstemp(prefix='.nxw-output-check-', dir=parent)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(b'NXNative output preflight')
            f.flush(); os.fsync(f.fileno())
    finally:
        try: os.unlink(probe)
        except FileNotFoundError: pass
    return Path(destination)


def safe_staged_copy(source, destination):
    """Copy to a unique sibling partial, verify bytes, then atomically publish it."""
    source, destination = Path(source), Path(destination)
    before = source.stat()
    digest = _sha256(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_name(f'{destination.name}.nxw-partial-{os.getpid()}-{uuid.uuid4().hex}')
    try:
        shutil.copy2(source, partial)
        after = source.stat()
        if (after.st_size, after.st_mtime_ns) != (before.st_size, before.st_mtime_ns):
            raise OSError(f'completed output changed during transfer: {source}')
        if partial.stat().st_size != before.st_size:
            raise OSError(f'incomplete transfer to {destination}: expected {before.st_size} bytes, got {partial.stat().st_size}')
        if _sha256(partial) != digest:
            raise OSError(f'transfer verification failed for {destination}')
        os.replace(partial, destination)
        return destination
    finally:
        try: partial.unlink()
        except FileNotFoundError: pass


def _atomic_copy(source, destination, expected_stat=None):
    source, destination = Path(source), Path(destination)
    before = expected_stat or source.stat()
    partial = destination.with_name(destination.name + '.nxw-partial')
    try:
        if partial.exists(): partial.unlink()
        shutil.copy2(source, partial)
        after = source.stat()
        if (after.st_size, after.st_mtime_ns) != (before.st_size, before.st_mtime_ns):
            raise OSError(f'game file changed while it was copied: {source}')
        if partial.stat().st_size != before.st_size:
            raise OSError(f'incomplete local copy of {source}: expected {before.st_size} bytes, got {partial.stat().st_size}')
        digest = _sha256(partial)
        os.replace(partial, destination)
        return digest
    finally:
        if partial.exists(): partial.unlink()


def _load_manifest(path):
    try:
        value = json.loads(path.read_text(encoding='utf-8'))
        return value if value.get('schema') == 1 and isinstance(value.get('files'), dict) else {}
    except (OSError, ValueError, AttributeError): return {}


def stage_folder(files, workspace_root=None, network_detector=is_network_path):
    """Return (folder, copied_names). UNC/SMB inputs are copied to a persistent local workspace.

    Local sources retain the existing behavior: use their folder when it contains only the selected
    game files, otherwise stage beside the sources and prefer same-volume hard links.
    """
    files = [Path(f).resolve() for f in files]
    if not files: raise ValueError('select at least one game file')
    parent = files[0].parent
    network = any(network_detector(f) for f in files)
    if network:
        root = Path(workspace_root) if workspace_root else local_workspace_root()
        if network_detector(root): raise OSError(f'build workspace must be on a local disk: {root}')
        tid = base_title_id(files)
        key = tid or hashlib.sha256(str(parent).casefold().encode()).hexdigest()[:16]
        dst = root / key / 'inputs'
        dst.mkdir(parents=True, exist_ok=True)
        manifest_path = dst / '.nxw-inputs.json'
        old = _load_manifest(manifest_path).get('files', {})
        copied, updated = [], {}
        for src in files:
            target = dst / src.name
            st = src.stat()
            record = old.get(src.name, {})
            if not isinstance(record, dict): record = {}
            reusable = (record.get('source') == str(src).casefold() and
                        record.get('size') == st.st_size and record.get('mtime_ns') == st.st_mtime_ns and
                        target.is_file() and target.stat().st_size == st.st_size and
                        _sha256(target) == record.get('sha256'))
            if reusable:
                updated[src.name] = record
                continue
            digest = _atomic_copy(src, target, st)
            copied.append(src.name)
            updated[src.name] = {'source': str(src).casefold(), 'size': st.st_size,
                                 'mtime_ns': st.st_mtime_ns, 'sha256': digest}
        tmp_manifest = manifest_path.with_name(manifest_path.name + '.partial')
        try:
            tmp_manifest.write_text(json.dumps({'schema': 1, 'files': updated}, indent=2), encoding='utf-8')
            os.replace(tmp_manifest, manifest_path)
        finally:
            if tmp_manifest.exists(): tmp_manifest.unlink()
        selected = {p.name for p in files}
        for p in dst.iterdir():
            if p.is_file() and p.suffix.lower() in GAME_EXT and p.name not in selected: p.unlink()
        return dst, copied

    if all(f.parent == parent for f in files) and {p.resolve() for p in parent.iterdir() if p.suffix.lower() in GAME_EXT} == set(files): return parent, None
    tid = base_title_id(files)
    dst = parent / f'{(tid or files[0].stem)[:40]}_nxw'
    dst.mkdir(exist_ok=True)
    copied = []
    for src in files:
        target = dst / src.name
        if target.exists():
            try:
                if os.path.samefile(src, target): continue
            except OSError: pass
            try:
                os.link(src, target.with_name(target.name + '.nxw-partial'))
                os.replace(target.with_name(target.name + '.nxw-partial'), target)
                continue
            except OSError:
                partial = target.with_name(target.name + '.nxw-partial')
                try:
                    _atomic_copy(src, partial)
                    os.replace(partial, target)
                finally:
                    if partial.exists(): partial.unlink()
                copied.append(src.name)
                continue
        try: os.link(src, target)
        except OSError:
            _atomic_copy(src, target)
            copied.append(src.name)
    selected = {p.name for p in files}
    for p in dst.iterdir():
        if p.suffix.lower() in GAME_EXT and p.name not in selected: p.unlink()
    return dst, copied


def default_network_output(files, repo):
    """Default network-source output to Media/Roms/iOS/<game>, when the source is under Media/Roms."""
    files = [Path(f) for f in files]
    tid = base_title_id(files)
    name = None
    if tid:
        profile = Path(repo) / 'dm/games' / tid / 'game.tsv'
        try:
            for line in profile.read_text(encoding='utf-8').splitlines():
                if line.startswith('ipa\t'):
                    name = line.split('\t', 1)[1].strip(); break
        except OSError: pass
    if not name: name = files[0].stem + '.ipa'
    ipa_name = PureWindowsPath(name).name
    roms_root = PureWindowsPath(files[0]).parent
    while roms_root != roms_root.parent:
        if roms_root.name.casefold() == 'roms': break
        roms_root = roms_root.parent
    else: roms_root = PureWindowsPath(r'\KPSynology\Media\Roms')
    return roms_root / 'iOS' / PureWindowsPath(ipa_name).stem / ipa_name


def zip_split_data(data_dir, destination, progress=None):
    """Zip a completed local split-data folder, then atomically transfer one file to its destination."""
    data_dir, destination = Path(data_dir), Path(destination)
    if not data_dir.is_dir(): raise OSError(f'split-data folder is missing: {data_dir}')
    if is_network_path(data_dir): raise OSError(f'split-data must be compressed from a local folder: {data_dir}')
    local_zip = data_dir.with_name(data_dir.name + '.zip')
    local_partial = local_zip.with_name(f'{local_zip.name}.partial-{os.getpid()}-{uuid.uuid4().hex}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        files = sorted(p for p in data_dir.rglob('*') if p.is_file())
        with zipfile.ZipFile(local_partial, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1, allowZip64=True) as archive:
            for index, path in enumerate(files, 1):
                arcname = (Path(data_dir.name) / path.relative_to(data_dir)).as_posix()
                archive.write(path, arcname)
                if progress and (index == 1 or index % 100 == 0 or index == len(files)): progress(index, len(files))
        with zipfile.ZipFile(local_partial, 'r') as archive:
            bad_file = archive.testzip()
            if bad_file: raise OSError(f'corrupt local split-data ZIP entry: {bad_file}')
        os.replace(local_partial, local_zip)
        return safe_staged_copy(local_zip, destination)
    finally:
        try:
            if local_partial.exists(): local_partial.unlink()
        except OSError:
            pass
