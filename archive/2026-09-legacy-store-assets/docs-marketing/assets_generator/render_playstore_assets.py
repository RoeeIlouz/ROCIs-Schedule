import os
import sys
import json
import asyncio

# Ensure UTF-8 output encoding on Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

from playwright.async_api import async_playwright

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "playstore"))
HTML_FILE = os.path.abspath(os.path.join(BASE_DIR, "screenshots.html"))
LOCALES_FILE = os.path.join(BASE_DIR, "locales.json")

async def render_language(page, lang, info, file_url):
    playstore_locale = info.get("playstore_locale", lang)
    lang_dir = os.path.join(OUTPUT_DIR, playstore_locale)
    os.makedirs(lang_dir, exist_ok=True)

    print(f"\n==========================================")
    print(f"[*] Rendering Play Store Assets: {info.get('name', lang)} ({lang}) -> {playstore_locale}")
    print(f"==========================================")

    url_with_lang = f"{file_url}?lang={lang}"
    await page.goto(url_with_lang, wait_until="networkidle")
    await page.evaluate(f"() => typeof applyLanguage === 'function' && applyLanguage('{lang}')")
    await page.wait_for_timeout(2200)

    # Render Slides 1 to 8
    for i in range(1, 9):
        element_id = f"#slide-{i}"
        element = await page.query_selector(element_id)
        if element:
            out_path = os.path.join(lang_dir, f"screenshot_0{i}.png")
            await element.screenshot(path=out_path)
            if lang == "en":
                await element.screenshot(path=os.path.join(OUTPUT_DIR, f"screenshot_0{i}.png"))
            print(f"  [OK] Screenshot {i}/8 -> {out_path}")
        else:
            print(f"  [WARN] Missing {element_id}")

    # Render Feature Graphic
    fg_elem = await page.query_selector("#feature-graphic")
    if fg_elem:
        fg_path = os.path.join(lang_dir, "feature_graphic.png")
        await fg_elem.screenshot(path=fg_path)
        if lang == "en":
            await fg_elem.screenshot(path=os.path.join(OUTPUT_DIR, "feature_graphic.png"))
        print(f"  [OK] Feature Graphic (1024x500) -> {fg_path}")
    else:
        print(f"  [WARN] Missing #feature-graphic")

async def generate_all_assets():
    with open(LOCALES_FILE, "r", encoding="utf-8") as f:
        locales = json.load(f)

    target_langs = sys.argv[1:] if len(sys.argv) > 1 else list(locales.keys())

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"[*] Root Output Directory: {OUTPUT_DIR}")
    print(f"[*] Target Languages ({len(target_langs)}): {', '.join(target_langs)}")

    file_url = f"file:///{HTML_FILE.replace(os.sep, '/')}"

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            args=['--allow-file-access-from-files', '--no-sandbox', '--disable-web-security']
        )
        page = await browser.new_page(viewport={"width": 1920, "height": 3200}, device_scale_factor=1)

        for lang in target_langs:
            if lang in locales:
                await render_language(page, lang, locales[lang], file_url)
            else:
                print(f"[WARN] Unknown locale code: {lang}")

        await browser.close()
        print("\n[ALL OK] All Play Store screenshots and feature graphics rendered successfully across all languages!")

if __name__ == "__main__":
    asyncio.run(generate_all_assets())
