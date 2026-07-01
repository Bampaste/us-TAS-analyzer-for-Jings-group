from __future__ import annotations

import csv
import html
import math
import re
from dataclasses import dataclass
from pathlib import Path

import numpy as np


SAMPLE_FOLDER = Path(r"D:\OneDrive\Jing Group\Results\PDI\us-TAS\2026.06.26\PDINH-Air-1mJ")
CALIBRATION_FILE = Path(r"G:\for jing us-TAS\Light intensity@20230408.txt")
OUTPUT_FOLDER = Path(__file__).resolve().parent / "preview_output_safe"
ALLOW_EXTRAPOLATION = False
CORRECTION_MODE = "unscaledSubtract"
REFERENCE_WAVELENGTHS = np.array([600, 650, 700, 750, 800, 850, 900, 950], dtype=float)


@dataclass
class Calibration:
    wavelength_nm: np.ndarray
    intensity: np.ndarray


def read_oscilloscope_csv(path: Path) -> tuple[np.ndarray, np.ndarray]:
    time = []
    signal = []
    with path.open(newline="") as handle:
        for row in csv.reader(handle):
            if len(row) < 5:
                continue
            try:
                time.append(float(row[3]))
                signal.append(float(row[4]))
            except ValueError:
                continue
    if not time:
        raise ValueError(f"No numeric time/signal data found in {path}")
    return np.array(time), np.array(signal)


def read_calibration(path: Path) -> Calibration:
    data = np.loadtxt(path)
    order = np.argsort(data[:, 0])
    wavelength = data[order, 0]
    intensity = data[order, 1]
    if np.any(intensity <= 0):
        raise ValueError("Calibration intensities must be positive.")
    return Calibration(wavelength, intensity)


def calibration_value(cal: Calibration, wavelength_nm: float, allow_extrapolation: bool) -> float:
    if wavelength_nm < cal.wavelength_nm.min() or wavelength_nm > cal.wavelength_nm.max():
        if not allow_extrapolation:
            raise ValueError(
                f"No calibration value for {wavelength_nm:.1f} nm; "
                f"range is {cal.wavelength_nm.min():.1f}-{cal.wavelength_nm.max():.1f} nm."
            )
    value = float(np.interp(wavelength_nm, cal.wavelength_nm, cal.intensity))
    if wavelength_nm > cal.wavelength_nm.max():
        x0, x1 = cal.wavelength_nm[-2:]
        y0, y1 = cal.intensity[-2:]
        value = float(y1 + (wavelength_nm - x1) * (y1 - y0) / (x1 - x0))
    elif wavelength_nm < cal.wavelength_nm.min():
        x0, x1 = cal.wavelength_nm[:2]
        y0, y1 = cal.intensity[:2]
        value = float(y0 + (wavelength_nm - x0) * (y1 - y0) / (x1 - x0))
    if not math.isfinite(value) or value <= 0:
        raise ValueError(f"Invalid calibration value {value} for {wavelength_nm:.1f} nm.")
    return value


def parse_wavelength(name: str) -> float | None:
    match = re.search(r"(\d+(?:\.\d+)?)\s*nm", name, re.IGNORECASE)
    return float(match.group(1)) if match else None


def find_track(folder: Path, suffix: str) -> Path | None:
    files = sorted(folder.glob(f"*{suffix}"))
    return files[0] if files else None


def downsample(x: np.ndarray, y: np.ndarray, max_points: int = 1800) -> tuple[np.ndarray, np.ndarray]:
    if len(x) <= max_points:
        return x, y
    idx = np.linspace(0, len(x) - 1, max_points).astype(int)
    return x[idx], y[idx]


def make_polyline(x: np.ndarray, y: np.ndarray, width: int, height: int, pad: int) -> str:
    finite = np.isfinite(x) & np.isfinite(y)
    x = x[finite]
    y = y[finite]
    if len(x) == 0:
        return ""
    xmin, xmax = float(np.min(x)), float(np.max(x))
    ymin, ymax = float(np.min(y)), float(np.max(y))
    if xmax == xmin:
        xmax = xmin + 1
    if ymax == ymin:
        ymax = ymin + 1
    xp = pad + (x - xmin) / (xmax - xmin) * (width - 2 * pad)
    yp = height - pad - (y - ymin) / (ymax - ymin) * (height - 2 * pad)
    return " ".join(f"{float(a):.2f},{float(b):.2f}" for a, b in zip(xp, yp))


def svg_plot(title: str, series: list[tuple[str, np.ndarray, np.ndarray, str]]) -> str:
    width, height, pad = 960, 320, 44
    all_x = np.concatenate([s[1] for s in series])
    all_y = np.concatenate([s[2] for s in series])
    xmin, xmax = float(np.nanmin(all_x)), float(np.nanmax(all_x))
    ymin, ymax = float(np.nanmin(all_y)), float(np.nanmax(all_y))
    polylines = []
    for label, x, y, color in series:
        xd, yd = downsample(x, y)
        points = make_polyline(xd, yd, width, height, pad)
        polylines.append(
            f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="1.2">'
            f'<title>{html.escape(label)}</title></polyline>'
        )
    legend = " ".join(
        f'<span><i style="background:{color}"></i>{html.escape(label)}</span>'
        for label, _, _, color in series
    )
    return f"""
    <section class="plot">
      <h3>{html.escape(title)}</h3>
      <svg viewBox="0 0 {width} {height}" role="img">
        <rect x="0" y="0" width="{width}" height="{height}" fill="#fff"/>
        <line x1="{pad}" y1="{height-pad}" x2="{width-pad}" y2="{height-pad}" stroke="#888"/>
        <line x1="{pad}" y1="{pad}" x2="{pad}" y2="{height-pad}" stroke="#888"/>
        <text x="{pad}" y="{height-10}" font-size="11">{xmin:.1f} us</text>
        <text x="{width-pad-70}" y="{height-10}" font-size="11">{xmax:.1f} us</text>
        <text x="6" y="{pad}" font-size="11">{ymax:.3g}</text>
        <text x="6" y="{height-pad}" font-size="11">{ymin:.3g}</text>
        {''.join(polylines)}
      </svg>
      <div class="legend">{legend}</div>
    </section>
    """


