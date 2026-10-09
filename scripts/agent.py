#!/usr/bin/env python3
"""Print an agent file (agents/*.md) as JSON: its frontmatter fields and its prompt.

Usage: agent.py AGENT_FILE
"""
import json
import sys

if len(sys.argv) != 2:
    print("usage: agent.py AGENT_FILE", file=sys.stderr)
    sys.exit(2)
_, front, body = open(sys.argv[1]).read().split("---\n", 2)
meta = dict(line.split(": ", 1) for line in front.strip().splitlines())
print(json.dumps(dict(meta, tools=meta["tools"].replace(" ", ""), prompt=body.strip())))
