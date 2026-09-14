# SPDX-License-Identifier: BSD-3-Clause

import json
import os
import subprocess
from pathlib import Path

event_path = os.environ.get("GITHUB_EVENT_PATH", "")
pr_num = ""

if event_path and os.path.exists(event_path):
    with Path(event_path).open() as f:
        event = json.load(f)
        if "pull_request" in event:
            pr_num = str(event["pull_request"]["number"])

if not pr_num:
    result = subprocess.run(
        ["/usr/bin/gh", "pr", "view", os.environ.get("GITHUB_SHA", ""), "--json", "number", "-q", ".number"],
        capture_output=True,
        text=True,
        check=False,
    )
    pr_num = result.stdout.strip()

marker = "<!-- pr-issue-fixer -->"
commit_sha = os.environ.get("FIX_COMMIT_SHA", "").strip()
commit_line = ""
if commit_sha:
    commit_line = f"\nCommit: `{commit_sha}`\n"

body = f"""{marker}

## Update

☑️ I applied the requested fixes and pushed them to this PR.
{commit_line}

What changed:
- added the missing workflow permissions
- applied the pre-commit fixes
"""

comments = subprocess.run(
    ["/usr/bin/gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/issues/{pr_num}/comments"],
    capture_output=True,
    text=True,
    check=True,
)

existing_comment_id = ""
for comment in json.loads(comments.stdout):
    if comment["user"]["login"] == "github-actions[bot]" and marker in comment["body"]:
        existing_comment_id = str(comment["id"])

if existing_comment_id:
    subprocess.run(
        [
            "/usr/bin/gh",
            "api",
            "--method",
            "PATCH",
            f"repos/{os.environ['GITHUB_REPOSITORY']}/issues/comments/{existing_comment_id}",
            "-f",
            f"body={body}",
        ],
        check=True,
    )
else:
    subprocess.run(["/usr/bin/gh", "pr", "comment", pr_num, "--body", body], check=True)
