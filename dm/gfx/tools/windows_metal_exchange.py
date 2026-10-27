#!/usr/bin/env python3
"""Export and validate iOS Metal IR compiled by Apple Metal Developer Tools for Windows."""
import argparse,csv,hashlib,json,shutil,sys,re
from pathlib import Path
SCHEMA=1
def sha(path):
 h=hashlib.sha256()
 with open(path,'rb') as f:
  for b in iter(lambda:f.read(1<<20),b''): h.update(b)
 return h.hexdigest()
def ios_flags():
 root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'ios/tools'));import ios_metal
 return ios_metal.METAL[5:],ios_metal.RECORD
def export(mac_dir,ios_dir,exchange):
 mac,ios,root=Path(mac_dir),Path(ios_dir),Path(exchange)
 if not mac.is_dir() or not ios.is_dir():raise SystemExit('Mac and iOS output directories must exist')
 flags,record=ios_flags();srcdir=root/'sources';refdir=root/'reflections';shutil.rmtree(srcdir,ignore_errors=True);shutil.rmtree(refdir,ignore_errors=True);srcdir.mkdir(parents=True,exist_ok=True);refdir.mkdir(parents=True,exist_ok=True);rows={}
 for msl in sorted(mac.glob('*.metal')):
  stem=msl.stem
  if not (stem.endswith(('_b','_bf','_bp','_bv')) or '_bg' in stem):continue
  mp=mac/(stem+'.json')
  output_key=stem
  if not mp.is_file() and stem.endswith(('_bp','_bv','_bf')):
   mp=mac/(stem[:-1]+'.json')
  if not mp.is_file():continue
  try:meta=json.loads(mp.read_text())
  except (OSError,ValueError):continue
  digest=sha(msl);target=srcdir/(digest+'.metal')
  if target.exists() and sha(target)!=digest:raise SystemExit(f'conflicting source for SHA {digest}')
  if not target.exists():shutil.copyfile(msl,target)
  row=rows.setdefault(digest,{'schema':SCHEMA,'filename':f'sources/{digest}.metal','source_sha256':digest,'shader_keys':set(),'stage':meta.get('stage','unknown'),'shader_source':meta.get('source','unknown'),'reflection_metadata':{},'reflection_files':{},'target':'ios18','metal_flags_json':json.dumps(flags,separators=(',',':')),'chain_metal':record})
  shader_key=output_key; row['shader_keys'].add(shader_key)
  metadata_key=meta.get('key',stem[:-1] if stem.endswith(('_bp','_bv','_bf')) else stem)
  row['reflection_metadata'][shader_key]={'sha256':sha(mp),'source':meta.get('source','unknown'),'stage':meta.get('stage','unknown'),'metadata_key':metadata_key}
  if Path(shader_key).name!=shader_key:raise SystemExit(f'unsafe shader key for reflection export: {shader_key}')
  reflection_file=f'reflections/{metadata_key}.json';shutil.copyfile(mp,root/reflection_file);row['reflection_files'][shader_key]={'path':reflection_file,'metadata_key':metadata_key}
  if row['stage']!=meta.get('stage','unknown'):raise SystemExit(f'inconsistent stages for {digest}')
 out=root/'manifest.csv'
 with open(out,'w',newline='') as f:
  fields=['schema','filename','source_sha256','shader_keys','stage','shader_source','reflection_metadata_json','reflection_files_json','target','metal_flags_json','chain_metal'];w=csv.DictWriter(f,fieldnames=fields);w.writeheader()
  for digest,row in sorted(rows.items()):row['shader_keys']=json.dumps(sorted(row['shader_keys']),separators=(',',':'));row['reflection_metadata_json']=json.dumps(row['reflection_metadata'],sort_keys=True,separators=(',',':'));row['reflection_files_json']=json.dumps(row['reflection_files'],sort_keys=True,separators=(',',':'));del row['reflection_metadata'];del row['reflection_files'];w.writerow(row)
 print(f'Windows iOS queue: {len(rows)} unique MSL sources; {out}');return len(rows)
def receipt_shader_keys(receipt):
 raw=receipt.get('shader_keys',[])
 if isinstance(raw,list) and len(raw)==1 and isinstance(raw[0],dict) and 'value' in raw[0]:
  raw=raw[0]['value']
 if isinstance(raw,str):return [raw]
 if isinstance(raw,list):return [str(x) for x in raw]
 return []

