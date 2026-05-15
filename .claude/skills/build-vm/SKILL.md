---
name: build-vm
description: Build the CAPE sandbox VM image with packer. Runs packer in the background, logs output, monitors for key events, and sends a push notification when done.
allowed-tools: [Bash, Monitor, PushNotification]
---

# Build VM

Launch a packer build for the `vmware-iso` CAPE sandbox, save the full log, stream key milestones to the user, and push a notification when the build finishes or fails.

## Steps

1. Create the logs directory and set the log path:
   ```bash
   mkdir -p /home/ed/Projects/cape-sandbox-vm/logs
   LOG=/home/ed/Projects/cape-sandbox-vm/logs/build-$(date +%Y%m%d-%H%M%S).log
   ```
   Tell the user the log path before proceeding.

2. Stop any running CAPE VM (a running VM holds VMware's VNC port and will cause packer to fail immediately), then delete any existing output directory (packer refuses to overwrite it), then start the build in the background with `run_in_background: true`. Run from the project root:
   ```bash
   vmrun list | grep cape-sandbox.vmx | xargs -r vmrun stop
   rm -rf /home/ed/Projects/cape-sandbox-vm/output-vmware-cape
   cd /home/ed/Projects/cape-sandbox-vm && \
     packer build -only='cape-sandbox.vmware-iso.ubuntu' -var-file=variables.pkrvars.hcl . 2>&1 | tee "$LOG"
   ```
   This requires `dangerouslyDisableSandbox: true`. If the build fails within the first 30 seconds with a VNC connection error, the VM was likely still shutting down — wait a few seconds and retry.

3. Wait a few seconds for the log file to be created, then start a Monitor to stream key events:
   ```bash
   tail -f "$LOG" | grep -E --line-buffered \
     'Waiting for SSH|Connected to SSH|Provisioning with|Starting VM|Retrieving ISO|Taking snapshot|Build '"'"'|Artifact:|[Ee]rror|errored|[Ff]ailed|[Tt]imeout|[Kk]illed'
   ```
   Use `timeout_ms: 10800000` (3 hours), `persistent: false`. Description: `"packer build progress"`.

   Key events and what they signal:
   - `Waiting for SSH` — VM is booting / Ubuntu cloud-init is running
   - `Connected to SSH` — Install done, provisioning scripts starting
   - `Provisioning with` — Shows which script is now running
   - `Build 'cape-sandbox.vmware-iso.ubuntu' finished` — **Success**
   - `Build 'cape-sandbox.vmware-iso.ubuntu' errored` — **Failure**
   - `Error:` / `errored` / `failed` / `timeout` / `Killed` — Problems worth noting

   **Zscaler/TLS interception check**: Shortly after `Connected to SSH`, scan the log for Zscaler certificate errors:
   ```bash
   grep -i 'zscaler\|certificate.*not trusted\|certificate.*unknown authority' "$LOG" | head -5
   ```
   If any match, **immediately warn the user** and send a PushNotification: `"CAPE build: Zscaler TLS interception detected — packages will fail to install"`. The build will appear to continue but MongoDB, uv/pip, and libvirt downloads will silently fail, producing a broken VM. The user should disable Zscaler and rebuild.

4. When the Monitor stream ends (packer exited), check the result:
   ```bash
   tail -5 "$LOG"
   ```
   Then send a `PushNotification`:
   - Success: `"CAPE VM build complete — output-vmware-cape/cape-sandbox.vmx"`
   - Failure: `"CAPE VM build FAILED — check logs/<logfile>"`

5. On success, ask the user if they want to start the VM. If yes, run:
   ```bash
   vmrun start /home/ed/Projects/cape-sandbox-vm/output-vmware-cape/cape-sandbox.vmx nogui
   ```
   This requires `dangerouslyDisableSandbox: true`. Report whether it started successfully.

## Notes

- Full unfiltered output is in the log file; share its path with the user so they can `tail -f` it themselves if desired.
- The build typically takes 60–120 minutes.
- If packer reports a host-key or VMware license error early, relay that to the user immediately rather than waiting for the build to time out.
