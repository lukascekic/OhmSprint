import subprocess
import os
import re

WEB_DIR = "web"
DATA_DIR = "data"

def rename_long_filenames(data_dir):
    static_dir = os.path.join(data_dir, "static")
    if not os.path.isdir(static_dir):
        return

    rename_map = {}
    for fname in os.listdir(static_dir):
        if "astro_astro_type_script" in fname and fname.endswith(".js"):
            rename_map[fname] = "bundle.js"
        elif fname.endswith(".css"):
            rename_map[fname] = "styles.css"

    for old_name, new_name in rename_map.items():
        old_path = os.path.join(static_dir, old_name)
        new_path = os.path.join(static_dir, new_name)
        if os.path.exists(old_path):
            os.rename(old_path, new_path)
            print(f"Renamed: {old_name} -> {new_name}")

    for html_file in ["index.html", "configure/index.html"]:
        html_path = os.path.join(data_dir, html_file)
        if os.path.exists(html_path):
            with open(html_path, "r") as f:
                content = f.read()
            for old_name, new_name in rename_map.items():
                content = content.replace(old_name, new_name)
            with open(html_path, "w") as f:
                f.write(content)

def build_web(target, source, env):
    print("Building Astro web UI...")

    result = subprocess.run(
        ["pnpm", "--dir", WEB_DIR, "run", "build"],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        raise RuntimeError(f"Astro build failed with code {result.returncode}")

    print("Astro build complete.")
    print(f"Files written to {DATA_DIR}/ for LittleFS packaging.")

    rename_long_filenames(DATA_DIR)

def generate_aliases(target, source, env):
    env.Alias("webfs", source)
    return None

Import("env")
env.AddPreAction("$BUILD_DIR/${PROGNAME}.bin", build_web)
