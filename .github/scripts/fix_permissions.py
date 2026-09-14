# SPDX-License-Identifier: BSD-3-Clause

import os
from pathlib import Path

import yaml

any_file_changed = False
SKIP_KEYS = ["needs", "if", "runs-on", "environment", "timeout-minutes", "continue-on-error"]

for root, dirs, files in os.walk(".github/workflows"):
    for fname in files:
        if fname.endswith(".yml"):
            file_changed = False
            fpath = Path(root) / fname
            with fpath.open() as f:
                workflow = yaml.safe_load(f)

            if "jobs" in workflow:
                for job_name, job_config in workflow["jobs"].items():
                    if any(k in job_config for k in SKIP_KEYS):
                        continue
                    if "permissions" in job_config:
                        continue
                    job_config["permissions"] = {"contents": "read"}
                    file_changed = True
                    any_file_changed = True
                    print(f"Added permissions to job: {job_name}")

                if file_changed:
                    with fpath.open("w") as f:
                        yaml.dump(workflow, f, default_flow_style=False, sort_keys=False)

if any_file_changed:
    print("WORKFLOW_FIX_DONE")
else:
    print("WORKFLOW_FIX_SKIPPED")
