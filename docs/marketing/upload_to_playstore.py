import os
import sys
import glob
import json
import time
import base64
import argparse
import requests

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_pem_private_key

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, "..", ".."))
DEFAULT_METADATA_FILE = os.path.join(BASE_DIR, "store_listings_metadata.json")
DEFAULT_SOURCE_DIR = os.path.join(BASE_DIR, "playstore")
DEFAULT_PACKAGE_NAME = "com.rocisapps.schedule"

def find_credentials():
    env_path = os.environ.get("PLAY_STORE_CREDENTIALS")
    if env_path and os.path.exists(env_path):
        return env_path
    candidates = glob.glob(os.path.join(PROJECT_ROOT, "ignored", "*.json"))
    candidates += glob.glob(os.path.join(PROJECT_ROOT, "..", "ROCIs-tasks", "ignored", "*.json"))
    for c in candidates:
        try:
            with open(c, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "client_email" in data and "private_key" in data:
                    return c
        except Exception:
            pass
    return None

def get_access_token(credentials_path):
    with open(credentials_path, "r", encoding="utf-8") as f:
        creds = json.load(f)

    client_email = creds["client_email"]
    private_key_pem = creds["private_key"].encode("utf-8")
    token_uri = creds.get("token_uri", "https://oauth2.googleapis.com/token")

    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    payload = {
        "iss": client_email,
        "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": token_uri,
        "exp": now + 3600,
        "iat": now
    }

    def b64_url(b):
        return base64.urlsafe_b64encode(b).decode("utf-8").rstrip("=")

    seg1 = b64_url(json.dumps(header).encode("utf-8"))
    seg2 = b64_url(json.dumps(payload).encode("utf-8"))
    to_sign = f"{seg1}.{seg2}".encode("utf-8")

    private_key = load_pem_private_key(private_key_pem, password=None)
    sig = private_key.sign(to_sign, padding.PKCS1v15(), hashes.SHA256())
    jwt = f"{seg1}.{seg2}.{b64_url(sig)}"

    resp = requests.post(token_uri, data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": jwt
    }, timeout=30)

    if resp.status_code != 200:
        raise RuntimeError(f"Failed to obtain OAuth2 access token: {resp.status_code} - {resp.text}")

    return resp.json()["access_token"]

