---
name: cape-ssh
description: SSH into the running CAPE sandbox VM and run a command. Use when the user wants to run a command on the cape VM, check VM state, or troubleshoot the sandbox.
argument-hint: <command>
allowed-tools: [Bash]
---

# Cape SSH

Run a command on the running CAPE sandbox VM via SSH.

## Usage

Arguments provided: $ARGUMENTS

## Steps

1. Get the VM's current IP via `vmrun` (requires `dangerouslyDisableSandbox: true`):
   ```
   vmrun getGuestIPAddress /home/ed/Projects/cape-sandbox-vm/output-vmware-cape/cape-sandbox.vmx
   ```
   If no IP is returned, report that the VM does not appear to be running and stop.

2. Proactively clear any stale host key, then run the command:
   ```
   ssh-keygen -f ~/.ssh/known_hosts -R <IP> 2>/dev/null
   sshpass -p 'cape' ssh -o StrictHostKeyChecking=no cape@<IP> <ARGUMENTS>
   ```

3. Display the output to the user.

## Notes

- User/password: `cape`/`cape`
- The IP can change after a VM rebuild; `vmrun getGuestIPAddress` is the source of truth.
