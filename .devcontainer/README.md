# Windows 11 Codespace for Roblox Studio

This branch contains an isolated Codespaces setup for a Windows 11 desktop.

## Provisioned Codespaces machine

- 4 virtual CPUs
- 16 GB host memory
- 32 GB Codespaces storage

## Windows virtual machine

- Windows 11
- 4 virtual CPU cores
- 8 GB guest RAM
- 32 GB dynamically growing QCOW2 disk
- 1280 × 720 web desktop on private forwarded port 8006

The Windows data is stored in `.windows-data/` inside the Codespaces workspace and is excluded from Git.

On Codespaces start, `.devcontainer/start-windows.sh` starts the Windows container. If KVM is available, it is used. Otherwise, the script falls back to slower software emulation.

## Important free-usage limit

A 32 GB Codespace uses more than the 15 GB-month storage allowance on a GitHub Free personal account if kept for a full month. Delete the Codespace when you no longer need it. The included compute allowance is 120 core-hours per month, so a 4-core machine provides up to 30 active hours.
