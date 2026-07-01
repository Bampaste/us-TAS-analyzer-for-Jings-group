from __future__ import annotations

import csv
import html
import math
import re
from pathlib import Path

import numpy as np

from preview_us_tas import (
    CALIBRATION_FILE,
    REFERENCE_WAVELENGTHS,
    SAMPLE_FOLDER,
    calibration_value,
    downsample,
    find_track,
    make_polyline,
    parse_wavelength,
    read_calibration,
    read_oscilloscope_csv,
    svg_plot,
)


OUTPUT_FOLDER = Path(__file__).resolve().parent / "comparison_output"


def read_old_ab(path: Path) -> tuple[np.ndarray, np.ndarray]:
    time = []
    signal = []
    with path.open() as handle:
        for line in handle:
            parts = line.split()
            if len(parts) < 2:
                continue
            try:
                time.append(float(parts[0]))
                signal.append(float(parts[1]))
            except ValueError:
                time.append(float("nan"))
                signal.append(float("nan"))
    return np.array(time), np.array(signal)


def find_old_ab(folder: Path) -> Path | None:
    files = sorted(folder.glob("*A track-A-B.txt"))
    return files[0] if files else None


def metrics(old: np.ndarray, new: np.ndarray) -> dict[str, float]:
    valid = np.isfinite(old) & np.isfinite(new)
    if not np.any(valid):
        return {
            "n": 0,
            "rmse": float("nan"),
            "mae": float("nan"),
            "bias": float("nan"),
            "corr": float("nan"),
        }
    residual = new[valid] - old[valid]
    corr = float(np.corrcoef(old[valid], new[valid])[0, 1]) if np.sum(valid) > 1 else float("nan")
    return {
        "n": int(np.sum(valid)),
        "rmse": float(np.sqrt(np.mean(residual**2))),
        "mae": float(np.mean(np.abs(residual))),
        "bias": float(np.mean(residual)),
        "corr": corr,
    }


def best_subtraction_scale(a: np.ndarray, b: np.ndarray, old: np.ndarray) -> float:
    valid = np.isfinite(a) & np.isfinite(b) & np.isfinite(old) & (b != 0)
    if not np.any(valid):
        return float("nan")
    # Minimize ||A - kB - old||.
    return float(np.sum(b[valid] * (a[valid] - old[valid])) / np.sum(b[valid] ** 2))


def residual_svg(title: str, t_us: np.ndarray, old: np.ndarray, new: np.ndarray) -> str:
    residual = new - old
    return svg_plot(title, [("new - old", t_us, residual, "#7a3db8")])


