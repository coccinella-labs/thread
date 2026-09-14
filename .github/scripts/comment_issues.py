# SPDX-License-Identifier: BSD-3-Clause

import base64
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
    github_ref = os.environ.get("GITHUB_REF", "")
    if "pull" in github_ref:
        parts = github_ref.split("/")
        for i, part in enumerate(parts):
            if part == "pull" and i + 1 < len(parts):
                pr_num = parts[i + 1]
                break

if not pr_num:
    result = subprocess.run(
        ["/usr/bin/gh", "pr", "view", os.environ.get("GITHUB_SHA", ""), "--json", "number", "-q", ".number"],
        capture_output=True,
        text=True,
        check=False,
    )
    pr_num = result.stdout.strip()

issues = ""
issues_path = Path("/tmp/issues.txt")
if issues_path.exists():
    issues = issues_path.read_text()
elif "ISSUES" in os.environ:
    issues = base64.b64decode(os.environ["ISSUES"]).decode()

marker = "<!-- pr-issue-analysis -->"
body = f"""{marker}

## Review note

☑️ I found a few things to fix in this PR.

{issues}

### Commands you can use

- `/fix-workflow-permissions` to fix workflow permissions
- `/fix precommit` to run the pre-commit fixes
- `/fix all` to apply everything
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
