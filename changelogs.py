import argparse
from itertools import product
import subprocess
import json
import time
from typing import Any
import re
from collections import defaultdict

REGISTRY = "docker://ghcr.io/m2giles/"

IMAGE_MATRIX = {
    "image": ["aurora", "cosmic", "bluefin", "ucore"],
    "image_flavor": ["main", "nvidia"],
}

BAZZITE_IMAGE_MATRIX = {
    "image": ["bazzite"],
    "image_flavor": ["main", "nvidia"]
}

RETRIES = 3
RETRY_WAIT = 5
FEDORA_PATTERN = re.compile(r"\.fc\d\d")
START_PATTERN = lambda img: re.compile(rf"{img}-[0-9]+")
STRIP_PATTERN = lambda strip: re.sub(r"[a-z]+-","", re.sub(r"[a-z]+-","", strip))

PATTERN_ADD = "\n| ✨ | {name} | | {version} |"
PATTERN_CHANGE = "\n| 🔄 | {name} | {prev} | {new} |"
PATTERN_REMOVE = "\n| ❌ | {name} | {version} | |"
PATTERN_PKGREL_CHANGED = "{prev} ➡️ {new}"
PATTERN_PKGREL = "{version}"
COMMON_PAT = "### All Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n"
DESKTOP_PAT = "### Desktop Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n"
OTHER_NAMES = {
    "aurora": "### [Aurora Images](https://getaurora.dev/)\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
    "bluefin": "### [Bluefin Images](https://projectbluefin.io/)\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
    "cosmic": "### Cosmic Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
    "bazzite": "### [Bazzite Images](https://bazzite.gg)\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
    "ucore": "### Ucore Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
    "nvidia": "### Nvidia Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
}

COMMITS_FORMAT = "### Commits\n| Hash | Subject |\n| --- | --- |{commits}\n\n"
COMMIT_FORMAT = "\n| **[{short}](https://github.com/m2giles/m2os/commit/{githash})** | {subject} |"

CHANGELOG_TITLE = "m2os {pretty}"
CHANGELOG_FORMAT = """\
{handwritten}

From previous m2os version `{prev}` there have been the following changes. **One package per new version shown.**

### Major packages
| Name | Version |
| --- | --- |
| **Kernel** | {pkgrel:kernel} |
| **Mesa** | {pkgrel:mesa-dri-drivers} |
| **Podman** | {pkgrel:podman} |
| **Docker** | {pkgrel:docker-ce} |
| **Incus** | {pkgrel:incus} |

{changes}"""

HANDWRITTEN_PLACEHOLDER = """\
This is an automatically generated changelog for release `{curr}`."""

BLACKLIST_VERSIONS = [
    "kernel",
    "mesa-dri-drivers",
    "podman",
    "docker-ce",
    "incus"
]


def get_images(target: str):
    if "bazzite" in target:
        matrix = BAZZITE_IMAGE_MATRIX
    else:
        matrix = IMAGE_MATRIX

    for image, image_flavor in product(*matrix.values()):
        img = image

        if image == "bazzite":
            if image_flavor == "main":
                img += "-deck"
        else:
            if image_flavor == "nvidia":
                img += "-nvidia"

        yield img, image, image_flavor


def get_manifests(imgs):
    out = {}
    imgs = list(imgs)
    j = 0
    for img in imgs:
        output = None
        print(f"Getting m2os:{img} manifest ({j+1}/{len(imgs)}).")
        for i in range(RETRIES):
            try:
                output = subprocess.run(
                    ["skopeo", "inspect", REGISTRY + "m2os" + ":" + img],
                    check=True,
                    stdout=subprocess.PIPE,
                ).stdout
                break
            except subprocess.CalledProcessError:
                print(
                    f"Failed to get m2os:{img}, retrying in {RETRY_WAIT} seconds ({i+1}/{RETRIES})"
                )
                time.sleep(RETRY_WAIT)
        if output is None:
            print(f"Failed to get m2os:{img}, skipping")
            continue
        out[img] = json.loads(output)
        j += 1
    return out


def get_tags(target: str, manifests: dict[str, Any]):
    prev_tags = []
    curr_tags = []
    imgs = list(get_images(target))
    for img in imgs:
        tags = set()
        for manifest in manifests.values():
            for tag in manifest["RepoTags"]:
                # Tags ending with .0 should not exist
                if tag.endswith(".0"):
                    continue
                if re.match(START_PATTERN(img[0]), tag):
                    tags.add(tag)

                    version = STRIP_PATTERN(tag)
                    for check_img in imgs:
                        if f"{check_img[0]}-{version}" not in manifest["RepoTags"]:
                            try:
                                tags.remove(tag)
                            except:
                                continue

        tags = list(sorted(tags))
        if not len(tags) >= 2:
            print("No current and previous tags found")
            exit(1)
        prev_tags.append(tags[-2]), curr_tags.append(tags[-1])
    prev_tags.sort()
    curr_tags.sort()
    return prev_tags, curr_tags 