def process() -> None:
    OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)
    cal = read_calibration(CALIBRATION_FILE)
    ref_values = np.array([calibration_value(cal, wl, False) for wl in REFERENCE_WAVELENGTHS])

    rows = []
    sections = []
    for folder in sorted(p for p in SAMPLE_FOLDER.iterdir() if p.is_dir()):
        wavelength = parse_wavelength(folder.name)
        if wavelength is None:
            continue
        a_file = find_track(folder, "A track.csv")
        b_file = find_track(folder, "B track.csv")
        if a_file is None or b_file is None:
            rows.append((folder.name, wavelength, "error", "missing A or B track"))
            continue

        try:
            time_a, a = read_oscilloscope_csv(a_file)
            _, b = read_oscilloscope_csv(b_file)
            n = min(len(a), len(b))
            cal_value = calibration_value(cal, wavelength, ALLOW_EXTRAPOLATION)
            if CORRECTION_MODE == "relativeCalibration":
                scale = cal_value / float(ref_values.mean())
            elif CORRECTION_MODE == "unscaledSubtract":
                scale = 1.0
            else:
                raise ValueError(f"Unknown correction mode: {CORRECTION_MODE}")
            corrected = a[:n] - scale * b[:n]
            if not np.all(np.isfinite(corrected)):
                raise ValueError("non-finite corrected values")

            stem = folder.name.replace(" ", "_")
            np.savetxt(
                OUTPUT_FOLDER / f"{stem}-corrected-A-B.txt",
                np.column_stack([time_a[:n], corrected]),
                fmt="%.15g",
                delimiter="\t",
            )

            t_us = time_a[:n] * 1e6
            sections.append(f"<article><h2>{html.escape(folder.name)} ({wavelength:.0f} nm)</h2>")
            sections.append(
                svg_plot(
                    "Raw A and B tracks",
                    [
                        ("A track", t_us, a[:n], "#2459a6"),
                        ("B track", t_us, b[:n], "#b5482f"),
                    ],
                )
            )
            sections.append(
                svg_plot(
                    f"Corrected A-B: A - {scale:.6g} * B; calibration {cal_value:.4g}",
                    [("Corrected A-B", t_us, corrected, "#111111")],
                )
            )
            sections.append("</article>")
            rows.append((folder.name, wavelength, "ok", f"scale={scale:.6g}, cal={cal_value:.4g}"))
        except Exception as exc:
            rows.append((folder.name, wavelength, "error", str(exc)))

    with (OUTPUT_FOLDER / "summary.tsv").open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["folder", "wavelength_nm", "status", "message"])
        writer.writerows(rows)

    html_doc = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>us-TAS A/B Correction Preview</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; color: #1f2328; background: #f6f7f9; }}
    h1 {{ margin-bottom: 4px; }}
    .meta {{ color: #59636e; margin-bottom: 20px; }}
    article {{ background: white; border: 1px solid #d8dee4; border-radius: 8px; padding: 18px; margin: 18px 0; }}
    h2 {{ margin: 0 0 12px; }}
    h3 {{ margin: 10px 0 6px; font-size: 15px; }}
    svg {{ width: 100%; height: auto; border: 1px solid #e5e7eb; }}
    .legend {{ font-size: 13px; margin: 6px 0 14px; }}
    .legend span {{ margin-right: 16px; }}
    .legend i {{ display: inline-block; width: 18px; height: 3px; margin-right: 6px; vertical-align: middle; }}
    table {{ border-collapse: collapse; background: white; width: 100%; margin-bottom: 20px; }}
    th, td {{ border: 1px solid #d8dee4; padding: 6px 8px; text-align: left; font-size: 13px; }}
    th {{ background: #eef1f4; }}
  </style>
</head>
<body>
  <h1>us-TAS A/B Correction Preview</h1>
  <div class="meta">Sample: {html.escape(str(SAMPLE_FOLDER))}<br>Calibration: {html.escape(str(CALIBRATION_FILE))}</div>
  <table>
    <tr><th>Folder</th><th>Wavelength</th><th>Status</th><th>Message</th></tr>
    {''.join(f'<tr><td>{html.escape(str(r[0]))}</td><td>{r[1]}</td><td>{html.escape(str(r[2]))}</td><td>{html.escape(str(r[3]))}</td></tr>' for r in rows)}
  </table>
  {''.join(sections)}
</body>
</html>
"""
    (OUTPUT_FOLDER / "index.html").write_text(html_doc, encoding="utf-8")

    print(f"Wrote preview output to {OUTPUT_FOLDER}")
    for row in rows:
        print("\t".join(map(str, row)))


if __name__ == "__main__":
    process()
