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

1. Find the VM's current IP. Try `vmrun` first (more reliable), then fall back to ARP. Both require `dangerouslyDisableSandbox: true`.
   ```
   vmrun getGuestIPAddress /home/ed/Projects/cape-sandbox-vm/output-vmware-cape/cape-sandbox.vmx 2>/dev/null \
     || arp -n | awk '/172\.16\.34\./ && !/incomplete/ {print $1}' | head -1
   ```
   If no IP is found, report that the VM does not appear to be running and stop.

2. Build the journalctl flags from $ARGUMENTS: if the first word looks like a service name (no leading `-`), prepend `-u` to it.

3. Fetch the journal and save it locally. Use `echo 'cape' | sudo -S` because ssh has no TTY for sudo:
   ```
   sshpass -p 'cape' ssh -o StrictHostKeyChecking=no cape@<IP> \
     'echo cape | sudo -S journalctl --no-pager <flags>' > ./cape-vm.log
   ```
   If SSH fails with a host-key-changed error (VM was rebuilt), first run:
   ```
   ssh-keygen -f ~/.ssh/known_hosts -R <IP>
   ```
   then retry the fetch.

4. Report the saved file path, total line count, and a grep summary of ERROR/WARN/CRITICAL/FATAL lines.

## Notes

- Requires `sshpass` installed locally.
- `sudo` works without a password for the `cape` user on the VM.
- Always grep the full log for errors — don't just tail.
