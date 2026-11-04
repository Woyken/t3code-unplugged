#!/usr/bin/env python3
"""Check that a fixer agent's shell allowlist covers the commands it must run.

The drift fixers use a deny-by-default shell allowlist. When a prompt gains a
new command, forgetting its allow rule does not fail until the agent has already
spent its step budget on permission errors. Run this before the agent starts,
and in CI, so the mismatch is caught immediately.

The required command lists are representative invocations of every command in
the corresponding prompt. Keep them in sync with .github/prompts/<agent>.md.
"""

import re
import sys
from pathlib import Path

REQUIRED = {
    "patch-fixer": [
        "bash scripts/apply-patches.sh upstream",
        "bash scripts/apply-patch.sh 0001-example.patch",
        "bash scripts/verify-strip.sh upstream",
        "bash scripts/typecheck-patches.sh upstream",
        "git apply --stat patches/0001-example.patch",
        "git apply --check patches/0001-example.patch",
        "git -C upstream reset --hard v0.0.0",
        "git -C upstream clean -fd",
        "git -C upstream diff v0.0.0 v0.0.1 -- apps/server/src/server.ts",
        "git -C upstream status --short",
        "git checkout -- patches/",
        "git checkout -- upstream-base.txt",
        "git rm patches/0001-example.patch",
        "git status --short",
        "wc -l patches/0001-example.patch",
    ],
    "release-fixer": [
        "bash scripts/apply-patches.sh upstream",
        "bash scripts/apply-patch.sh 0001-example.patch",
        "bash scripts/verify-strip.sh upstream",
        "bash -n scripts/example.sh",
        "node --check scripts/example.mjs",
        "git status",
        "git diff",
        "git -C upstream reset --hard v0.0.0",
        "git -C upstream clean -fd",
        "git -C upstream tag --list",
    ],
}


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def read_permissions(path: Path) -> list[dict[str, str]]:
    lines = path.read_text().splitlines()
    if not lines or lines[0].strip() != "---":
        raise SystemExit(f"{path}: missing frontmatter")
    try:
        end = next(i for i, line in enumerate(lines[1:], 1) if line.strip() == "---")
    except StopIteration:
        raise SystemExit(f"{path}: unterminated frontmatter")

    rules: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    for line in lines[1:end]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        action = re.match(r"^-\s+action:\s*(.+)$", stripped)
        resource = re.match(r"^resource:\s*(.+)$", stripped)
        effect = re.match(r"^effect:\s*(.+)$", stripped)
        if action:
            if current is not None:
                rules.append(current)
            current = {"action": unquote(action.group(1))}
        elif current is not None and resource:
            current["resource"] = unquote(resource.group(1))
        elif current is not None and effect:
            current["effect"] = unquote(effect.group(1))

    if current is not None:
        rules.append(current)

    for rule in rules:
        missing = {"action", "resource", "effect"} - rule.keys()
        if missing:
            raise SystemExit(f"{path}: permission rule is missing {sorted(missing)}: {rule}")
    return rules


def matches(pattern: str, value: str) -> bool:
    regex = "^" + re.escape(pattern).replace(r"\*", ".*").replace(r"\?", ".") + "$"
    if re.fullmatch(regex, value):
        return True
    # A shell pattern ending in " *" also matches the command without arguments.
    return pattern.endswith(" *") and value == pattern[:-2]


def effect(rules: list[dict[str, str]], command: str) -> str:
    result = "ask"
    for rule in rules:
        if rule["action"] in ("shell", "*") and matches(rule["resource"], command):
            result = rule["effect"]
    return result


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: check-fixer-permissions.py <agent-id>")

    agent_id = sys.argv[1]
    required = REQUIRED.get(agent_id)
    if required is None:
        raise SystemExit(f"no permission check for agent {agent_id!r}")

    rules = read_permissions(Path(".opencode/agents") / f"{agent_id}.md")
    blocked = [command for command in required if effect(rules, command) != "allow"]
    for command in required:
        print(f"{effect(rules, command):5} {command}")
    if blocked:
        raise SystemExit("fixer permission check failed: " + ", ".join(blocked))
    print(f"fixer permissions OK for {agent_id}")


if __name__ == "__main__":
    main()
