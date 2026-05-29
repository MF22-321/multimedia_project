#!/usr/bin/env python3
"""Convert SOP videos to Flutter-friendly SDR H.264 assets.

Output format:
- H.264 video
- yuv420p pixel format
- bt709 SDR color metadata
- AAC audio

Examples:
  python3 frontend/scripts/convert_video_sdr.py input.mp4
  python3 frontend/scripts/convert_video_sdr.py input.mp4 -o frontend/assets/video_sdr/MyVideo_sdr.mp4
  python3 frontend/scripts/convert_video_sdr.py frontend/assets/video_raw --batch
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


DEFAULT_OUTPUT_DIR = Path("frontend/assets/video_sdr")
VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".avi", ".webm", ".m4v"}


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(f"Missing required tool: {name}")


def probe_video(path: Path) -> dict[str, str]:
    result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            (
                "stream=codec_name,profile,pix_fmt,color_space,"
                "color_transfer,color_primaries,width,height,r_frame_rate"
            ),
            "-of",
            "json",
            str(path),
        ]
    )

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"ffprobe failed: {path}")

    data = json.loads(result.stdout)
    streams = data.get("streams") or []
    if not streams:
        raise RuntimeError(f"No video stream found: {path}")

    return {key: str(value) for key, value in streams[0].items()}


def is_hdr_hlg(metadata: dict[str, str]) -> bool:
    return (
        metadata.get("color_transfer") == "arib-std-b67"
        or metadata.get("color_primaries") == "bt2020"
        or metadata.get("pix_fmt", "").endswith("10le")
    )


def output_path_for(input_path: Path, output_dir: Path) -> Path:
    return output_dir / f"{input_path.stem}_sdr.mp4"


def convert_video(input_path: Path, output_path: Path, fps: int, crf: int) -> None:
    metadata = probe_video(input_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if is_hdr_hlg(metadata):
        video_filter = (
            "zscale=transferin=arib-std-b67:"
            "primariesin=bt2020:"
            "matrixin=bt2020nc:"
            "transfer=linear:npl=100,"
            "format=gbrpf32le,"
            "tonemap=tonemap=hable:desat=0,"
            "zscale=transfer=bt709:primaries=bt709:matrix=bt709:range=tv,"
            "format=yuv420p"
        )
    else:
        video_filter = "format=yuv420p"

    command = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-i",
        str(input_path),
        "-vf",
        video_filter,
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        str(crf),
        "-r",
        str(fps),
        "-colorspace",
        "bt709",
        "-color_trc",
        "bt709",
        "-color_primaries",
        "bt709",
        "-c:a",
        "aac",
        "-b:a",
        "160k",
        "-movflags",
        "+faststart",
        str(output_path),
    ]

    print(f"Converting: {input_path}")
    print(f"Output:     {output_path}")

    result = run(command)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "ffmpeg failed")

    converted = probe_video(output_path)
    print(
        "Done: "
        f"{converted.get('codec_name')} / "
        f"{converted.get('pix_fmt')} / "
        f"{converted.get('color_transfer')} / "
        f"{converted.get('color_primaries')}"
    )


def collect_inputs(path: Path, batch: bool) -> list[Path]:
    if path.is_file():
        return [path]

    if not batch:
        raise SystemExit("Input is a folder. Add --batch to convert all videos.")

    if not path.is_dir():
        raise SystemExit(f"Input not found: {path}")

    return sorted(
        file
        for file in path.iterdir()
        if file.is_file() and file.suffix.lower() in VIDEO_EXTENSIONS
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert videos to H.264 yuv420p SDR/bt709 for Flutter.",
    )
    parser.add_argument("input", type=Path, help="Input video file or folder")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output file. Only valid for single-file conversion.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Output folder for batch or default single conversion.",
    )
    parser.add_argument("--batch", action="store_true", help="Convert a folder")
    parser.add_argument("--fps", type=int, default=30, help="Output FPS")
    parser.add_argument("--crf", type=int, default=20, help="H.264 quality")

    args = parser.parse_args()

    require_tool("ffmpeg")
    require_tool("ffprobe")

    inputs = collect_inputs(args.input, args.batch)
    if not inputs:
        raise SystemExit("No video files found.")

    if args.output is not None and len(inputs) > 1:
        raise SystemExit("--output can only be used with one input file.")

    for input_path in inputs:
        output_path = args.output or output_path_for(input_path, args.output_dir)
        convert_video(input_path, output_path, fps=args.fps, crf=args.crf)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1)
