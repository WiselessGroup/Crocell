#!/usr/bin/env bash
# The version a CI build carries: 0.4.0 for the tag v0.4.0, dev-<sha> for
# anything else. Release builds compare it with GitHub's latest release.
if [[ ${GITHUB_REF:-} == refs/tags/v* ]]; then
  echo "${GITHUB_REF_NAME#v}"
else
  echo "dev-$(git rev-parse --short=7 HEAD)"
fi
