# hostmgr

## What is it?

This tool suite is used to create and manage VMs on our Buildkite CI Mac hosts:

 - `hostmgr` is a command-line tool to:
    - Create, package and publish VMs… (when we prepare new VMs for new macOS or Xcode versions)
    - List installed VMs, fetch VMs, start and stop VMs… (when running this tool on our CI hosts, to boot VMs and run Buildkite jobs in them)
 - `hostmgr-helper` is a helper tool used to display the VM's GUI in a Window on the host machine.
    - This helper shows up as a Menu Bar item in your Mac
    - It is especially useful when setting up new OS templates, to go through the macOS setup wizard via the GUI when configuring the template.

## Installation

Those tools are installed in our macOS CI hosts when those are deployed, using the [Ansible playbook](https://github.com/Automattic/buildkite-ci/blob/trunk/src/agents/macos-hosts/tasks/install-hostmgr.yml)

When you need to install those tools on your local machine—typically to create new OS templates or Xcode VMs—follow the below instructions:

_(We can potentially automate this step, but for now this is still manual)_

1. Run `sudo mkdir -p /opt/ci/ && sudo chown <your-mac-user-name> /opt/ci`.
1. Create a few directories: `mkdir -p /opt/ci/bin /opt/ci/vm-images /opt/ci/working-vm-images`.
1. Download `hostmgr` and `hostmgr-helper` from [the latest release](https://github.com/automattic/hostmgr/releases) and move them to `/opt/ci/bin`.
1. Give the downloaded binaries executable permission: `chmod u+x /opt/ci/bin/hostmgr /opt/ci/bin/hostmgr-helper`.
1. You might also need to remove the quanrantine flag from downloaded executables so they can run from Terminal:
   - Either by right-clicking the executable in the Finder, selecting "Open" in the context menu, and click "Open" button.
   - Or by running `xattr -d com.apple.quarantine /opt/ci/bin/hostmgr /opt/ci/bin/hostmgr-helper`.
1. Add `/opt/ci/bin` to your PATH so that the VM tools will be able to use `hostmgr` and `hostmgr-helper`
1. Create a config file in `/opt/ci/hostmgr.json`. You can copy [the file we use to provision our macOS CI hosts](src/agents/macos-hosts/resources/hostmgr.json) directly there.
1. Open a Terminal and run `hostmgr-helper` to launch the "hostmgr-helper" macOS app, which needs to be running during building VM images.

## Release

1. Create a PR to update [the version property](Sources/libhostmgr/libhostmgr.swift).
1. After the PR is merged, create a tag named same as the updated version,
1. Once the tag is pushed up to this repo, a CI job will be automatically kicked off to create a GitHub release for the tag.
