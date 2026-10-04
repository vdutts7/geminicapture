# OpenHands - repository customization
# See https://openhands.dev and https://docs.openhands.dev/openhands/usage/customization/repository
# Copy: cp -r .github/templates/openhands/.openhands .
# Optional: cp -r .github/templates/openhands/.agents .
# Optional: cp .github/templates/openhands/AGENTS.md .  (project root)

## Root context
# Prefer a project-root AGENTS.md for always-on instructions (reuse or merge with other agents’ AGENTS.md).

## This directory
# - setup.sh - runs when OpenHands starts on this repo (deps, env)
# - hooks.json - lifecycle hooks for custom scripts
# - microagents/ - legacy on-demand prompts (see docs for .agents/skills/ migration)
