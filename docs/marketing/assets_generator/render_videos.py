import os
import sys
import asyncio
import subprocess
import shutil

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

from playwright.async_api import async_playwright

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
VIDEOS_DIR = os.path.join(BASE_DIR, "videos")
TEMP_FRAMES_DIR = os.path.join(BASE_DIR, "assets_generator", "temp_frames")

HTML_TRAILER = os.path.abspath(os.path.join(os.path.dirname(__file__), "video_trailer_16_9.html"))
HTML_SHORTS = os.path.abspath(os.path.join(os.path.dirname(__file__), "video_shorts_9_16.html"))

async def render_video_frames(html_path, width, height, total_seconds, fps, seek_fn, prefix, lang="en"):
    frames_dir = os.path.join(TEMP_FRAMES_DIR, f"{prefix}_{lang}")
    os.makedirs(frames_dir, exist_ok=True)
    
    total_frames = int(total_seconds * fps)
    print(f"[*] Rendering {total_frames} frames for {prefix} [lang={lang}] ({width}x{height} @ {fps}fps)...")

    async with async_playwright() as p:
        browser = await p.chromium.launch(args=['--allow-file-access-from-files', '--no-sandbox'])
        page = await browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
        file_url = f"file:///{html_path.replace(os.sep, '/')}?lang={lang}"
        await page.goto(file_url, wait_until="networkidle")
        await page.wait_for_timeout(2000)

        for f in range(total_frames):
            sec = f / fps
            await page.evaluate(f"window.{seek_fn}({sec})")
            await page.wait_for_timeout(16)
            frame_path = os.path.join(frames_dir, f"frame_{f:05d}.png")
            stage = await page.query_selector("#stage")
            if stage:
                await stage.screenshot(path=frame_path)
            else:
                await page.screenshot(path=frame_path)

            if f % 90 == 0 or f == total_frames - 1:
                progress = int((f / total_frames) * 100)
                print(f"  [{prefix}-{lang}] Progress: {progress}% ({f}/{total_frames} frames)")

        await browser.close()
    
    return frames_dir

def encode_mp4_with_ffmpeg(frames_dir, output_mp4, fps, width, height):
    print(f"[*] Encoding MP4 with FFmpeg -> {output_mp4}...")
    cmd = [
        "ffmpeg",
        "-y",
        "-framerate", str(fps),
        "-i", os.path.join(frames_dir, "frame_%05d.png"),
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-vf", f"scale={width}:{height}",
        "-movflags", "+faststart",
        output_mp4
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode == 0:
        print(f"[OK] Video successfully encoded -> {output_mp4}")
    else:
        print(f"[ERROR] FFmpeg failed with error:\n{res.stderr}")

async def render_for_language(lang, do_trailer=True, do_shorts=True):
    print(f"\n==========================================")
    print(f"[*] Starting Video Rendering for: {lang.upper()}")
    print(f"==========================================")

    lang_dir = VIDEOS_DIR if lang == "en" else os.path.join(VIDEOS_DIR, lang)
    os.makedirs(lang_dir, exist_ok=True)

    # 1. 16:9 Google Play Trailer (30s at 30fps)
    if do_trailer:
        trailer_name = "rocis_schedule_playstore_trailer_16x9.mp4" if lang == "en" else f"rocis_schedule_playstore_trailer_16x9_{lang}.mp4"
        trailer_output = os.path.join(lang_dir, trailer_name)
        frames_trailer = await render_video_frames(
            HTML_TRAILER, 1920, 1080, total_seconds=30.0, fps=30, seek_fn="seekToTime", prefix="trailer_16x9", lang=lang
        )
        encode_mp4_with_ffmpeg(frames_trailer, trailer_output, fps=30, width=1920, height=1080)
        shutil.rmtree(frames_trailer, ignore_errors=True)

    # 2. 9:16 Vertical Shorts Video (15s at 30fps)
    if do_shorts:
        shorts_name = "rocis_tasks_shorts_9x16.mp4" if lang == "en" else f"rocis_tasks_shorts_9x16_{lang}.mp4"
        shorts_output = os.path.join(lang_dir, shorts_name)
        frames_shorts = await render_video_frames(
            HTML_SHORTS, 1080, 1920, total_seconds=15.0, fps=30, seek_fn="seekShortsTime", prefix="shorts_9x16", lang=lang
        )
        encode_mp4_with_ffmpeg(frames_shorts, shorts_output, fps=30, width=1080, height=1920)
        shutil.rmtree(frames_shorts, ignore_errors=True)

async def main():
    os.makedirs(VIDEOS_DIR, exist_ok=True)
    os.makedirs(TEMP_FRAMES_DIR, exist_ok=True)

    do_shorts_only = "--shorts" in sys.argv
    do_trailer_only = "--trailer" in sys.argv
    do_trailer = not do_shorts_only
    do_shorts = not do_trailer_only

    target_langs = [a for a in sys.argv[1:] if not a.startswith("--")] or ["en"]
    for lang in target_langs:
        await render_for_language(lang, do_trailer=do_trailer, do_shorts=do_shorts)

    print("\n[ALL OK] All requested marketing videos generated successfully!")

if __name__ == "__main__":
    asyncio.run(main())
