import subprocess
import datetime
import plistlib
import os


def write_to_info():
    path = "info.plist"

    with open(path, 'rb') as f:
        contents = plistlib.load(f)

    if not contents:
        exit(-1)

    branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).strip().decode()
    commit = subprocess.check_output(["git", "describe", "--always"]).strip().decode()

    contents["gitBranch"] = branch
    contents["gitCommit"] = commit
    contents["buildTime"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    with open(path, 'wb') as f:
        plistlib.dump(contents, f, sort_keys=False)


def run():
    if os.environ.get("CI", False) or os.environ.get("GITHUB_ACTIONS", False):
        print("writing info.plist")
        write_to_info()
        print("done")


if __name__ == "__main__":
    run()
