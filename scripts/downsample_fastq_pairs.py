#!/usr/bin/env python3
import argparse
import gzip
import random
import sys
from pathlib import Path


def open_text(path: Path, mode: str):
    if path.suffix == ".gz":
        return gzip.open(path, mode + "t")
    return open(path, mode, encoding="utf-8")


def count_fastq_records(path: Path) -> int:
    lines = 0
    with open_text(path, "r") as handle:
        for _ in handle:
            lines += 1
    if lines % 4 != 0:
        raise ValueError(f"{path} does not look like a valid FASTQ file: line count {lines} is not divisible by 4")
    return lines // 4


def read_fastq_record(handle):
    rec = [handle.readline() for _ in range(4)]
    if not rec[0]:
        return None
    if any(x == "" for x in rec):
        raise ValueError("FASTQ record is truncated")
    return rec


def write_record(handle, rec):
    for line in rec:
        handle.write(line)


def main():
    p = argparse.ArgumentParser(
        description=(
            "Downsample paired-end FASTQ files to an exact target number of pairs. "
            "If --target-reads-total is used, it is interpreted as total reads across R1+R2 "
            "and will be converted to read pairs by dividing by 2."
        )
    )
    p.add_argument("--r1", required=True, help="Input R1 FASTQ(.gz)")
    p.add_argument("--r2", required=True, help="Input R2 FASTQ(.gz)")
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument("--target-pairs", type=int, help="Exact number of read pairs to keep")
    group.add_argument("--target-reads-total", type=int, help="Exact total reads to keep across R1+R2")
    p.add_argument("--out-r1", required=True, help="Output downsampled R1 FASTQ(.gz)")
    p.add_argument("--out-r2", required=True, help="Output downsampled R2 FASTQ(.gz)")
    p.add_argument("--seed", type=int, default=42, help="Random seed for reproducibility")
    args = p.parse_args()

    r1 = Path(args.r1)
    r2 = Path(args.r2)
    out_r1 = Path(args.out_r1)
    out_r2 = Path(args.out_r2)

    if args.target_reads_total is not None:
        if args.target_reads_total % 2 != 0:
            raise ValueError("--target-reads-total must be even for paired-end FASTQ input")
        target_pairs = args.target_reads_total // 2
    else:
        target_pairs = args.target_pairs

    total_r1 = count_fastq_records(r1)
    total_r2 = count_fastq_records(r2)
    if total_r1 != total_r2:
        raise ValueError(f"R1/R2 record count mismatch: {total_r1} vs {total_r2}")
    total_pairs = total_r1

    if target_pairs < 0:
        raise ValueError("Target pair count must be >= 0")
    if target_pairs > total_pairs:
        raise ValueError(f"Target pairs {target_pairs} exceed available pairs {total_pairs}")

    random.seed(args.seed)
    remaining_total = total_pairs
    remaining_keep = target_pairs
    kept = 0

    out_r1.parent.mkdir(parents=True, exist_ok=True)
    out_r2.parent.mkdir(parents=True, exist_ok=True)

    with open_text(r1, "r") as h1, open_text(r2, "r") as h2, open_text(out_r1, "w") as o1, open_text(out_r2, "w") as o2:
        while True:
            rec1 = read_fastq_record(h1)
            rec2 = read_fastq_record(h2)
            if rec1 is None and rec2 is None:
                break
            if rec1 is None or rec2 is None:
                raise ValueError("R1/R2 reached EOF at different positions")

            # Exact one-pass sampling without replacement.
            keep = random.randrange(remaining_total) < remaining_keep
            if keep:
                write_record(o1, rec1)
                write_record(o2, rec2)
                remaining_keep -= 1
                kept += 1
            remaining_total -= 1

    sys.stderr.write(
        f"Finished downsampling.\n"
        f"Input pairs: {total_pairs}\n"
        f"Target pairs: {target_pairs}\n"
        f"Kept pairs: {kept}\n"
        f"Seed: {args.seed}\n"
        f"Output total reads: {kept * 2}\n"
    )


if __name__ == "__main__":
    main()
