---
name: cape-debug
description: Fetch journalctl logs from the running CAPE sandbox VM and analyze them to diagnose errors and suggest fixes. Use when CAPE isn't working correctly, a service failed, or the user wants to understand what went wrong on the sandbox VM.
allowed-tools: [Bash, Agent]
---

# Cape Debug

Fetch the CAPE sandbox VM journal and use a subagent to analyze it.

## Steps

1. Run the `/cape-logs` skill to fetch and save `./cape-vm.log`. If the VM is not reachable, stop and report that.

2. Spawn a `cape-log-analyzer` subagent using the Agent tool with `subagent_type: "cape-log-analyzer"`. Pass a prompt containing only the absolute path to `cape-vm.log`, substituted into `$LOG_PATH`.

3. Report the subagent's diagnosis to the user.