def get_packages(manifests: dict[str, Any]):
    packages = {}
    for img, manifest in manifests.items():
        try:
            packages[img] = json.loads(manifest["Labels"]["dev.hhd.rechunk.info"])[
                "packages"
            ]
        except Exception as e:
            print(f"Failed to get packages for {img}:\n{e}")
    return packages


def get_package_groups(target: str, prev: dict[str, Any], manifests: dict[str, Any]):
    common = set()
    desktop = set()
    others = {k: set() for k in OTHER_NAMES.keys()}

    npkg = get_packages(manifests)
    ppkg = get_packages(prev)

    keys = set(npkg.keys()) | set(ppkg.keys())
    pkg = defaultdict(set)
    for k in keys:
        pkg[k] = set(npkg.get(k, {})) | set(ppkg.get(k, {}))

    # Find common packages
    first = True
    for img, image, image_flavor in get_images(target):
        if img not in pkg:
            continue

        if first:
            for p in pkg[img]:
                common.add(p)
        else:
            for c in common.copy():
                if c not in pkg[img]:
                    common.remove(c)

        first = False

    # Desktop common packages
    first = True
    for img, image, image_flavor in get_images(target):
        if image not in ["aurora", "bluefin", "cosmic"]:
            continue
        if img not in pkg:
            continue

        if first:
            for p in pkg[img]:
                if p not in common:
                    desktop.add(p)
        else:
            for c in desktop.copy():
                if c not in pkg[img]:
                    desktop.remove(c)

        first = False

    # Find other packages
    for t, other in others.items():
        first = True
        for img, image, image_flavor in get_images(target):
            if img not in pkg:
                continue

            if t == "main" and "main" not in image_flavor:
                continue
            if t == "nvidia" and "nvidia" not in image_flavor:
                continue
            if t == "aurora" and image != "aurora":
                continue
            if t == "bluefin" and image != "bluefin":
                continue
            if t == "bazzite" and image != "bazzite":
                continue
            if t == "cosmic" and image != "cosmic":
                continue
            if t == "ucore" and image != "ucore":
                continue

            if first:
                for p in pkg[img]:
                    if p not in common:
                        if p not in desktop:
                            other.add(p)
            else:
                for c in other.copy():
                    if c not in pkg[img]:
                        other.remove(c)

            first = False

    return sorted(common), sorted(desktop), {k: sorted(v) for k, v in others.items()}


def get_versions(manifests: dict[str, Any]):
    versions = {}
    pkgs = get_packages(manifests)
    for img_pkgs in pkgs.values():
        for pkg, v in img_pkgs.items():
            versions[pkg] = re.sub(FEDORA_PATTERN, "", v)
    return versions


def calculate_changes(pkgs: list[str], prev: dict[str, str], curr: dict[str, str]):
    added = []
    changed = []
    removed = []

    blacklist_ver = set([curr.get(v, None) for v in BLACKLIST_VERSIONS])

    for pkg in pkgs:
        # Clearup changelog by removing mentioned packages
        if pkg in BLACKLIST_VERSIONS:
            continue
        if pkg in curr and curr.get(pkg, None) in blacklist_ver:
            continue
        if pkg in prev and prev.get(pkg, None) in blacklist_ver:
            continue

        if pkg not in prev:
            added.append(pkg)
        elif pkg not in curr:
            removed.append(pkg)
        elif prev[pkg] != curr[pkg]:
            changed.append(pkg)

        blacklist_ver.add(curr.get(pkg, None))
        blacklist_ver.add(prev.get(pkg, None))

    out = ""
    for pkg in added:
        out += PATTERN_ADD.format(name=pkg, version=curr[pkg])
    for pkg in changed:
        out += PATTERN_CHANGE.format(name=pkg, prev=prev[pkg], new=curr[pkg])
    for pkg in removed:
        out += PATTERN_REMOVE.format(name=pkg, version=prev[pkg])
    return out


