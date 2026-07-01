# us-TAS Analyzer for Jing's Group

Packaged copy: V1.1, named for Jing's group.

V1.1 adds exact typed X/Y axis limits, split `Auto X` / `Auto Y` / `Auto all` scale buttons, top/right plot borders, and an optional `y=0` baseline reference line.

First-pass replacement for the old LabVIEW A/B background correction workflow.

## What this version does

- Reads oscilloscope CSV files with time/value data in columns 4 and 5.
- Finds wavelength folders such as `850 nm-1`, `850 nm-end`, `1000 nm-2`.
- Pairs `A track.csv` and `B track.csv`.
- Loads the probe light-intensity calibration table.
- Stops with a clear error when a wavelength is outside the calibrated range.
- Applies a conservative B-track correction:

```matlab
corrected = A - B;
```

The calibration file is still loaded and checked. If the measured wavelength is outside the calibrated range, the pipeline stops instead of creating simulated data. The first comparison against the old finite A-B outputs shows plain `A - B` is much closer than scaling B by relative light intensity.

## Why 1000 nm failed in the old workflow

`Light intensity@20230408.txt` stops at 950 nm. The old LabVIEW process appears to request a 1000 nm calibration value anyway, which produces `Inf` or `-Inf` in the A-B output. This pipeline refuses to silently do that. By default it errors outside the calibration range; only enable extrapolation in an explicitly marked exploratory script, not in final analysis.

## Files

- `run_us_tas_analyzer.m` - start the combined analyzer.
- `usTASAnalyzer.m` - one launcher for all three viewers.
- `run_ab_generator.m` - open the A-B generator directly.
- `usTASABGeneratorViewer.m` - generate A-B from A/B track CSV files.
- `usTASGenerateAB.m` - batch function for `A track - B track`.
- `usTASCreateAxisLimitControls.m` - shared editable plot limit controls.
- `usTASSyncAxisLimitControls.m` - sync editable limit boxes after zoom/auto-scale.
- `usTASUpdateZeroLine.m` - shared optional `y=0` baseline reference line.
- `run_us_tas_demo.m` - edit paths here and run this first.
- `run_smoothing_viewer.m` - open the interactive segmented smoothing viewer.
- `run_compare_viewer.m` - open the kinetics comparison viewer.
- `run_spectrum_viewer.m` - open the spectrum builder.
- `usTASProcessSample.m` - processes a whole sample folder.
- `usTASReadOscilloscopeCsv.m` - imports A/B CSV traces.
- `usTASReadABTxt.m` - imports existing old A-B text traces.
- `usTASReadCalibration.m` - imports wavelength/intensity calibration.
- `usTASCalibrationValue.m` - interpolation/extrapolation guard.
- `usTASCorrectAB.m` - calibrated A/B correction.
- `usTASSegmentedSmooth.m` - segmented moving-window smoothing.
- `usTASSmoothFile.m` - batch smooth one A-B file and export data.
- `usTASSmoothViewer.m` - interactive plot for adjusting smoothing.
- `usTASReadSmoothedKinetics.m` - imports exported smoothed kinetics.
- `usTASKineticsCompareViewer.m` - compare multiple smoothed kinetics.
- `usTASParseWavelength.m` - extracts wavelength from file names/paths.
- `usTASSpectrumViewer.m` - combines kinetics into spectra at selected times.
- `usTASPlotQC.m` - saves raw/corrected QC plots.
- `preview_us_tas.py` - quick visual HTML preview without opening MATLAB.
- `compare_old_ab.py` - compares the new correction with old finite A-B outputs.

## Quick MATLAB Usage

Start here for the normal interactive workflow:

```matlab
run_us_tas_analyzer
```

This opens one analyzer window with buttons for A-B generation, smoothing, kinetics comparison, and spectrum building.

## Generate A-B From A/B Tracks

The LabVIEW code writer confirmed the old background removal is direct subtraction:

```text
A-B = A track - B track
```

Open the combined analyzer and choose `Generate A-B from tracks`, or run:

```matlab
run_ab_generator
```

You can select a wavelength folder, or manually select A-track and B-track CSV files. The generated output is a two-column text file:

```text
time_s    A_minus_B
```

The A-B preview plot also includes typed `X min` / `X max` / `Y min` / `Y max` boxes for exact axis limits, `Auto X`, `Auto Y`, and `Auto all` scale buttons, plus a `y=0` baseline reference checkbox.

