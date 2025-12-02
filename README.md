# GitHub Actions Runner Manager

Script to manage multiple self-hosted Github Actions runners on a single host.

## Usage

Run `gharm.sh` from a directory where you want to host the runners:

- `gharm.sh setup`: download and install the Github Runner package (only do this once).
- `gharm.sh create ...`: create a new runner
- `gharm.sh service`: manage runner systemd service
- `gharm.sh remove`: remove a runner

The `create` and `remove` commands require a Github *Personal Access Token* with
the *"Administration" repository permissions (write)*. The token can be passed either via the
`--token` command line option, or via the `GITHUB_TOKEN` env variable or read from the
`.github-token` file in the same directory the script it invoked from.

## Limitations

It seems the only way to run multiple Github runners on a single machine is to install it multiple
times, each into its own directory. To prevent wasting disk space, this script installs it once and
then uses hard-links to create each instance. That, however, doesn't work well with the auto-update
feature of the Github runner, as the update would replace the hard-links with new files which would
negate the saved disk space. Because of this, the auto-update feature is currently disabled.