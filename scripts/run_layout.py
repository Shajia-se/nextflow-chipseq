#!/usr/bin/env python3
"""Keep launcher-owned files in chip_runs/<run_id>; no third-party packages."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import sys


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def inside(path, root):
    return path.resolve() == root.resolve() or root.resolve() in path.resolve().parents


def checked_dir(path, root):
    if not inside(path, root):
        raise ValueError('Path escapes this run (including symlinks): ' + str(path))
    path.mkdir(parents=True, exist_ok=True)
    return path


def initialize(args):
    code = Path(args.code).resolve(strict=True)
    root = Path(args.runs).expanduser().resolve()
    if root.name != 'chip_runs':
        raise ValueError('CHIP_RUNS_ROOT must name a chip_runs directory, not a project subfolder')
    if args.legacy and Path(args.legacy).expanduser().resolve() != root:
        raise ValueError('Remove OUTPUT_PROJECT_ROOT from the old env. Set CHIP_RUNS_ROOT and RUN_ID instead; old runs are not migrated automatically.')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', args.run_id):
        raise ValueError('RUN_ID must be a single name using letters, numbers, _, . or -')
    # Do not permit a caller to hide run data inside any code repository.
    if any(inside(root, p) for p in [code/'nextflow-chipseq', *code.glob('nf-*')]):
        raise ValueError('CHIP_RUNS_ROOT must be outside the code repositories')
    root.mkdir(parents=True, exist_ok=True)
    run = root / args.run_id
    if run.is_symlink():
        raise ValueError('Run directory must not be a symlink')
    run.mkdir(exist_ok=True)
    for output in run.glob('*_output'):
        if not inside(output, run):
            raise ValueError('Published output points outside this run: '+str(output))
    records = checked_dir(run/'02_run_record', run)
    intermediate = checked_dir(run/'99_intermediate', run)
    # Fail before touching existing state if a second launcher owns this run.
    lock = run/'.launcher.lock'
    lock.mkdir()
    try:
        (lock/'owner.txt').write_text(f'{args.owner}\n')
        attempt = dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f') + '_' + args.owner
        record = checked_dir(records/attempt, run)
        checked_dir(record/'logs', run)
        for directory in ('execution', 'work', 'tmp', 'container_cache'):
            checked_dir(intermediate/directory, run)
        shutil.copy2(args.env, record/'pipeline.env')
        versions = {}
        for module in [code/'nextflow-chipseq', *sorted(code.glob('nf-*'))]:
            if not module.is_dir():
                continue
            def git(*cmd):
                p = subprocess.run(['git', '-C', str(module), *cmd], capture_output=True, text=True)
                return p.stdout.strip() if p.returncode == 0 else 'unavailable'
            files = {}
            for pattern in ('*.nf', '*.config', 'configs/*.config', 'modules/*.nf', '*.sh', 'scripts/*.py', 'scripts/*.sh'):
                for p in module.glob(pattern):
                    files[str(p.relative_to(module))] = hashlib.sha256(p.read_bytes()).hexdigest()
            versions[module.name] = {'commit': git('rev-parse', 'HEAD'), 'status': git('status', '--short'), 'sha256': files}
            (record/(module.name+'.diff')).write_text(git('diff', 'HEAD', '--'))
        write_json(record/'code_versions.json', versions)
        write_json(record/'run.json', {'run_id':args.run_id, 'run_root':str(run), 'code_root':str(code), 'attempt':attempt, 'status':'RUNNING'})
        (run/'README_交付与清理.md').write_text('''# 本次运行的文件 / Run files

*_output/：各模块结果。02_run_record/：配置、版本、日志和每次启动状态。
99_intermediate/：工作文件、Nextflow 缓存和临时文件；此目录不是最终结果。

确认最新启动状态为 COMPLETED，并检查本次启用模块的结果完整、复制到最终存储位置后，
可以删除整个 99_intermediate 文件夹。不需要逐个打开模块 work 目录。
失败或仍在运行时请保留该目录。删除后失去缓存恢复能力，部分任务需要重新计算。
COMPLETED 只表示该次启用的模块成功；未启用模块不在验证范围内。

模块结果中仍可能有 trimmed FASTQ 和多个阶段的 BAM，它们不会随中间目录一起删除。
原始 FASTQ、参考文件及代码仓库不在清理范围内。不要删除 .launcher.lock 来启动并发运行；
异常退出留下锁时，先确认 launcher 及其计算作业均已停止，再人工移除锁目录。
''')
        for name,value in {'ACTIVE_RUN_ROOT':str(run), 'RECORD_DIR':str(record), 'LOG_DIR':str(record/'logs'), 'PIPELINES_ROOT':str(code), 'CHIP_RUNS_ROOT':str(root)}.items():
            print(name+'='+shlex.quote(value))
    except BaseException:
        (lock/'owner.txt').unlink(missing_ok=True)
        lock.rmdir()
        raise


def snapshot(args):
    target = Path(args.record)/'inputs'
    target.mkdir(exist_ok=True)
    for i, name in enumerate(args.files):
        if name and Path(name).is_file():
            shutil.copy2(name, target/(str(i)+'_'+Path(name).name))


def groovy(value):
    return "'" + str(value).replace('\\','\\\\').replace("'", "\\'") + "'"


def execute(args):
    run, record, code = Path(args.run), Path(args.record), Path(args.code)
    module = args.module
    if not re.fullmatch(r'nf-[a-z0-9-]+', module):
        raise ValueError('Invalid module name')
    main = code/module/'main.nf'
    if not main.is_file():
        raise ValueError('Missing module: '+str(main))
    wd = checked_dir(run/'99_intermediate/execution'/module, run)
    work = checked_dir(run/'99_intermediate/work'/module, run)
    tmp = checked_dir(run/'99_intermediate/tmp'/module, run)
    logs = checked_dir(record/'logs'/module, run)
    extras = args.extra[1:] if args.extra[:1] == ['--'] else args.extra
    # Inputs are absolute; do not let changing launchDir reinterpret relative paths.
    mounts = [run]
    for value in extras:
        if value.startswith('/') and Path(value).exists():
            p = Path(value).resolve()
            mounts.append(p if p.is_dir() else p.parent)
    mounts = list(dict.fromkeys(mounts))
    if module == 'nf-bwa':
        ref = Path(extras[extras.index('--reference_fasta')+1]).resolve(strict=True)
        mounts.append(ref.parent)
        index = checked_dir(run/'99_intermediate/reference/bwa', run)
        existing = ref.parent/'primary_bwa'
        suffixes = ['','.amb','.ann','.bwt','.pac','.sa']
        if (existing/'index.fa').resolve() == ref and all((existing/('index.fa'+s)).is_file() for s in suffixes):
            for s in suffixes:
                dst = index/('index.fa'+s)
                if not dst.exists():
                    dst.symlink_to(existing/('index.fa'+s))
        extras += ['--index_dir',str(index)]
    # String-valued control BAMs/scan roots are not discovered by autoMounts.
    # Keep all run outputs visible; external inputs are staged by their modules,
    # and site-specific binds remain available through params.extra_mounts.
    binds = ' '.join('--bind '+shlex.quote(str(p)) for p in mounts)
    volumes = ' '.join('-v '+shlex.quote(str(p)+':'+str(p)) for p in mounts)
    cfg = logs/'runtime.config'
    custom = ('includeConfig '+groovy(Path(args.config).resolve(strict=True))+'\n') if args.config else ''
    cfg.write_text(custom + 'cleanup = false\n' +
        'singularity.runOptions = (params.containsKey("extra_mounts") ? params.extra_mounts : "") + '+groovy(' '+binds)+'\n' +
        'docker.runOptions = '+groovy("--entrypoint '' "+volumes)+'\n')
    cmd = ['nextflow','-log',str(logs/'nextflow.log'),'-c',str(cfg),'run',str(main),
           '-profile',args.profile,'-work-dir',str(work),'-ansi-log','false',
           '--project_folder',str(run),'--mail_user',args.mail,*extras]
    if args.resume == 'true':
        cmd += ['-resume']
    env = os.environ.copy()
    env.update(NXF_TEMP=str(tmp), TMPDIR=str(tmp), NXF_SINGULARITY_CACHEDIR=str(run/'99_intermediate/container_cache'))
    status = {'module':module, 'cwd':str(wd), 'command':cmd, 'status':'RUNNING'}
    write_json(logs/'status.json',status)
    print('[RUN]',shlex.join(cmd),flush=True)
    proc = subprocess.Popen(cmd,cwd=wd,env=env,start_new_session=True)
    cancelled = []
    def cancel(signum, _frame):
        cancelled.append(signum)
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
    signal.signal(signal.SIGTERM,cancel)
    signal.signal(signal.SIGINT,cancel)
    rc = proc.wait()
    if cancelled:
        rc = 128 + cancelled[0]
    status.update(status='COMPLETED' if rc == 0 else 'FAILED',exit_code=rc)
    write_json(logs/'status.json',status)
    return rc if rc >= 0 else 128-rc


def finish(args):
    record = Path(args.record)
    p = record/'run.json'
    data = json.loads(p.read_text())
    data.update(status='COMPLETED' if args.exit_code == 0 else 'FAILED',exit_code=args.exit_code)
    write_json(p,data)
    lock=Path(args.run)/'.launcher.lock'
    if (lock/'owner.txt').read_text().strip() == args.owner:
        (lock/'owner.txt').unlink()
        lock.rmdir()
    print('[STATUS]',data['status'],args.run)
    if args.exit_code == 0:
        print('After checking and saving results, delete only: '+str(Path(args.run)/'99_intermediate'))
        print('Keep 02_run_record. Removing intermediate files disables cache-based resume.')
    else:
        print('Run failed: keep 99_intermediate for diagnosis/resume.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='action',required=True)
    p=commands.add_parser('init')
    for key in ('code','runs','run-id','env','owner'):p.add_argument('--'+key,required=True)
    p.add_argument('--legacy',default='')
    p=commands.add_parser('snapshot');p.add_argument('--record',required=True);p.add_argument('files',nargs='*')
    p=commands.add_parser('module')
    for key in ('code','run','record','module','profile','mail','resume'):p.add_argument('--'+key,required=True)
    p.add_argument('--config', default='')
    p.add_argument('extra',nargs=argparse.REMAINDER)
    p=commands.add_parser('finish')
    for key in ('record','run','owner'):p.add_argument('--'+key,required=True)
    p.add_argument('--exit-code',type=int,required=True)
    args=parser.parse_args()
    try:
        if args.action=='init':initialize(args)
        elif args.action=='snapshot':snapshot(args)
        elif args.action=='module':return execute(args)
        else:finish(args)
    except (ValueError,OSError) as e:
        print('ERROR:',e,file=sys.stderr);return 1
    return 0

if __name__=='__main__':sys.exit(main())
