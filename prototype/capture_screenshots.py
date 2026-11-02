import os
import time
from playwright.sync_api import sync_playwright

OUTPUT_DIR = "d:/NutriViet/docs/requirements/assets/prototypes"
os.makedirs(OUTPUT_DIR, exist_ok=True)

HTML_PATH = "file:///D:/NutriViet/prototype/index.html"

SCREENS = [
    ("auth-register", "uc01_register.png"),
    ("auth-login", "uc02_login.png"),
    ("profile-allergens", "uc04_uc05_health_profile.png"),
    ("scanner-camera", "uc06_camera_scanner.png"),
    ("scanner-crop", "uc07_crop_adjust.png"),
    ("scanner-history", "uc08_scan_history.png"),
    ("alert-red", "uc09_alert_red.png"),
    ("alert-yellow", "uc09_alert_yellow.png"),
    ("alert-green", "uc09_alert_green.png"),
    ("alternatives-view", "uc10_safe_alternatives.png"),
    ("diary-nutrition", "uc11_diary_nutrition.png"),
    ("diary-reaction", "uc12_diary_reaction.png"),
    ("shopping-list", "uc13_uc14_shopping_list.png"),
    ("crowdsource-submit", "uc15_crowdsource_submit.png"),
    ("crowdsource-report", "uc16_ocr_discrepancy.png"),
    ("admin-moderation", "uc17_admin_moderation.png"),
    ("admin-dictionary", "uc18_admin_dictionary.png")
]

def main():
    print(f"Starting capture to {OUTPUT_DIR}...", flush=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1400, "height": 1000}, device_scale_factor=2)
        print(f"Navigating to {HTML_PATH}...", flush=True)
        page.goto(HTML_PATH, wait_until="domcontentloaded", timeout=10000)
        time.sleep(1)

        for screen_id, filename in SCREENS:
            print(f"Switching to {screen_id}...", flush=True)
            page.evaluate(f"window.switchScreen('{screen_id}')")
            time.sleep(0.3)

            target = page.locator("#deviceFrame")
            out_path = os.path.join(OUTPUT_DIR, filename)
            target.screenshot(path=out_path)
            print(f"Captured: {filename}", flush=True)

        browser.close()
        print("SUCCESS: All prototype screenshots captured!", flush=True)

if __name__ == "__main__":
    main()
