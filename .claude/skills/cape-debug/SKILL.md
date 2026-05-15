---
name: cape-debug
description: Fetch journalctl logs from the running CAPE sandbox VM and analyze them to diagnose errors and suggest fixes. Use when CAPE isn't working correctly, a service failed, or the user wants to understand what went wrong on the sandbox VM.
allowed-tools: [Bash, Agent]
---

# Cape Debug

Fetch the CAPE sandbox VM journal and use a subagent to analyze it.

## Steps

1. Run the `/cape-logs` skill to fetch and save `./cape-vm.log`. If the VM is not reachable, stop and report that.

2. Spawn a subagent using the Agent tool to analyze the saved log. Pass it this prompt (substituting the absolute path to `cape-vm.log`):

   > You are analyzing a journalctl log from a CAPEv2 malware sandbox VM (Ubuntu 24.04).
   > The log is at: <absolute path to cape-vm.log>
   >
   > Read the full file — it may be large, so read it in chunks using offset/limit if needed.
   > Focus on actionable errors. Ignore known-harmless noise:
   > - PCI bridge window assignment failures (VMware artifact)
   > - apport/autoreport skipped conditions
   > - ATA IDENTIFY PACKET DEVICE errors on /dev/sr0
   >
   > Analyze for:
   > - Service startup failures and crash loops (systemd unit failures, ExecStart errors)
   > - Python tracebacks and exceptions
   > - Network errors (connection refused, timeouts, port conflicts)
   > - Dependency failures (MongoDB, Suricata, libvirt, volatility, yara, httpreplay, etc.)
   > - Permission or file-not-found errors
   > - Lines containing ERROR, CRITICAL, FATAL, or "failed"
   >
   > Cross-reference errors across services — downstream failures often cascade from one upstream cause (e.g., CAPE crashing because MongoDB didn't start, or tor failing because dnsmasq didn't start).
   > Focus on the first occurrence of each error class, not the last.
   >
   > Produce a structured diagnosis:
   > - **Summary**: one sentence describing the primary problem
   > - **Root cause**: the underlying issue, not just the symptom
   > - **Affected services**: which systemd units or components are broken
   > - **Recommended fixes**: concrete steps to resolve, in order of priority
   > - **Non-issues**: things that look alarming but are harmless, briefly noted

3. Report the subagent's diagnosis to the user.
