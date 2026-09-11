#!/usr/bin/env python3
"""Create chip_runs/date_runner with editable config and a Slurm launcher."""
import argparse
from pathlib import Path
import re
import shlex

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('run_id',help='e.g. 20260911_shan')
parser.add_argument('--chip-runs-root',type=Path)
a=parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*',a.run_id):parser.error('Use a single run name: letters/numbers/underscore/dot/hyphen')
repo=Path(__file__).resolve().parents[1];code=repo.parent
root=(a.chip_runs_root or code/'chip_runs').resolve()
if root.name!='chip_runs':parser.error('Root directory must be named chip_runs')
if any(p==root or p in root.parents for p in [repo,*code.glob('nf-*')]):parser.error('Run storage must be outside code repositories')
root.mkdir(parents=True,exist_ok=True)
run=root/a.run_id
run.mkdir(exist_ok=False)
s=(repo/'pipeline.env.example').read_text()
s=s.replace('PIPELINES_ROOT=/path/to/pipelines','PIPELINES_ROOT='+shlex.quote(str(code)))
s=s.replace('CHIP_RUNS_ROOT=${PIPELINES_ROOT}/chip_runs','CHIP_RUNS_ROOT='+shlex.quote(str(root)))
s=s.replace('RUN_ID=20260911_your_name','RUN_ID='+a.run_id)
(run/'pipeline.env').write_text(s)
(run/'samples_master.csv').write_text((repo/'samples_master_template.csv').read_text())
submit='''#!/usr/bin/env bash
#SBATCH --job-name=chipseq
#SBATCH --partition=cpu_p
#SBATCH --qos=cpu_normal
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=24:00:00
#SBATCH --output=launcher.%j.log
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
'''
# Slurm copies scripts to spool, so use the recorded absolute run path.
submit=submit[:submit.index('cd ')]+'cd '+shlex.quote(str(run))+'\n'
submit+='bash '+shlex.quote(str(repo/'run_end2end_parallel_safe.sh'))+' '+shlex.quote(str(run/'pipeline.env'))+'\n'
# Absolute Slurm output path, double-quoted for directories containing spaces.
submit=submit.replace('#SBATCH --output=launcher.%j.log','#SBATCH --output="'+str(run/'launcher.%j.log')+'"')
(run/'submit.sh').write_text(submit)
print('Created:',run)
print('Edit pipeline.env and samples_master.csv before running.')
print('HPC: sbatch '+shlex.quote(str(run/'submit.sh')))
print('Local: set PROFILE=local and run bash '+shlex.quote(str(repo/'run_end2end_parallel_safe.sh'))+' '+shlex.quote(str(run/'pipeline.env')))