def get_commits(prev_manifests, manifests, workdir: str):
    try:
        start = next(iter(prev_manifests.values()))["Labels"][
            "org.opencontainers.image.revision"
        ]
        finish = next(iter(manifests.values()))["Labels"][
            "org.opencontainers.image.revision"
        ]

        commits = subprocess.run(
            [
                "git",
                "-C",
                workdir,
                "log",
                "--pretty=format:%H %h %s",
                f"{start}..{finish}",
            ],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout.decode("utf-8")

        out = ""
        for commit in commits.split("\n"):
            if not commit:
                continue
            githash, short, subject = commit.split(" ", 2)

            if subject.lower().startswith("merge"):
                continue

            out += (
                COMMIT_FORMAT.replace("{short}", short)
                .replace("{subject}", subject)
                .replace("{githash}", githash)
            )

        if out:
            return COMMITS_FORMAT.format(commits=out)
        return ""
    except Exception as e:
        print(f"Failed to get commits:\n{e}")
        return ""


def generate_changelog(
    handwritten: str | None,
    urlmd: str | None,
    target: str,
    pretty: str | None,
    workdir: str,
    prev_manifests,
    manifests,
):
    common, desktop, others = get_package_groups(target, prev_manifests, manifests)
    versions = get_versions(manifests)
    prev_versions = get_versions(prev_manifests)

    prev_tags, curr_tags = get_tags(target, manifests)

    if not pretty:
        # Generate pretty version since we dont have it
        try:
            finish: str = next(iter(manifests.values()))["Labels"][
                "org.opencontainers.image.revision"
            ]
        except Exception as e:
            print(f"Failed to get finish hash:\n{e}")
            finish = ""

        # Remove .0 from curr
        for curr in curr_tags:
            curr_pretty = re.sub(r"\.\d{1,2}$", "", curr)
            # Remove target- from curr
            curr_pretty = STRIP_PATTERN(curr_pretty)
            pretty = target.capitalize() + " (F" + curr_pretty
            if finish and target != "stable":
                pretty += ", #" + finish[:7]
            pretty += ")"

    title = CHANGELOG_TITLE.format_map(defaultdict(str, tag=STRIP_PATTERN(curr_tags[0]), pretty=pretty))

    changelog = CHANGELOG_FORMAT

    changelog = (
        changelog.replace("{handwritten}", handwritten if handwritten else HANDWRITTEN_PLACEHOLDER)
        .replace("{target}", target)
        .replace("{prev}", f"{STRIP_PATTERN(prev_tags[0])}")
        .replace("{curr}", f"{STRIP_PATTERN(curr_tags[0])}")
    )
    if urlmd:
        with open(urlmd, "r") as f:
            changelog = f"{changelog}### ISO Downloads\n| Image |\n| --- |\n{f.read()}\n\n"

    for pkg, v in versions.items():
        if pkg not in prev_versions or prev_versions[pkg] == v:
            changelog = changelog.replace(
                "{pkgrel:" + pkg + "}", PATTERN_PKGREL.format(version=v)
            )
        else:
            changelog = changelog.replace(
                "{pkgrel:" + pkg + "}",
                PATTERN_PKGREL_CHANGED.format(prev=prev_versions[pkg], new=v),
            )

    changes = ""
    changes += get_commits(prev_manifests, manifests, workdir)
    common = calculate_changes(common, prev_versions, versions)
    desktop = calculate_changes(desktop, prev_versions, versions)
    if common:
        changes += COMMON_PAT.format(changes=common)
    if desktop:
        changes += DESKTOP_PAT.format(changes=desktop)
    for k, v in others.items():
        chg = calculate_changes(v, prev_versions, versions)
        if chg:
            changes += OTHER_NAMES[k].format(changes=chg)

    changelog = changelog.replace("{changes}", changes)

    return title, changelog


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="Target tag")
    parser.add_argument("output", help="Output environment file")
    parser.add_argument("changelog", help="Output changelog file")
    parser.add_argument("--urlmd", help="md file of urls")
    parser.add_argument("--pretty", help="Subject for the changelog")
    parser.add_argument("--workdir", help="Git directory for commits")
    parser.add_argument("--handwritten", help="Handwritten changelog")
    args = parser.parse_args()

    target = args.target

    temp = list(get_images(target))
    images = []
    for image in temp:
        images.append(image[0])
    manifests = get_manifests(images)
    prev, curr = get_tags(target, manifests)
    print(f"Previous tag date: {STRIP_PATTERN(prev[0])}")
    print(f" Current tag date: {STRIP_PATTERN(curr[0])}")
    prev_manifests = get_manifests(prev)
    title, changelog = generate_changelog(
        args.handwritten,
        args.urlmd,
        target,
        args.pretty,
        args.workdir,
        prev_manifests,
        manifests,
    )

    print(f"Changelog:\n# {title}\n{changelog}")
    print(f"\nOutput:\nTITLE=\"{title}\"\nTAG=\"{target.lower()}-{STRIP_PATTERN(curr[0])}\"")

    with open(args.changelog, "w") as f:
        f.write(f'# {title}\n{changelog}')

    with open(args.output, "w") as f:
        f.write(f'TITLE="{title}"\nTAG="{target.lower()}-{STRIP_PATTERN(curr[0])}"\n')


if __name__ == "__main__":
    main()