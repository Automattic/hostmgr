# hostmgr

A description of this package.

## Release

1. Create a PR to update the [`appVersion`](Sources/hostmgr/main.swift).
1. After the PR is merged, create a tag named same as the `appVersion`,
1. Once the tag is pushed up to this repo, a CI job will be automatically kicked off to create a GitHub release for the tag. Wait for the CI job to finish.
1. Update [the hostmgr homebrew formula](https://github.com/Automattic/homebrew-build-tools/blob/trunk/hostmgr.rb)'s `url` and `sha256` fields, whose value can be found in the GitHub release created above.
