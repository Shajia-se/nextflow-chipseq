# Validation

Run `python3 -m unittest discover -s tests -v` from this repository.
Set `NEXTFLOW_BIN` to an existing Nextflow executable to include the native execution/resume test; otherwise that test is skipped. No software is installed by these tests. Test artifacts are retained under the sibling `chip_runs/` directory.

The eight launcher contract tests use a mock Nextflow command to check both launchers, module scheduling, failures, resume arguments, run locks, and path rejection. The native test executes a small real Nextflow process and verifies cache reuse and run isolation.

On 2026-09-11 all nine tests passed with Nextflow 25.10.0. A separate local Docker smoke run using five synthetic paired-end samples completed FastQC, fastp, BWA, Picard, chipfilter, MACS3, IDR, peak consensus, bamCoverage, FRiP, MultiQC, and result delivery. The sample summary contained all five samples and FRiP outputs covered all four ChIP samples across three peak sources. Cached container images and a local resource/image override config were used.

DiffBind, ChIPseeker, HOMER and deepTools heatmap were not exercised in that smoke run. Synthetic execution tests do not validate biological conclusions. HPC execution of this revision remains to be checked with real samples; no HPC files were modified during this validation.
