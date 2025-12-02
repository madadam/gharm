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