def main():
    parser = argparse.ArgumentParser(description="Upload screenshots, feature graphics, and listings to Google Play Store.")
    parser.add_argument("--credentials", help="Path to Google Play Service Account JSON key")
    parser.add_argument("--package-name", default=DEFAULT_PACKAGE_NAME, help="Android package name (applicationId)")
    parser.add_argument("--source-dir", default=DEFAULT_SOURCE_DIR, help="Directory containing locale asset folders")
    parser.add_argument("--locales", nargs="+", help="Specific locales to upload (e.g. en-US iw-IL)")
    parser.add_argument("--metadata-file", default=DEFAULT_METADATA_FILE, help="Path to store_listings_metadata.json")
    parser.add_argument("--skip-listings", action="store_true", help="Skip creating/updating text listings")
    parser.add_argument("--commit", action="store_true", help="Commit changes to Google Play production listing (default is dry-run)")

    args = parser.parse_args()

    is_live_commit = args.commit

    creds_path = args.credentials or find_credentials()
    if not creds_path:
        print("[ERROR] Could not find Google Play Service Account JSON credentials.")
        print("Please provide --credentials <path_to_json> or place it in ignored/ folder.")
        sys.exit(1)

    print("=" * 60)
    print("ROCIs Tasks - Google Play Store Asset Uploader")
    print("=" * 60)
    print(f"[*] Package Name:     {args.package_name}")
    print(f"[*] Credentials File: {creds_path}")
    print(f"[*] Source Directory: {args.source_dir}")
    print(f"[*] Mode:             {'LIVE COMMIT' if is_live_commit else 'DRY RUN (Changes will be safely discarded)'}")
    print("=" * 60)

    # 1. Authenticate
    print("\n[1/4] Authenticating with Google Play Developer API...")
    token = get_access_token(creds_path)
    headers = {"Authorization": f"Bearer {token}"}
    print("[OK] Authenticated successfully!")

    # 2. Open Edit Draft
    print("\n[2/4] Opening Play Store Edit session...")
    edit_url = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{args.package_name}/edits"
    edit_resp = requests.post(edit_url, headers=headers, timeout=30)
    if edit_resp.status_code != 200:
        print(f"[ERROR] Failed to create edit: {edit_resp.status_code} - {edit_resp.text}")
        sys.exit(1)

    edit_id = edit_resp.json()["id"]
    print(f"[OK] Active Edit ID: {edit_id}")

    # Load metadata if available
    metadata_map = {}
    if os.path.exists(args.metadata_file) and not args.skip_listings:
        with open(args.metadata_file, "r", encoding="utf-8") as f:
            metadata_map = json.load(f)

    # Identify target locales
    available_locales = [
        d for d in os.listdir(args.source_dir)
        if os.path.isdir(os.path.join(args.source_dir, d))
    ]
    target_locales = args.locales if args.locales else available_locales

    print(f"[*] Target Locales ({len(target_locales)}): {', '.join(target_locales)}")

    success_summary = []
    error_summary = []

    try:
        listings_url = f"{edit_url}/{edit_id}/listings"
        existing_listings_resp = requests.get(listings_url, headers=headers, timeout=30)
        existing_locales = set()
        if existing_listings_resp.status_code == 200:
            for l in existing_listings_resp.json().get("listings", []):
                existing_locales.add(l.get("language"))

        print("\n[3/4] Processing locale listings and assets...")

        for locale in target_locales:
            print(f"\n--- Processing Locale: {locale} ---")
            locale_dir = os.path.join(args.source_dir, locale)
            if not os.path.exists(locale_dir):
                print(f"  [WARN] Directory not found: {locale_dir}, skipping.")
                continue

            # A. Ensure Listing Exists
            if not args.skip_listings and locale in metadata_map:
                meta = metadata_map[locale]
                listing_locale_url = f"{listings_url}/{locale}"
                listing_body = {
                    "language": locale,
                    "title": meta.get("title", "ROCIs Tasks"),
                    "shortDescription": meta.get("shortDescription", ""),
                    "fullDescription": meta.get("fullDescription", "")
                }
                
                listing_res = requests.put(
                    listing_locale_url,
                    headers={**headers, "Content-Type": "application/json"},
                    json=listing_body,
                    timeout=30
                )
                if listing_res.status_code in [200, 201]:
                    print(f"  [OK] Listing text configured for {locale} ('{listing_body['title']}')")
                else:
                    print(f"  [WARN] Failed to set listing text for {locale}: {listing_res.status_code} - {listing_res.text}")

            # B. Clear existing phone screenshots
            del_screenshots_url = f"{listings_url}/{locale}/phoneScreenshots"
            requests.delete(del_screenshots_url, headers=headers, timeout=30)

            # C. Upload new phone screenshots in order
            screenshots = sorted([
                f for f in os.listdir(locale_dir)
                if f.startswith("screenshot_") and f.endswith(".png")
            ])

            upload_screen_url = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{args.package_name}/edits/{edit_id}/listings/{locale}/phoneScreenshots?uploadType=media"
            uploaded_screens = 0

            for sc_file in screenshots:
                sc_path = os.path.join(locale_dir, sc_file)
                with open(sc_path, "rb") as img_file:
                    sc_data = img_file.read()
                
                # Upload with exponential retry on 5xx or transient errors
                max_retries = 3
                success = False
                for attempt in range(1, max_retries + 1):
                    sc_resp = requests.post(
                        upload_screen_url,
                        headers={"Authorization": f"Bearer {token}", "Content-Type": "image/png"},
                        data=sc_data,
                        timeout=60
                    )
                    if sc_resp.status_code in [200, 201]:
                        uploaded_screens += 1
                        print(f"  [OK] Uploaded {sc_file} ({uploaded_screens}/{len(screenshots)})")
                        success = True
                        break
                    elif sc_resp.status_code in [500, 502, 503, 504, 429] and attempt < max_retries:
                        print(f"  [RETRY] Got {sc_resp.status_code} for {sc_file}, retrying in {attempt * 2}s (attempt {attempt}/{max_retries})...")
                        time.sleep(attempt * 2)
                    else:
                        print(f"  [FAIL] Failed to upload {sc_file}: {sc_resp.status_code} - {sc_resp.text}")
                        break

            # D. Clear & Upload Feature Graphic
            fg_path = os.path.join(locale_dir, "feature_graphic.png")
            fg_uploaded = False
            if os.path.exists(fg_path):
                del_fg_url = f"{listings_url}/{locale}/featureGraphic"
                requests.delete(del_fg_url, headers=headers, timeout=30)

                upload_fg_url = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{args.package_name}/edits/{edit_id}/listings/{locale}/featureGraphic?uploadType=media"
                with open(fg_path, "rb") as fg_file:
                    fg_data = fg_file.read()

                for attempt in range(1, 4):
                    fg_resp = requests.post(
                        upload_fg_url,
                        headers={"Authorization": f"Bearer {token}", "Content-Type": "image/png"},
                        data=fg_data,
                        timeout=60
                    )
                    if fg_resp.status_code in [200, 201]:
                        fg_uploaded = True
                        print(f"  [OK] Uploaded feature_graphic.png (1024x500)")
                        break
                    elif fg_resp.status_code in [500, 502, 503, 504, 429] and attempt < 3:
                        print(f"  [RETRY] Got {fg_resp.status_code} for feature_graphic.png, retrying in {attempt * 2}s...")
                        time.sleep(attempt * 2)
                    else:
                        print(f"  [FAIL] Failed to upload feature_graphic.png: {fg_resp.status_code} - {fg_resp.text}")
                        break

            success_summary.append({
                "locale": locale,
                "screenshots": uploaded_screens,
                "feature_graphic": fg_uploaded
            })

    except Exception as e:
        print(f"\n[FATAL ERROR] An exception occurred during processing: {e}")
        error_summary.append(str(e))
    finally:
        print("\n" + "=" * 60)
        print("[4/4] Finishing Session...")
        print("=" * 60)

        if is_live_commit and not error_summary:
            print("[*] Committing Edit Draft to Google Play...")
            commit_url = f"{edit_url}/{edit_id}:commit"
            commit_resp = requests.post(commit_url, headers=headers, timeout=60)
            if commit_resp.status_code in [200, 201]:
                print("\n[SUCCESS] All assets and listings were COMMITTED to Google Play Store!")
            else:
                print(f"\n[ERROR] Commit failed: {commit_resp.status_code} - {commit_resp.text}")
                requests.delete(f"{edit_url}/{edit_id}", headers=headers, timeout=30)
        else:
            print("[*] Dry run mode active: Cleaning up and deleting edit session safely...")
            requests.delete(f"{edit_url}/{edit_id}", headers=headers, timeout=30)
            print("[OK] Edit draft deleted. Zero changes were written to production.")

    print("\n==========================================")
    print("Execution Summary")
    print("==========================================")
    for s in success_summary:
        print(f"  Locale: {s['locale']:<7} | Screenshots: {s['screenshots']}/8 | Feature Graphic: {'OK' if s['feature_graphic'] else 'Missing'}")

    if not is_live_commit:
        print("\nTo execute the live commit to Google Play Store, run:")
        print("   python docs/marketing/upload_to_playstore.py --commit")

if __name__ == "__main__":
    main()
