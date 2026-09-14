# Presentation notes — archived source material

These are the speaking sections extracted from the former walkthroughs. They describe historical settings and are not operating instructions. In particular, the current standard uses q=0.05/q=0.01 and has no default blacklist. Use the [technical manual](../../docs/USER_MANUAL_EN.md) for handoff.

## PICARD

`nf-chipfilter` focuses on MAPQ filtering plus mitochondrial burden QC.
- Duplicate handling is conceptually separate and is best done explicitly here.
- Keeping `remove_duplicates` configurable preserves flexibility for low-depth or special library scenarios.

## MACS3

This module performs peak calling with MACS3 using treatment-control pairs.
Compared with the earlier version, we now always generate two output branches: one relaxed branch at q<0.1 for IDR, and one strict branch at q<0.01 for consensus and differential workflows.

A recent update is that we now also perform peak-level blacklist filtering after callpeak.
So both branches are cleaned against mm39 blacklist regions, and each sample writes a `blacklist_applied` report with before/after peak counts.

This setup keeps branch intent clear: IDR gets a broader candidate set, while strict analyses use higher-confidence peaks.
