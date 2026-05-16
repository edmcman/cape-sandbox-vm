---
name: cape-logs
description: Download and display the journalctl log from the running CAPE sandbox VM. Use when the user wants to check VM logs, investigate errors, or monitor CAPE service output.
argument-hint: [unit] [journalctl-flags]
allowed-tools: [Bash, Read]
---

# Cape Logs

Fetch journalctl output from the running CAPE sandbox VM.

## Usage

Arguments (optional): $ARGUMENTS

- No arguments: fetch the full journal
- First argument is a service name (cape, mongod, suricata, etc.): scope to that unit with `-u <unit>`
- Any additional flags are passed through to journalctl verbatim

## Steps

1. Build the journalctl flags from $ARGUMENTS: if the first word looks like a service name (no leading `-`), prepend `-u` to it.

2. Run the `/cape-ssh` skill to fetch the journal. Pass this as the command (substituting `<flags>`):
   ```
   'echo cape | sudo -S journalctl --no-pager <flags>'
   ```
   Redirect the output to `./cape-vm.log`. If the VM is not reachable, stop and report that.

3. Report the saved file path, total line count, and a grep summary of ERROR/WARN/CRITICAL/FATAL lines.

## Notes

- Requires `sshpass` installed locally.
- `sudo` works without a password for the `cape` user on the VM.
- Always grep the full log for errors — don't just tail.
