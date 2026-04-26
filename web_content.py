import subprocess

WEB_DIR = "web"
DATA_DIR = "data"

def build_web(target, source, env):
    print("Building Astro web UI...")

    # Run Astro build
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

def generate_aliases(target, source, env):
    env.Alias("webfs", source)
    return None

Import("env")
env.AddPreAction("$BUILD_DIR/${PROGNAME}.bin", build_web)
