# How To Fill `samples_master.csv`

This guide explains exactly how to fill `samples_master.csv` for the end-to-end ChIP-seq pipeline.

Audience: users with little or no coding experience.

---

## 1. Purpose

`samples_master.csv` is the **single source of truth** for your sample metadata.

From this table, downstream sheets can be generated for:

- MACS3 treatment/control pairing
- IDR replicate pairing
- FRiP calculation
- DiffBind analysis
- HOMER motif comparison
- deepTools region plotting

---

## 2. File Format Rules

- File type: CSV (comma-separated)
- First row must be the header
- One sample per row
- No empty required columns
- Use `true` / `false` (lowercase) for boolean columns
- Do not add extra spaces before/after commas

---

## 3. Required Columns

Header must be exactly:

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
```

### Column-by-column instructions

1. `sample_id`
- Meaning: unique sample name/ID
- Example: `GAR0968`
- Required: yes
- Rule: must be unique in the table

2. `condition`
- Meaning: biological group label
- Example: `WT`, `TG`, `KO`, `Treated`, `Control`
- Required: yes
- Rule: for current project, keep it as a 1-vs-1 design (two ChIP conditions)

3. `replicate`
- Meaning: biological replicate number
- Example: `1`, `2`
- Required: yes
- Rule: integer only

4. `library_type`
- Meaning: library role
- Allowed values: `chip` or `input`
- Required: yes
- Rule:
  - ChIP IP samples -> `chip`
  - Control/input samples -> `input`

5. `fastq_r1`
- Meaning: absolute path to read 1 FASTQ file
- Required: yes

6. `fastq_r2`
- Meaning: absolute path to read 2 FASTQ file
- Required: yes (for paired-end data)

7. `is_control`
- Meaning: whether this row is a control/input sample
- Allowed values: `true` or `false`
- Required: yes
- Rule:
  - `library_type=input` -> `is_control=true`
  - `library_type=chip` -> `is_control=false`

8. `control_id`
- Meaning: which control sample is used for this ChIP sample
- Required:
  - yes for `chip` rows
  - empty for `input` rows
- Rule: must match an existing `sample_id` of an `input` sample

9. `use_for_idr`
- Meaning: include this sample in IDR pairing
- Allowed values: `true` or `false`
- Recommended default:
  - `chip` -> `true`
  - `input` -> `false`

10. `use_for_diffbind`
- Meaning: include this sample in DiffBind analysis
- Allowed values: `true` or `false`
- Recommended default:
  - `chip` -> `true`
  - `input` -> `false`

11. `enabled`
- Meaning: whether this row is active
- Allowed values: `true` or `false`
- Recommended default: `true`
- Use case: set `false` to temporarily disable problematic samples

---

## 4. Recommended Defaults (Quick Rules)

For a normal ChIP sample row:

- `library_type=chip`
- `is_control=false`
- `control_id=<input sample_id>`
- `use_for_idr=true`
- `use_for_diffbind=true`
- `enabled=true`

For an input/control row:

- `library_type=input`
- `is_control=true`
- `control_id=` (leave empty)
- `use_for_idr=false`
- `use_for_diffbind=false`
- `enabled=true`

---

## 5. Example (WT vs TG, 2 replicates each, one shared input)

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
GAR0968,WT,1,chip,/path/GAR0968_R1.fastq.gz,/path/GAR0968_R2.fastq.gz,false,SRR7416886,true,true,true
GAR0979,WT,2,chip,/path/GAR0979_R1.fastq.gz,/path/GAR0979_R2.fastq.gz,false,SRR7416886,true,true,true
GAR1585,TG,1,chip,/path/GAR1585_R1.fastq.gz,/path/GAR1585_R2.fastq.gz,false,SRR7416886,true,true,true
GAR1586,TG,2,chip,/path/GAR1586_R1.fastq.gz,/path/GAR1586_R2.fastq.gz,false,SRR7416886,true,true,true
SRR7416886,CTRL,1,input,/path/SRR7416886_1.fastq.gz,/path/SRR7416886_2.fastq.gz,true,,false,false,true
```

---

## 6. Pre-run Checklist

Before running the pipeline, verify:

- All `sample_id` values are unique
- All FASTQ paths exist
- Exactly one row per real sample/library
- Every `chip` row has a valid `control_id`
- At least 2 `chip` replicates per ChIP condition for robust IDR/DiffBind
- `enabled=true` for all rows you want to run

---

## 7. Common Mistakes to Avoid

- Using relative FASTQ paths instead of absolute paths
- Typing `TRUE/FALSE` instead of `true/false`
- Forgetting `control_id` for chip rows
- Typo in `control_id` that does not match any `sample_id`
- Duplicate `sample_id`
- Marking input rows as `use_for_idr=true`

---

## 8. Where This File Lives

- Working file:
  - `nextflow-chipseq/samples_master.csv`
- Template copy:
  - `nextflow-chipseq/templates/samples_master.example.csv`

---

## 9. Optional: Export To PDF

If you need PDF for sharing, convert this Markdown file using any Markdown-to-PDF tool (for example, VS Code export, Typora, or pandoc).
