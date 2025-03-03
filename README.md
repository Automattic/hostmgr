# hostmgr

A suite of tools for managing macOS virtual machines using Apple's Virtualization framework.

## Overview

`hostmgr` is an internal tool developed by Automattic to manage macOS VMs for CI/CD purposes.
It facilitates managing multiple combinations of macOS versions, Xcode installations and tooling on a single physical machine (typically a CI host).

> [!IMPORTANT]
> This tool is designed for Automattic's specific CI infrastructure, and as such have some assumptions about our CI infra and tools hardcoded into its implementation (e.g. our use of S3 to store VM templates, our use of Buildkite for our CI/CD…)
>
> As such, while developed in the open, this tool is not really intended to be used by other as-is, and we don't plan to address issues related to the use of this tool outside of the context of Automattic's CI infrastructure.

That being said, feel free to open PRs to suggest improvements or fix issues, or just use the codebase as an inspiration and practical reference for a Swift implementation of:

- Working with Apple's Virtualization framework
- Managing macOS VMs and their lifecycle programmatically
- Integration and publishing of VM images in AWS S3

The suite consists of two main components:

### `hostmgr` CLI
A command-line tool that provides capabilities for:
- Creating, packaging, and publishing VMs to S3
- Managing VM lifecycle (start, stop, list)
- Preparing
- Integration with CI systems (specifically Buildkite in our case)

### `hostmgr-helper`
A macOS menu bar application that:
- Provides GUI access to running VMs
- Enables VNC connections to VMs
- Displays VM status and controls
- Facilitates initial VM setup through graphical interface
  - We use it to [create new OS templates for VMs](https://github.com/Automattic/buildkite-ci/blob/trunk/src/agents/macos-vms/README.md) _(Automattic internal link)_, to go through the macOS setup wizard via the GUI when configuring the template VM.

## Installation

Those tools are installed in our macOS CI hosts when those are deployed, using the [Ansible playbook](https://github.com/Automattic/buildkite-ci/blob/trunk/src/agents/macos-hosts/tasks/install-hostmgr.yml) _(Automattic internal link)_

When you need to install those tools on your local machine—typically to create new OS templates or Xcode VMs—follow the below instructions:

_(We can potentially automate this step, but for now this is still manual)_

1. Run `sudo mkdir -p /opt/ci/ && sudo chown $(whoami) /opt/ci`.
1. Create a few directories: `mkdir -p /opt/ci/bin /opt/ci/vm-images /opt/ci/working-vm-images`.
1. Download `hostmgr` and `hostmgr-helper` from [the latest release](https://github.com/automattic/hostmgr/releases) and move them to `/opt/ci/bin`.
1. Give the downloaded binaries executable permission: `chmod u+x /opt/ci/bin/hostmgr /opt/ci/bin/hostmgr-helper`.
1. You might also need to remove the quanrantine flag from downloaded executables so they can run from Terminal:
   - Either by right-clicking the executable in the Finder, selecting "Open" in the context menu, and click "Open" button.
   - Or by running `xattr -d com.apple.quarantine /opt/ci/bin/hostmgr /opt/ci/bin/hostmgr-helper`.
1. Add `/opt/ci/bin` to your PATH so that the VM tools will be able to use `hostmgr` and `hostmgr-helper`
1. Create a config file in `/opt/ci/hostmgr.json`. You can copy [the file we use to provision our macOS CI hosts](https://github.com/Automattic/buildkite-ci/blob/trunk/src/agents/macos-hosts/resources/hostmgr.json) _(Automattic internal link)_ directly there.
1. Open a Terminal and run `hostmgr-helper` to launch the "hostmgr-helper" macOS app, which needs to be running during building VM images.

## Release

1. Create a PR to update [the version property](Sources/libhostmgr/libhostmgr.swift).
1. After the PR is merged, create a tag named same as the updated version,
1. Once the tag is pushed up to this repo, a CI job will be automatically kicked off to create a GitHub release for the tag.