def process() -> None:
    OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)
    cal = read_calibration(CALIBRATION_FILE)
    ref_values = np.array([calibration_value(cal, wl, False) for wl in REFERENCE_WAVELENGTHS])
    ref_mean = float(ref_values.mean())

    rows = []
    sections = []

    for folder in sorted(p for p in SAMPLE_FOLDER.iterdir() if p.is_dir()):
        wavelength = parse_wavelength(folder.name)
        if wavelength is None:
            continue

        a_file = find_track(folder, "A track.csv")
        b_file = find_track(folder, "B track.csv")
        old_file = find_old_ab(folder)
        if a_file is None or b_file is None or old_file is None:
            rows.append([folder.name, wavelength, "skipped", "", "", "", "", "", "", "missing input"])
            continue

        try:
            _, a = read_oscilloscope_csv(a_file)
            time_a, b = read_oscilloscope_csv(b_file)
            old_time, old = read_old_ab(old_file)
            n = min(len(a), len(b), len(old))
            a = a[:n]
            b = b[:n]
            old = old[:n]
            t_us = old_time[:n] * 1e6 if len(old_time) >= n else time_a[:n] * 1e6

            finite_old = np.isfinite(old)
            if np.sum(finite_old) < 0.95 * n:
                rows.append([
                    folder.name,
                    wavelength,
                    "invalid-old",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    f"old A-B has {np.sum(finite_old)}/{n} finite points",
                ])
                continue

            cal_value = calibration_value(cal, wavelength, False)
            current_scale = cal_value / ref_mean
            new = a - current_scale * b
            unscaled = a - b
            best_k = best_subtraction_scale(a, b, old)
            best_new = a - best_k * b
            m_current = metrics(old, new)
            m_unscaled = metrics(old, unscaled)
            m_best = metrics(old, best_new)

            rows.append([
                folder.name,
                wavelength,
                "ok",
                f"{current_scale:.8g}",
                f"{m_unscaled['rmse']:.8g}",
                f"{best_k:.8g}",
                f"{m_current['rmse']:.8g}",
                f"{m_best['rmse']:.8g}",
                f"{m_current['corr']:.8g}",
                "",
            ])

            sections.append(f"<article><h2>{html.escape(folder.name)} ({wavelength:.0f} nm)</h2>")
            sections.append(
                f"<p>Current scale: <b>{current_scale:.6g}</b>; best A-kB scale to match old output: "
                f"<b>{best_k:.6g}</b>; RMSE current: <b>{m_current['rmse']:.4g}</b>; "
                f"RMSE A-B: <b>{m_unscaled['rmse']:.4g}</b>; "
                f"RMSE best-k: <b>{m_best['rmse']:.4g}</b>.</p>"
            )
            sections.append(
                svg_plot(
                    "Old A-B vs current new correction",
                    [
                        ("old A-B", t_us, old, "#2459a6"),
                        ("current new", t_us, new, "#111111"),
                    ],
                )
            )
            sections.append(residual_svg("Residual: current new - old A-B", t_us, old, new))
            sections.append("</article>")
        except Exception as exc:
            rows.append([folder.name, wavelength, "error", "", "", "", "", "", "", str(exc)])

    with (OUTPUT_FOLDER / "comparison_summary.tsv").open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow([
            "folder",
            "wavelength_nm",
            "status",
            "current_scale",
            "rmse_unscaled_A_minus_B",
            "best_k_to_match_old",
            "rmse_current",
            "rmse_best_k",
            "corr_current",
            "message",
        ])
        writer.writerows(rows)

    html_rows = "".join(
        "<tr>" + "".join(f"<td>{html.escape(str(cell))}</td>" for cell in row) + "</tr>"
        for row in rows
    )
    html_doc = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>us-TAS Old A-B Comparison</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; color: #1f2328; background: #f6f7f9; }}
    article {{ background: white; border: 1px solid #d8dee4; border-radius: 8px; padding: 18px; margin: 18px 0; }}
    h1 {{ margin-bottom: 4px; }}
    .meta {{ color: #59636e; margin-bottom: 20px; }}
    svg {{ width: 100%; height: auto; border: 1px solid #e5e7eb; background: white; }}
    .legend {{ font-size: 13px; margin: 6px 0 14px; }}
    .legend span {{ margin-right: 16px; }}
    .legend i {{ display: inline-block; width: 18px; height: 3px; margin-right: 6px; vertical-align: middle; }}
    table {{ border-collapse: collapse; background: white; width: 100%; margin-bottom: 20px; }}
    th, td {{ border: 1px solid #d8dee4; padding: 6px 8px; text-align: left; font-size: 13px; }}
    th {{ background: #eef1f4; }}
  </style>
</head>
<body>
  <h1>us-TAS Old A-B Comparison</h1>
  <div class="meta">Sample: {html.escape(str(SAMPLE_FOLDER))}<br>Calibration: {html.escape(str(CALIBRATION_FILE))}</div>
  <table>
    <tr><th>Folder</th><th>Wavelength</th><th>Status</th><th>Current scale</th><th>RMSE A-B</th><th>Best k</th><th>RMSE current</th><th>RMSE best k</th><th>Corr</th><th>Message</th></tr>
    {html_rows}
  </table>
  {''.join(sections)}
</body>
</html>
"""
    (OUTPUT_FOLDER / "index.html").write_text(html_doc, encoding="utf-8")

    print(f"Wrote comparison output to {OUTPUT_FOLDER}")
    for row in rows:
        print("\t".join(map(str, row)))


if __name__ == "__main__":
    process()
