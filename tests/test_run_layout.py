"""Launcher contract tests using a fake Nextflow executable (not tool validation).
Run with PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v.
Fixtures and evidence are kept under the workspace chip_runs tree.
"""
from pathlib import Path
import json,os,subprocess,unittest,uuid

REPO=Path(__file__).resolve().parents[1]
NAMES=['fastqc','fastp','bwa','picard','chipfilter','macs3','idr','peak-consensus','diffbind','bamcoverage','frip','chipseeker','homer','deeptools-heatmap','multiqc','result-delivery']
class Layout(unittest.TestCase):
 def setUp(self):
  self.base=REPO.parent/'chip_runs'/'20260911_contract_tests'/uuid.uuid4().hex
  self.code=self.base/'code';self.code.mkdir(parents=True)
  for name in NAMES:
   p=self.code/('nf-'+name);p.mkdir();(p/'main.nf').write_text('// fixture\n')
  self.bin=self.base/'bin';self.bin.mkdir()
  stub=self.bin/'nextflow';stub.write_text('''#!/usr/bin/env python3
import sys,os,json,time
from pathlib import Path
a=sys.argv[1:];main=Path(a[a.index('run')+1]);module=main.parent.name
run=Path(a[a.index('--project_folder')+1]);work=Path(a[a.index('-work-dir')+1])
Path('.nextflow').mkdir(exist_ok=True);Path('.nextflow/history').write_text('fixture')
work.mkdir(exist_ok=True,parents=True);(work/'task.txt').write_text('fixture')
(run/(module+'.argv.json')).write_text(json.dumps({'args':a,'cwd':str(Path.cwd()),'tmp':os.environ['NXF_TEMP']}))
if os.environ.get('FAKE_FAIL')==module:sys.exit(17)
''');stub.chmod(0o755)
  self.ref=self.base/'genome.fa';self.ref.write_text('>chr1\nACGT\n')
  self.gtf=self.base/'genes.gtf';self.gtf.touch()
  self.samples=self.base/'samples.csv';self.samples.write_text('sample_id\nfixture\n')
  self.env=self.base/'pipeline.env'
  self.text=f'PIPELINES_ROOT={self.code}\nCHIP_RUNS_ROOT={self.base}/chip_runs\nRUN_ID=20260911_tester\nREFERENCE_FASTA={self.ref}\nGTF={self.gtf}\nSAMPLES_MASTER={self.samples}\nPROFILE=local\n'
  self.env.write_text(self.text)
  self.osenv=dict(os.environ,PATH=str(self.bin)+os.pathsep+os.environ['PATH'])
  self.run=self.base/'chip_runs/20260911_tester'
 def launch(self,name='run_end2end_parallel_safe.sh',extra=None):
  result=subprocess.run(['bash',str(REPO/name),str(self.env)],env=extra or self.osenv,cwd=self.base,capture_output=True,text=True)
  (self.base/(name+'.log')).write_text(result.stdout+result.stderr)
  return result
 def assert_success(self,name):
  p=self.launch(name);self.assertEqual(p.returncode,0,p.stdout+p.stderr)
  for name in NAMES:
   d=json.loads((self.run/('nf-'+name+'.argv.json')).read_text())
   self.assertTrue(d['cwd'].startswith(str(self.run/'99_intermediate/execution')))
   self.assertIn(str(self.code/('nf-'+name)/'main.nf'),d['args'])
   self.assertFalse((self.code/('nf-'+name)/'work').exists())
   self.assertFalse((self.code/('nf-'+name)/'.nextflow').exists())
  self.assertFalse((self.run/'.launcher.lock').exists())
  status=list((self.run/'02_run_record').glob('*/run.json'))[-1]
  self.assertEqual(json.loads(status.read_text())['status'],'COMPLETED')
 def test_parallel_all_modules(self):self.assert_success('run_end2end_parallel_safe.sh')
 def test_sequential_all_modules(self):self.assert_success('run_end2end.sh')
 def test_failure_and_resume(self):
  p=self.launch(extra=dict(self.osenv,FAKE_FAIL='nf-idr'));self.assertNotEqual(p.returncode,0)
  self.assertFalse((self.run/'.launcher.lock').exists())
  self.assertFalse((self.run/'nf-frip.argv.json').exists())
  self.assertEqual(self.launch().returncode,0)
  self.assertEqual(len(list((self.run/'02_run_record').glob('*/run.json'))),2)
 def test_legacy_root_rejected(self):
  self.env.write_text(self.text+f'OUTPUT_PROJECT_ROOT={self.base}/runs/default_project\n')
  p=self.launch();self.assertNotEqual(p.returncode,0);self.assertIn('Remove OUTPUT_PROJECT_ROOT',p.stderr)
  self.assertFalse((self.base/'runs').exists())
 def test_traversal_rejected(self):
  self.env.write_text(self.text+'RUN_ID=../escape\n');self.assertNotEqual(self.launch().returncode,0)
  self.assertFalse((self.base/'escape').exists())
 def test_same_run_lock(self):
  (self.run/'.launcher.lock').mkdir(parents=True)
  self.assertNotEqual(self.launch().returncode,0)
  self.assertTrue((self.run/'.launcher.lock').exists())
 def test_empty_parallel_waves(self):
  disabled=['IDR','PEAK_CONSENSUS','DIFFBIND','BAMCOVERAGE','FRIP','CHIPSEEKER','HOMER','DEEPTOOLS_HEATMAP']
  self.env.write_text(self.text+''.join('RUN_'+n+'=false\n' for n in disabled))
  p=self.launch();self.assertEqual(p.returncode,0,p.stdout+p.stderr)
 def test_run_symlink_rejected(self):
  outside=self.base/'outside';outside.mkdir();self.run.parent.mkdir();self.run.symlink_to(outside,target_is_directory=True)
  self.assertNotEqual(self.launch().returncode,0);self.assertEqual(list(outside.iterdir()),[])
if __name__=='__main__':unittest.main()
