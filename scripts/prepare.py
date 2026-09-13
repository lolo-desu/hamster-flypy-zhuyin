#!/usr/bin/env python3
"""Assemble pinned upstream projects plus a small, reviewable display patch."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "upstream.lock.json").read_text())

def run(*args, cwd=None):
    subprocess.run(args, cwd=cwd, check=True)

def checkout(name, dst, recursive=False):
    spec = LOCK[name]
    if not (dst / ".git").exists():
        run("git", "init", str(dst))
        run("git", "remote", "add", "origin", spec["url"], cwd=dst)
        run("git", "fetch", "--depth", "1", "origin", spec["commit"], cwd=dst)
        run("git", "checkout", "--detach", "FETCH_HEAD", cwd=dst)
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=dst, text=True).strip()
    if actual != spec["commit"]:
        raise RuntimeError(f"Unexpected source revision: {dst}: {actual}")
    if recursive:
        run("git", "submodule", "update", "--init", "--recursive", "--depth", "1", cwd=dst)

def zip_tree(src, dst):
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(src.rglob("*")):
            if p.is_file() and not any(part.startswith(".") for part in p.relative_to(src).parts):
                z.write(p, p.relative_to(src).as_posix())

def package_frost(frost, hamster):
    resources = hamster / "Resources/SharedSupport"
    resources.mkdir(parents=True, exist_ok=True)
    # Keep every upstream dictionary weight, Lua filter, .gram and translator
    # option unchanged. Only select Flypy as the default/sole visible schema.
    patch = 'patch:\n  schema_list:\n    - schema: rime_frost_double_pinyin_flypy\n'
    with zipfile.ZipFile(resources / "rime-ice.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(frost.rglob("*")):
            if p.is_file() and not any(part.startswith(".") for part in p.relative_to(frost).parts):
                z.write(p, p.relative_to(frost).as_posix())
        z.writestr("default.custom.yaml", patch)
    # Legacy filename is required by Hamster's existing first-run importer.
    # The shared fallback has OpenCC data and upstream defaults, no duplicate
    # dictionary corpus. All input data is bundled, with no runtime download.
    with zipfile.ZipFile(resources / "SharedSupport.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for name in ("default.yaml", "key_bindings.yaml", "punctuation.yaml"):
            z.write(frost / name, name)
        z.writestr("default.custom.yaml", patch)
        z.write(resources / "hamster.yaml", "hamster.yaml")
        for p in sorted((frost / "opencc").rglob("*")):
            if p.is_file(): z.write(p, p.relative_to(frost).as_posix())


def prepare_app(work):
    hamster, frost = work / "Hamster", work / "rime-frost"
    checkout("hamster", hamster)
    checkout("frost", frost)
    patch = ROOT / "patches/hamster.patch"
    applied = subprocess.run(["git", "apply", "--reverse", "--check", str(patch)], cwd=hamster, capture_output=True).returncode == 0
    if not applied: run("git", "apply", "--check", str(patch), cwd=hamster); run("git", "apply", str(patch), cwd=hamster)
    shutil.copy2(ROOT / "src/FlypyZhuyin.swift", hamster / "Packages/HamsterKeyboardKit/Sources/FlypyZhuyin.swift")
    package_frost(frost, hamster)


def prepare_frameworks(work):
    fw = work / "LibrimeKit-iOS"
    checkout("frameworks", fw, recursive=True)
    librime = fw / "deps/librime"
    checkout("lua", librime / "plugins/lua")
    checkout("lua_source", librime / "plugins/lua/thirdparty")
    checkout("octagram", librime / "plugins/octagram")
    # Force static linkage and default registration, just as upstream does for
    # Lua; silently dropping octagram would alter Frost's candidate ranking.
    api = librime / "src/rime_api.cc"
    text = api.read_text()
    marker = "  // Flypy Zhuyin: force-link octagram"
    if marker not in text:
        anchor = "  rime_require_module_levers();"
        assert text.count(anchor) == 1
        text = text.replace(anchor, anchor + "\n" + marker + "\n  extern void rime_require_module_octagram();\n  rime_require_module_octagram();")
        api.write_text(text)
    cmake = librime / "plugins/octagram/CMakeLists.txt"
    text = cmake.read_text().replace('option(BUILD_TOOLS "Build tools" ON)', 'option(BUILD_TOOLS "Build tools" OFF)')
    cmake.write_text(text)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, default=ROOT / "work")
    ap.add_argument("--frameworks", action="store_true")
    args = ap.parse_args()
    args.work = args.work.resolve()
    args.work.mkdir(parents=True, exist_ok=True)
    prepare_frameworks(args.work) if args.frameworks else prepare_app(args.work)
