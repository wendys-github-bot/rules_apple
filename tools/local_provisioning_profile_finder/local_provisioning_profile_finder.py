import argparse
import datetime
import plistlib
import shutil
import subprocess
from typing import List, Optional, Tuple


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("name", help="The name of the profile to find")
    parser.add_argument("output", help="The path to copy the profile to")
    parser.add_argument(
        "--local-profiles",
        nargs="*",
        required=True,
        help="All local provisioning profiles to search through",
    )
    parser.add_argument(
        "--fallback-profiles",
        nargs="+",
        required=True,
        help="Fallback provisioning profiles to use if not found locally",
    )
    return parser


def _profile_contents(profile: str) -> Tuple[str, datetime.datetime]:
    output = subprocess.check_output(["security", "cms", "-D", "-i", profile])
    plist = plistlib.loads(output)
    return plist["Name"], plist["CreationDate"]


def _find_newest_profile(name: str, profiles: List[str]) -> Optional[str]:
    sanitized_name = name.replace("_", " ")
    newest_path: Optional[str] = None
    newest_date: Optional[datetime.datetime] = None
    for profile in profiles:
        name, creation_date = _profile_contents(profile)
        if name != sanitized_name:
            continue
        # TODO: Skip expired profiles
        if not newest_date or creation_date > newest_date:
            newest_path = profile
            newest_date = creation_date

    return newest_path


def _find_profile(
    name: str,
    output: str,
    local_profiles: List[str],
    fallback_profiles: List[str],
) -> None:
    profile = _find_newest_profile(name, local_profiles + fallback_profiles)
    if not profile:
        raise SystemError(f"error: no profile found for '{name}'")

    shutil.copyfile(profile, output)


if __name__ == "__main__":
    args = _build_parser().parse_args()
    _find_profile(
        args.name, args.output, args.local_profiles, args.fallback_profiles
    )
