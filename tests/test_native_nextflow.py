"""Real Nextflow scheduling/cache test; no bioinformatics tool mocks or containers.
Set NEXTFLOW_BIN to an installed Nextflow executable. No downloads are required.
"""
from pathlib import Path
import json,os,subprocess,unittest,uuid
REPO=Path(__file__).resolve().parents[1]
@unittest.skipUnless(os.environ.get('NEXTFLOW_BIN'),'Set NEXTFLOW_BIN for native Nextflow tests')
class Native(unittest.TestCase):
 def test_real_execution_resume_and_run_isolation(self):
  base=REPO.parent/'chip_runs'/'20260911_native_tests'/uuid.uuid4().hex
  module=base/'code/nf-fastqc';module.mkdir(parents=True)
  (module/'nextflow.config').write_text("params.samples_master = null\nparams.project_folder = null\nprofiles { local { process.executor = 'local' } }\n")
  (module/'main.nf').write_text('''nextflow.enable.dsl=2
process fixture {
 input:
 path sheet
 output:
 path 'verified.txt'
 publishDir "${params.project_folder}/fastqc_output", mode: 'copy'
 script:
 """
 cat ${sheet} > verified.txt
 """
}
workflow { fixture(Channel.fromPath(params.samples_master, checkIfExists:true)) }
''')
  (base/'samples.csv').write_text('sample_id\nreal_nextflow_test\n')
  (base/'genome.fa').write_text('>chr1\nACGT\n');(base/'genes.gtf').touch()
  bin_dir=base/'bin';bin_dir.mkdir();(bin_dir/'nextflow').symlink_to(Path(os.environ['NEXTFLOW_BIN']).resolve())
  env=dict(os.environ,PATH=str(bin_dir)+os.pathsep+os.environ['PATH'],NXF_OFFLINE='true')
  config=f'PIPELINES_ROOT={base}/code\nCHIP_RUNS_ROOT={base}/chip_runs\nPROFILE=local\nRESUME=true\nREFERENCE_FASTA={base}/genome.fa\nGTF={base}/genes.gtf\nSAMPLES_MASTER={base}/samples.csv\n'
  for name in ['FASTP','BWA','PICARD','CHIPFILTER','MACS3','IDR','PEAK_CONSENSUS','DIFFBIND','BAMCOVERAGE','FRIP','CHIPSEEKER','HOMER','DEEPTOOLS_HEATMAP','RESULT_DELIVERY','MULTIQC']:config+='RUN_'+name+'=false\n'
  sheet=base/'pipeline.env'
  for launcher,run_id in [('run_end2end.sh','20260911_native'),('run_end2end.sh','20260911_native'),('run_end2end_parallel_safe.sh','20260911_independent')]:
   sheet.write_text(config+'RUN_ID='+run_id+'\n')
   p=subprocess.run(['bash',str(REPO/launcher),str(sheet)],cwd=base,env=env,text=True,capture_output=True,timeout=120)
   self.assertEqual(p.returncode,0,p.stdout+p.stderr)
  run=base/'chip_runs/20260911_native'
  records=sorted((run/'02_run_record').glob('*/logs/nf-fastqc/nextflow.log'))
  self.assertEqual(len(records),2)
  self.assertIn('Cached process',records[-1].read_text())
  self.assertEqual((run/'fastqc_output/verified.txt').read_text(),(base/'samples.csv').read_text())
  self.assertTrue((run/'99_intermediate/execution/nf-fastqc/.nextflow').is_dir())
  self.assertFalse((module/'work').exists());self.assertFalse((module/'.nextflow').exists())
  second=base/'chip_runs/20260911_independent'
  self.assertTrue((second/'fastqc_output/verified.txt').is_file())
if __name__=='__main__':unittest.main()