def verify_export(manifest_path,shader_map):
 manifest_path,shader_map=Path(manifest_path),Path(shader_map);flags,_=ios_flags();rows=[];fail=[];allkeys=[];base=set()
 with open(manifest_path,newline='') as f:rows=list(csv.DictReader(f))
 for row in rows:
  try:
   src=manifest_path.parent/row['filename'];digest=row['source_sha256'];keys=json.loads(row['shader_keys']);meta_rows=json.loads(row['reflection_metadata_json']);files=json.loads(row['reflection_files_json'])
   if sha(src)!=digest:raise ValueError('source SHA-256 mismatch')
   if json.loads(row['metal_flags_json'])!=flags:raise ValueError('flags differ from NXNative iOS flags')
   if set(keys)!=set(meta_rows) or set(keys)!=set(files):raise ValueError('reflection key set differs from shader keys')
   for key in keys:
    info=meta_rows[key];entry=files[key];rp=manifest_path.parent/entry['path'];reflection=json.loads(rp.read_text())
    if sha(rp)!=info['sha256']:raise ValueError(f'reflection hash mismatch for {key}')
    if reflection.get('key')!=entry['metadata_key'] or reflection.get('stage')!=info['stage'] or reflection.get('source')!=info['source']:raise ValueError(f'reflection content mismatch for {key}')
    allkeys.append(key)
    if key.endswith('_b'):base.add(key)
  except Exception as e:fail.append(f"{row.get('filename','?')}: {e}")
 expected=set()
 for line in shader_map.read_text(errors='replace').splitlines():
  c=line.rstrip('\n').split('\t')
  if len(c)>4 and c[0].endswith('.bin'):expected.add(c[3]+'_b')
 report={'unique_msl_sources':len(rows),'shader_library_keys':len(allkeys),'unique_shader_library_keys':len(set(allkeys)),'base_shader_keys':len(base),'expected_base_shader_keys':len(expected),'missing_base_keys':len(expected-base),'unexpected_base_keys':len(base-expected),'reflection_records':len({v['path'] for r in rows for v in json.loads(r['reflection_files_json']).values()}),'nxnative_ios_flags':flags,'all_flags_exact':len({r['metal_flags_json'] for r in rows})==1 and all(json.loads(r['metal_flags_json'])==flags for r in rows),'failures':fail[:20]}
 print(json.dumps(report,indent=2));return 0 if rows and not fail and len(allkeys)==len(set(allkeys)) and base==expected and report['all_flags_exact'] else 1

def verify_results(manifest_path,results_dir):
 manifest_path,results_dir=Path(manifest_path),Path(results_dir);flags,record=ios_flags();versions=set();executables=set();libraries=set();rows=[];keys=set();fail=[]
 with open(manifest_path,newline='') as f:rows=list(csv.DictReader(f))
 for row in rows:
  try:
   digest=row['source_sha256'];src=manifest_path.parent/row['filename'];source=src.read_bytes()
   if sha(src)!=digest:raise ValueError('source SHA-256 mismatch')
   if json.loads(row['metal_flags_json'])!=flags:raise ValueError('flags differ from NXNative iOS flags')
   refl=json.loads(row['reflection_metadata_json']);files=json.loads(row['reflection_files_json'])
   if set(refl)!=set(files):raise ValueError('reflection key/file set mismatch')
   for key,entry in files.items():
    relative=entry['path'];metadata_key=entry['metadata_key'];rp=manifest_path.parent/relative;meta=json.loads(rp.read_text())
    if sha(rp)!=refl[key]['sha256'] or meta.get('key',metadata_key)!=metadata_key:raise ValueError(f'reflection mismatch for {key}')
    keys.add(key)
   hit=load_cached(results_dir,source,flags)
   if not hit:raise ValueError('missing or invalid Windows receipt/library')
   lib,receipt=hit
   if receipt_shader_keys(receipt)!=json.loads(row['shader_keys']):raise ValueError('shader key receipt mismatch')
   if receipt.get('reflection_metadata_json')!=row['reflection_metadata_json']:raise ValueError('receipt reflection metadata mismatch')
   if receipt.get('reflection_files_json')!=row['reflection_files_json']:raise ValueError('receipt reflection file map mismatch')
   if receipt.get('stage')!=row['stage'] or receipt.get('shader_source')!=row['shader_source']:raise ValueError('stage/source metadata mismatch')
   versions.add(receipt.get('compiler_version'));executables.add(receipt.get('compiler_executable_sha256'));libraries.add(receipt.get('metallib_executable_sha256'))
  except Exception as e:fail.append(f"{row.get('filename','?')}: {e}")
 expected=sum(len(json.loads(r['shader_keys'])) for r in rows)
 report={'source_count':len(rows),'shader_key_count':len(keys),'expected_key_count':expected,'valid_results':len(rows)-len(fail),'compiler_versions':sorted(str(x) for x in versions),'metal_executable_sha256':sorted(str(x) for x in executables),'metallib_executable_sha256':sorted(str(x) for x in libraries),'target':'ios18','nxnative_flags':flags,'failures':fail[:20]}
 print(json.dumps(report,indent=2));return 0 if rows and not fail and expected==len(keys) and len(versions)==len(executables)==len(libraries)==1 and None not in versions|executables|libraries else 1