## Legacy MATLAB Usage

Edit the paths in `run_us_tas_demo.m`, then run:

```matlab
run_us_tas_demo
```

## Quick Preview Without MATLAB UI

From PowerShell:

```powershell
python preview_us_tas.py
```

If normal `python` is not available, use the bundled Codex Python path printed in the final response.

The preview writes `preview_output/index.html` plus corrected text files. Open the HTML file to inspect raw A/B traces and corrected A-B traces.

## Compare Against Old A-B Outputs

```powershell
python compare_old_ab.py
```

The comparison writes `comparison_output/index.html` and `comparison_output/comparison_summary.tsv`. The script skips old A-B files that contain `Inf`/`-Inf`, so `1000 nm` is reported as invalid rather than used as a target.

## Smooth Existing A-B Kinetics

For now, this is the main workflow: use the old `A-B.txt` file already present in each wavelength folder, then smooth that kinetic trace.

```matlab
run_smoothing_viewer
```

The viewer opens empty first. Load data with `File > Open A-B file...` or the `Load A-B file` button.

The viewer lets you tune four smoothing windows:

- `t <= 0 us`
- `0 < t <= 10 us`
- `10 < t <= 100 us`
- `t > 100 us`

Each smoothing window can be changed three ways: slider, typed number box, or `-` / `+` step buttons. Window sizes are kept as odd point counts. The smoothed line is blue, raw A-B is gray.

It shows raw A-B and smoothed A-B together, rescales the axes automatically, supports linear/log X and Y scales, and exports a text file with three columns:

```text
time_s    raw_A_minus_B    smoothed_A_minus_B    baseline_corrected_smoothed_A_minus_B
```

Automatic baseline correction is off by default. Turn on `Auto baseline` to estimate a baseline from the selected pre-pump time window and subtract it from the smoothed trace. You can also use `Manual offset` with a typed value or `-` / `+` buttons to adjust the vertical offset yourself. The default baseline window is `-900` to `-50 us`.

Use `Zoom +`, `Zoom -`, the mouse wheel, `Auto`, `Auto X`, `Auto Y`, `Auto all`, or the typed `X min` / `X max` / `Y min` / `Y max` boxes for plot scaling. The `y=0` checkbox shows or hides a baseline reference line. The window can be dragged from blank figure space as well as from the normal title bar.

The smoothing viewer remembers the last folder used to load data and the last folder used to export data/figures.

## Compare Smoothed Kinetics

```matlab
run_compare_viewer
```

Use `Add kinetics files` to load one or more exported smoothed kinetics files. The viewer uses the final signal column if present, otherwise the last available signal column.

Features:

- show/hide each trace with the table checkboxes
- rename labels in the table
- normalize by a fixed value
- normalize by the y value closest to a selected time in microseconds
- linear/log X and Y controls
- zoom buttons, mouse-wheel zoom, auto-scale, `Auto X`, `Auto Y`, `Auto all`, typed X/Y axis limits, and optional `y=0` baseline line
- drag the window from blank figure space
- export the currently visible plotted data
- save the comparison figure

The comparison viewer remembers the last folder used to load kinetics and the last folder used to export data/figures.

## Build Spectra From Kinetics

```matlab
run_spectrum_viewer
```

Use `Add kinetics files` to load smoothed kinetics from one sample. The viewer parses wavelengths from file names or paths, then interpolates each kinetic trace at the selected times.

Features:

- plot `wavelength` vs `DeltaOD`
- one line per selected time or selected time window
- edit spectrum requests in microseconds, one request per line
- a single number means one time point, e.g. `10`
- two numbers or a range means average over that period, e.g. `1 5` or `1-5`
- keep/hide individual kinetics in the table
- edit wavelengths manually if parsing is wrong
- choose between repeated measurements at the same wavelength by keeping only the replicate you want
- export the plotted spectrum table
- save the spectrum figure
- zoom buttons, mouse-wheel zoom, auto-scale, `Auto X`, `Auto Y`, `Auto all`, typed X/Y axis limits, and optional `y=0` baseline line

For reproducible batch smoothing without the viewer:

```matlab
opts = struct();
opts.segmentEdgesUs = [0 10 100];
opts.windowPoints = [5 21 81 301];
opts.method = 'movmean';
opts.baselineWindowUs = [-900 -50];
opts.baselineMethod = 'mean';

usTASSmoothFile(inputFile, outputFile, opts);
```
