# SPDX-License-Identifier: BSD-3-Clause

import base64
import os
from pathlib import Path

import yaml

SKIP_KEYS = ["needs", "if", "runs-on", "environment", "timeout-minutes", "continue-on-error"]
ISSUES = ""

for root, dirs, files in os.walk(".github/workflows"):
    for fname in files:
        if fname.endswith(".yml"):
            fpath = Path(root) / fname
            with fpath.open() as f:
                workflow = yaml.safe_load(f)

            if "jobs" in workflow:
                workflow_has_permissions = "permissions" in workflow
                for job_name, job_config in workflow["jobs"].items():
                    if any(k in job_config for k in SKIP_KEYS):
                        continue
                    if "permissions" in job_config or workflow_has_permissions:
                        continue
                    if ISSUES:
                        ISSUES += "\n"
                    ISSUES += f"Job '{job_name}' in '{fname}' missing permissions"

github_output = Path(os.environ["GITHUB_OUTPUT"])
with github_output.open("a") as f:
    f.write(f"issues_found={'true' if ISSUES else 'false'}\n")
    if ISSUES:
        encoded = base64.b64encode(ISSUES.encode()).decode()
        f.write(f"ISSUES={encoded}\n")

if ISSUES:
    issues_path = Path("/tmp/issues.txt")
    issues_path.write_text(ISSUES)
