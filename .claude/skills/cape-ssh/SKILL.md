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

1. Find the VM's current IP. Try `vmrun` first (more reliable), then fall back to ARP. Both require `dangerouslyDisableSandbox: true`.
   ```
   vmrun getGuestIPAddress /home/ed/Projects/cape-sandbox-vm/output-vmware-cape/cape-sandbox.vmx 2>/dev/null \
     || arp -n | awk '/172\.16\.34\./ && !/incomplete/ {print $1}' | head -1
   ```
   If no IP is found, report that the VM does not appear to be running and stop.

2. Run the user's command on the VM:
   ```
   sshpass -p 'cape' ssh -o StrictHostKeyChecking=no cape@<IP> <ARGUMENTS>
   ```

3. Display the output to the user.

## Notes

- User/password: `cape`/`cape`
- If the host key changed (VM was rebuilt), SSH may fail — run `ssh-keygen -f ~/.ssh/known_hosts -R <IP>` first, then retry.
- The IP can change after a VM rebuild; `arp -n` is the source of truth.