def verify_samples(repo,sample,work):
 sample,work=Path(sample),Path(work);want={}
 with open(sample/'manifest.csv',newline='') as f:
  for r in csv.DictReader(f):want[r['shader_source']]=r
 found={}
 for jp in (work/'shader/cache/cas/shader').glob('*/mac/*_b.json'):
  try:
   m=json.loads(jp.read_text());src=m.get('source')
   if src not in want:continue
   r=want[src];msl=jp.with_suffix('.metal');iosj=jp.parents[1]/'ios'/jp.name;ioslib=iosj.with_suffix('.metallib')
   winlib=sample/'compiled'/r['filename'].replace('.metal','.metallib');air=sample/'compiled'/r['filename'].replace('.metal','.air')
   mb=winlib.read_bytes();ab=air.read_bytes();target=re.search(rb'air64_v\d+-apple-ios18\.0\.0',ab);ver=re.search(rb'Apple metal version (\d+\.\d+\.\d+ \([^)]+\))',ab);stage=m.get('stage')
   try:
    im=json.loads(iosj.read_text()); mm=json.loads(jp.read_text()); fields=set(mm)|set(im); refl_match=all(mm.get(k)==im.get(k) for k in fields-{'chain_metal','metal_compiler'})
   except (OSError,ValueError): refl_match=False
   found[src]={'shader_key':m.get('key'),'stage':stage,'stage_match':stage=={'vertex':'vs','fragment':'ps','compute':'cs'}.get(r['stage']),'source_sha256':sha(sample/r['filename']),'source_match':msl.is_file() and sha(msl)==sha(sample/r['filename']),'reflection_present':iosj.is_file(),'reflection_matches_mac':refl_match,'reflection_sha256':sha(iosj) if iosj.is_file() else None,'tahoe_ios_library_present':ioslib.is_file(),'windows_library_sha256':sha(winlib),'windows_library_mtlb':mb[:4]==b'MTLB','air_target':target.group(0).decode() if target else None,'metal_version':ver.group(1).decode(errors='replace') if ver else None,'windows_air_sha256':sha(air),'windows_compile_flags_recorded':False}
  except (OSError,ValueError):pass
 report={'sample_count':len(want),'matched_count':len(found),'results':[{'shader_source':k,**found.get(k,{'matched':False})} for k in want],'runtime_compatibility':'not established by compilation or MTLB parsing; device/runtime load test required'}
 print(json.dumps(report,indent=2));return 0 if len(found)==len(want) and all(x.get('source_match') and x.get('stage_match') and x.get('windows_library_mtlb') and x.get('air_target') for x in found.values()) else 1
