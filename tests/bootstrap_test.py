from __future__ import annotations

import pathlib
import sys
import time

APK = "https://f-droid.org/repo/com.termux.nix_188037.apk"
BOOTSTRAP_URL = "file:///data/local/tmp"
SCREENSHOTS_DIR = pathlib.Path("screenshots")


def screenshot(d, suffix: str = "") -> None:
    SCREENSHOTS_DIR.mkdir(exist_ok=True, parents=True)
    fname_base = SCREENSHOTS_DIR / f"{time.time():.3f}-{suffix}"
    d.ui.screenshot(f"{fname_base}.png")
    xml_content = d.ui.dump_hierarchy()
    pathlib.Path(f"{fname_base}.xml").write_text(xml_content, encoding="utf-8")
    print(f"screenshotted: {fname_base}.{{png,xml}}")


def wait_for(d, on_screen_text: str, timeout: int = 30, critical: bool = True) -> None:
    start = time.monotonic()
    last_displayed_time: int | None = None
    while (elapsed := time.monotonic() - start) < timeout:
        display_time = int(timeout - elapsed)
        if display_time != last_displayed_time:
            print(f"waiting for `{on_screen_text}`: {display_time}s...")
            sys.stdout.flush()
            last_displayed_time = display_time
        if on_screen_text in d.ui.dump_hierarchy():
            print(f"found: {on_screen_text} after {elapsed:.1f}s")
            return
        time.sleep(1.5)
    print(f"NOT FOUND: {on_screen_text} after {timeout}s")
    screenshot(d, suffix="error")
    if critical:
        sys.exit(1)


def run_cmd(d, cmd: str, wait: int = 1) -> None:
    d(f"input text {cmd!r}")
    d.ui.press("enter")
    time.sleep(wait)


def run(d):
    nod = d.app("com.termux.nix", url=APK)
    nod.permissions.allow_notifications()
    nod.launch()
    time.sleep(2)

    wait_for(d, "Bootstrap zipball location")
    screenshot(d, "bootstrap-prompt")

    d.ui(className="android.widget.EditText").set_text(BOOTSTRAP_URL)
    time.sleep(1)
    screenshot(d, "url-entered")

    d.ui(text="OK").click()
    screenshot(d, "ok-clicked")

    wait_for(d, "Welcome to Nix-on-Droid!")
    screenshot(d, "welcome-screen")

    wait_for(d, "Initializing Nix-on-Droid")
    screenshot(d, "init-screen")

    wait_for(d, "Initialization complete", timeout=600)
    wait_for(d, "sh-")

    screenshot(d, "bootstrap-complete")

    run_cmd(d, "nix --version", wait=3)
    run_cmd(d, 'nix eval --expr "1 + 1"', wait=3)
    run_cmd(d, "nix shell nixpkgs#fastfetch --command fastfetch --version", wait=60)

    screenshot(d, "nix-tests-complete")
    print("✓ Bootstrap test completed successfully")

    return nod
