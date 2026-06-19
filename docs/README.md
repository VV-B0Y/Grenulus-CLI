# Athena Developer Documentation

> **Welcome, new dev.** This folder is your starting point for understanding, running, and extending the Athena AI pentesting agent.

---

## Where to Start

| I want to… | Read this |
|---|---|
| Understand the big picture | [DEVELOPER_GUIDE.md §3 — Top-Down Architecture](DEVELOPER_GUIDE.md#3-top-down-architecture) |
| Understand the turn-by-turn execution loop | [DEVELOPER_GUIDE.md §6 — Turn Execution Flow](DEVELOPER_GUIDE.md#6-turn-execution-flow) |
| Understand the data models | [DEVELOPER_GUIDE.md §4 — Core Data Models](DEVELOPER_GUIDE.md#4-core-data-models) |
| Add a new specialist agent | [CUSTOMIZATION.md §1](CUSTOMIZATION.md#1-adding-a-new-specialist-agent) |
| Add a new workflow | [CUSTOMIZATION.md §2](CUSTOMIZATION.md#2-adding-a-new-workflow) |
| Add a new tool | [CUSTOMIZATION.md §3](CUSTOMIZATION.md#3-adding-a-new-tool) |
| Change Athena's tone / prompts | [CUSTOMIZATION.md §4](CUSTOMIZATION.md#4-customizing-agent-prompts) |
| Add a knowledge base section | [CUSTOMIZATION.md §5](CUSTOMIZATION.md#5-adding-knowledge-base-sections) |
| Add a new LLM model | [CUSTOMIZATION.md §6](CUSTOMIZATION.md#6-adding-a-new-llm-provider--model) |
| See all agents, tools, commands at a glance | [REFERENCE.md](REFERENCE.md) |

---

## Documents

- **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** — Full architecture, component deep-dives, Mermaid flowcharts, data models, class diagrams.
- **[CUSTOMIZATION.md](CUSTOMIZATION.md)** — Step-by-step instructions for adding agents, workflows, tools, prompts, KB sections, card types.
- **[REFERENCE.md](REFERENCE.md)** — Quick lookup tables: all 11 agents, 23 workflows, 28 tools, LLM tags, REPL commands, finding types, timeouts.

---

## 60-Second Orientation

```
athena.py (6 275 lines) — the entire CLI engine, one file
│
├── PROVIDER_CHAIN       # Groq model fallback list (cheapest → most capable)
├── AGENT_SPECS          # 11 specialist agents (persona + rules per agent)
├── WORKFLOWS            # 23 pre-built engagement templates (PTT seeders)
├── TOOL_DISPATCH        # 28 structured tools (nmap, sqlmap, hydra, …)
├── KB                   # Numbered tactical knowledge base sections
├── FINDING_PATTERNS     # Regex patterns run on raw subprocess output
├── CORE_RULES           # LLM output format definition ([THOUGHT][CMD][CONF]…)
├── MENTOR_PERSONA       # Athena's global voice + teaching rules
│
├── class PTT            # Pentesting Task Tree — tracks all tasks + findings
├── class ContextManager # Decides how much context to send each turn
├── class ScopeConfig    # Scope / RoE enforcement from ~/.athena/scope.json
├── class AttackGraph    # networkx DiGraph of hosts/services/creds
├── class ToolBuilder    # 28 static methods → shell strings
│
└── class AthenaSession  # Main runtime: owns all state + runs _agent_loop()
    ├── think_turn()     # Single LLM turn (select agent → build prompt → call API → parse)
    ├── _agent_loop()    # Main while-loop (calls think_turn, handles y/n/q, updates PTT)
    └── run_command()    # subprocess execution with timeout + sudo retry

athena_gui.py (1 566 lines) — GTK4 shell, spawns athena.py as subprocess
```

---

## Running Locally (dev mode)

```bash
# Install Python deps
pip install groq networkx

# Set your free Groq API key
export GROQ_API_KEY='gsk_...'

# Run CLI directly (no install.sh needed)
python3 athena.py

# Run GUI (needs GTK4 + libadwaita)
python3 athena_gui.py
```
