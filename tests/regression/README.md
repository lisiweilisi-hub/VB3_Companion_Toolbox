# VB3 v4.2 regression baseline

This harness targets the known-good Cell4 group02 trajectory/HMM pair documented
for the v4.2 pipeline. It is deliberately compatible with MATLAB R2016b.

Before changing source calculations, run from MATLAB with the v4.2 folder and
the regression folder on the path:

```matlab
addpath('C:\path\to\VB_ok 4.2');
addpath('C:\path\to\VB_ok 4.2\tests\regression');
VB3_RunRegressionBaseline('capture');
```

This executes `SPT_RunPipeline`, runs `SPT_Validation`, and writes:

- `baselines/v42_cell4_group02_baseline.mat`, used for comparison;
- `baselines/v42_cell4_group02_baseline.txt`, the readable contract manifest.

Later revisions are checked with:

```matlab
VB3_RunRegressionBaseline('verify');
```

The optional arguments are `mode`, `inputMAT`, `hmmMAT`, `runOutputDir`, and
`baselineFile`. Use them when the Cell4 files are installed elsewhere.

The committed harness records table schemas and row counts, recursive Analysis
field/size inventory, scalar validation flags, representative numeric outputs,
numeric table-column summaries, and generated CSV/Figure file manifests. Figure
byte counts are recorded for inspection, but verification compares filenames
because renderer metadata can vary across machines.

The known-good Cell4 files and MATLAB R2016b were not present on the machine that
added this harness. Therefore the generated `.mat` and `.txt` capture must be
created on the validated R2016b workstation before this becomes a numeric release
gate. A missing capture is an error in `verify` mode; the harness never invents
expected values.