def annotate(mac_dir,ios_dir,cache_dir):
 mac,ios,cache=Path(mac_dir),Path(ios_dir),Path(cache_dir);flags,_=ios_flags();updates={};count=0
 for receipt_path in sorted(cache.glob('*.json')):
  try:r=json.loads(receipt_path.read_text())
  except (OSError,ValueError):continue
  if r.get('status')!='ok':continue
  if not receipt_shader_keys(r):continue
  # Validate this receipt's output and metadata through each key, including generated variants.
  for key in receipt_shader_keys(r):
   source_path=mac/(key+'.metal')
   if not source_path.is_file() or sha(source_path)!=r.get('source_sha256'):continue
   hit=load_cached(cache,source_path.read_bytes(),flags,key)
   if not hit:continue
   rows=json.loads(r.get('reflection_metadata_json','{}'));row=rows.get(key)
   if not row:raise SystemExit(f'Windows receipt has no reflection metadata for {key}')
   metadata_key=row.get('metadata_key',key);mac_json=mac/(metadata_key+'.json');ios_json=ios/(metadata_key+'.json')
   if not (mac_json.is_file() and ios_json.is_file()) or sha(mac_json)!=row.get('sha256'):
    raise SystemExit(f'reflection metadata hash mismatch for Windows library {key}')
   meta=updates.get(ios_json)
   if meta is None:meta=json.loads(ios_json.read_text())
   provenance={k:r.get(k) for k in ('compiler','compiler_version','compiler_executable_sha256','metallib_executable_sha256','air_target','source_sha256','metallib_sha256')}
   if metadata_key==key:meta['metal_compiler']=provenance
   else:meta.setdefault('metal_compiler_variants',{})[key]=provenance
   updates[ios_json]=meta;count+=1
 for path,meta in updates.items():
  tmp=path.with_suffix('.json.tmp');tmp.write_text(json.dumps(meta,ensure_ascii=False,indent=1)+'\n');tmp.replace(path)
 print(f'Windows compiler provenance attached to {count} shader libraries across {len(updates)} reflection records')
 return count

def load_cached(cache_dir,source,expected_flags,shader_key=None):
 root=Path(cache_dir);digest=hashlib.sha256(source).hexdigest();lib=root/(digest+'.metallib');rp=root/(digest+'.json')
 try:r=json.loads(rp.read_text());data=lib.read_bytes()
 except (OSError,ValueError):return None
 if r.get('schema')!=SCHEMA or r.get('status')!='ok' or r.get('source_sha256')!=digest or r.get('target')!='ios18':return None
 if r.get('metal_flags_json')!=json.dumps(expected_flags,separators=(',',':')):return None
 if r.get('compiler')!='Apple Metal Developer Tools for Windows' or not r.get('compiler_version') or not r.get('compiler_executable_sha256') or not r.get('metallib_executable_sha256'):return None
 if shader_key and shader_key not in receipt_shader_keys(r):return None
 if shader_key and shader_key not in json.loads(r.get('reflection_metadata_json','{}')):return None
 if data[:4]!=b'MTLB' or hashlib.sha256(data).hexdigest()!=r.get('metallib_sha256'):return None
 if not re.fullmatch(r'air64_v\d+-apple-ios18\.0\.0',str(r.get('air_target',''))):return None
 try: reflection=json.loads(r.get('reflection_metadata_json','{}'))
 except (TypeError,ValueError):return None
 if not isinstance(reflection,dict) or (shader_key and shader_key not in reflection):return None
 return lib,r
def main():
 ap=argparse.ArgumentParser();sub=ap.add_subparsers(dest='cmd',required=True);e=sub.add_parser('export');e.add_argument('mac_dir');e.add_argument('ios_dir');e.add_argument('exchange_dir');v=sub.add_parser('verify-samples');v.add_argument('repo');v.add_argument('sample_dir');v.add_argument('work_dir');q=sub.add_parser('verify-results');q.add_argument('manifest');q.add_argument('results_dir');x=sub.add_parser('verify-export');x.add_argument('manifest');x.add_argument('shader_map');n=sub.add_parser('annotate');n.add_argument('mac_dir');n.add_argument('ios_dir');n.add_argument('cache_dir');a=ap.parse_args()
 if a.cmd=='export':export(a.mac_dir,a.ios_dir,a.exchange_dir);return 0
 if a.cmd=='annotate':annotate(a.mac_dir,a.ios_dir,a.cache_dir);return 0
 if a.cmd=='verify-results':return verify_results(a.manifest,a.results_dir)
 if a.cmd=='verify-export':return verify_export(a.manifest,a.shader_map)
 return verify_samples(a.repo,a.sample_dir,a.work_dir)
if __name__=='__main__':raise SystemExit(main())
