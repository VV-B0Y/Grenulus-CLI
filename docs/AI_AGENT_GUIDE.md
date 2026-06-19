# DroneCoil — AI Agent Onboarding Guide

> **Audience:** AI coding agents (Copilot, Claude, GPT, etc.) taking over or contributing to this project.
> **Purpose:** Fast-ramp on architecture, safe editing patterns, testing/debugging methodology, and in-session terminal commands.
> **Version:** 7.3

---

## Table of Contents

1. [What This Project Is](#1-what-this-project-is)
2. [File Map — Where Everything Lives](#2-file-map--where-everything-lives)
3. [Architecture in One Page](#3-architecture-in-one-page)
4. [Key Constants Cheat-Sheet](#4-key-constants-cheat-sheet)
5. [Testing & Debugging — Rules of Engagement](#5-testing--debugging--rules-of-engagement)
6. [Pre-Push Checklist](#6-pre-push-checklist)
7. [In-Session Terminal Commands](#7-in-session-terminal-commands)
8. [Extended Sub-Commands Reference](#8-extended-sub-commands-reference)
9. [Common Change Recipes](#9-common-change-recipes)
10. [Danger Zones — What NOT to Touch Without Care](#10-danger-zones--what-not-to-touch-without-care)
11. [Debug Mode & Log Inspection](#11-debug-mode--log-inspection)

---

## 1. What This Project Is

DroneCoil is a **single-file AI pentesting copilot** (`dronecoil.py`, ~6,300 lines). It wraps a free-tier Groq LLM around a structured pentesting engine. The operator types a target and an objective; DroneCoil:

1. Seeds a **Pentesting Task Tree (PTT)** — a rooted task tree representing the full engagement.
2. Selects a **specialist agent** for each PTT node (recon, web, AD, privesc, etc.).
3. Builds a **compressed system prompt** and calls the Groq API.
4. Parses the LLM response for `[CMD]`, `[TOOL]/[ARGS]`, and confidence tags.
5. Asks the operator `y/n/q`, runs the command via `subprocess`, and regex-extracts findings from real output.
6. Updates the PTT and attack graph, then loops.

**Everything lives in `dronecoil.py`.** The file is intentionally monolithic so operators can fork, diff, and patch without a build system. All configuration is top-level constants.

---

## 2. File Map — Where Everything Lives

```
DroneCoil/
├── dronecoil.py          ← THE ENGINE  (~6,300 lines, single source of truth)
├── dronecoil_gui.py      ← GTK4 GUI shell (~1,566 lines)
├── dronecoil-gui         ← Bash launcher for the GUI
├── bootstrap.sh       ← Remote one-shot installer
├── install.sh         ← Local installer (symlinks, deps, desktop entry)
├── requirements.txt   ← groq>=0.4.0, networkx>=3.0
└── docs/
    ├── AI_AGENT_GUIDE.md   ← THIS FILE
    ├── DEVELOPER_GUIDE.md  ← Full architecture deep-dive
    ├── CUSTOMIZATION.md    ← How to add agents, tools, workflows
    └── REFERENCE.md        ← Quick-lookup tables for all components
```

### Critical line numbers in `dronecoil.py`

| Component | Line (approx.) |
|---|---|
| `VERSION`, `PROVIDER_CHAIN` | ~54 |
| `KWARG_SYNONYMS`, `COMMAND_TIMEOUTS` | ~106 |
| `KALI_TOOLS` | ~334 |
| `FINDING_PATTERNS` | ~487 |
| `KB` (Knowledge Base dict) | ~720 |
| `WORKFLOW_KB_MAP` | ~1031 |
| `AGENT_SPECS` | ~1135 |
| `PHASE_TO_AGENT` | ~1315 |
| `PTT`, `PTTNode`, `Finding` classes | ~1388 |
| `ToolBuilder` class | ~2464 |
| `TOOL_DISPATCH` | ~2833 |
| `TOOL_BINARY` | ~2868 |
| `ContextManager` class | ~3499 |
| `WORKFLOWS` dict | ~3550 |
| `build_system_prompt()` | ~3920 |
| `DroneCoilSession.__init__()` | ~4194 |
| `_think_with_fallback()` | ~4363 |
| `parse_specialist_response()` | ~5200 (approx) |
| `show_workflow_menu()` | ~5690 |
| `show_help()` | ~6063 |
| `show_agents()` | ~6096 |
| `repl()` / REPL while loop | ~6100 |

> **Tip:** `grep -n "def show_workflow_menu\|def show_agents\|def repl\|AGENT_SPECS\|WORKFLOWS" dronecoil.py` is the fastest way to jump to any section.

---

## 3. Architecture in One Page

```
Operator input (CLI or GUI)
       │
       ▼
  repl()  ──────── single-word REPL commands (workflow, target, findings, …)
       │            └── sub-commands: workflow add/edit, agent edit, model set, …
       │
       ▼
  _agent_loop(prompt, workflow_key)
       │
       ├─ _select_agent(ptt_node)  →  PHASE_TO_AGENT → AGENT_SPECS
       ├─ build_system_prompt()    →  MENTOR_PERSONA + agent persona + CORE_RULES
       │                              + PTT + KB sections + (tools block on turns 1-2)
       ├─ _think_with_fallback()   →  Groq API, provider chain LLaMA 3.1 8B → … → Compound Beta
       ├─ parse_specialist_response() →  extracts [THOUGHT][CMD][TOOL][ARGS][CONF][HANDOFF]…
       ├─ ScopeConfig.check()      →  RoE gate (blocks out-of-scope targets)
       ├─ run_command()            →  subprocess, timeout, sudo retry, output compression
       └─ extract_findings_from_stdout()  →  FINDING_PATTERNS regexes on real output
              │
              └─ PTT.add_finding() + AttackGraph.add_*() + MITRE tagging
```

**Data flows in one direction:** operator → REPL → agent loop → LLM → subprocess → findings. There is **no feedback from findings back to the LLM** within a single turn; the updated PTT is injected into the *next* system prompt.

---

## 4. Key Constants Cheat-Sheet

| Constant | Location | What to change it for |
|---|---|---|
| `VERSION` | ~line 54 | Bump after significant changes |
| `PROVIDER_CHAIN` | ~line 64 | Add/remove/reorder Groq models |
| `DEFAULT_COMMAND_TIMEOUT` | ~line 108 | Catch-all timeout (seconds) |
| `COMMAND_TIMEOUTS` | ~line 108 | Per-tool timeout tuning |
| `KWARG_SYNONYMS` | ~line 106 | Fix LLM arg name variations |
| `KALI_TOOLS` | ~line 334 | Register new tool binaries |
| `FINDING_PATTERNS` | ~line 487 | Add new regex finding types |
| `KB` | ~line 720 | Add/edit knowledge base sections |
| `WORKFLOW_KB_MAP` | ~line 1031 | Map workflows → KB sections |
| `AGENT_SPECS` | ~line 1135 | Add/edit specialist agents |
| `PHASE_TO_AGENT` | ~line 1315 | Map PTT phases → agent keys |
| `TOOL_DISPATCH` | ~line 2833 | Register ToolBuilder methods |
| `TOOL_BINARY` | ~line 2868 | Register binary names for `which` check |
| `WORKFLOWS` | ~line 3550 | Add/edit built-in workflows |
| `MENTOR_PERSONA` | ~line 3920 | Change DroneCoil's global voice |
| `CORE_RULES` | after MENTOR_PERSONA | Change output tag format rules |
| `DEFAULT_SCOPE` | ~line 3088 | Change default RoE settings |

---

## 5. Testing & Debugging — Rules of Engagement

### 5.1 Syntax Check First (Always)

Before touching anything else, verify the file parses cleanly:

```bash
python3 -m py_compile dronecoil.py && echo "OK"
python3 -m py_compile dronecoil_gui.py && echo "OK"
```

If either fails, the entire tool breaks. Fix syntax errors before doing anything else.

### 5.2 Import Check

```bash
python3 -c "import ast; ast.parse(open('dronecoil.py').read()); print('AST OK')"
```

### 5.3 Smoke Test — Dry Run (No API Key Needed)

Start DroneCoil without a valid API key to verify boot, REPL wiring, and command parsing:

```bash
GROQ_API_KEY=test python3 dronecoil.py
```

Expected: banner prints, boot sequence runs, `set_target()` prompts. If it crashes before the prompt, something structural is broken.

### 5.4 REPL Command Smoke Test

With the dry-run session open, type each command and verify no Python traceback:

```
help        ← should print the help block
agents      ← should list all AGENT_SPECS entries
model       ← should list PROVIDER_CHAIN entries
workflow    ← should show the workflow menu (then 0 to cancel)
tools       ← should show tool availability grid
findings    ← should say "No findings yet"
tree        ← should show an empty PTT
graph       ← should show an empty attack graph
scope       ← should show scope config
mitre       ← should show empty MITRE table
dashboard   ← should show session status panel
```

### 5.5 Tool Dispatch Unit Test

Verify a new or modified `ToolBuilder` method builds the correct shell string:

```bash
python3 - <<'EOF'
import sys
sys.path.insert(0, '.')
# Patch out the Groq import to avoid API key requirement
import unittest.mock as m
with m.patch.dict('sys.modules', {'groq': m.MagicMock()}):
    # Import only the ToolBuilder class
    import importlib, types
    src = open('dronecoil.py').read()
    # Quick extraction: exec just the ToolBuilder section
    exec(compile(src, 'dronecoil.py', 'exec'), {'__builtins__': __builtins__})
    # Test nmap
    result = ToolBuilder.nmap(target='10.0.0.1', ports='1-1000', stealth=True)
    print('nmap test:', result)
    assert 'nmap' in result and '10.0.0.1' in result
    print('PASS')
EOF
```

### 5.6 Finding Pattern Test

Test regex patterns against sample tool output before adding them:

```bash
python3 - <<'EOF'
import re
# Paste your new pattern here
pattern = r'(\d{1,3}(?:\.\d{1,3}){3})\s+is up'
sample_output = """
Nmap scan report for 10.0.0.5 - 10.0.0.5 is up (0.0012s latency).
"""
matches = re.findall(pattern, sample_output)
print('Matches:', matches)
assert matches, "Pattern did not match — fix the regex"
print('PASS')
EOF
```

### 5.7 System Prompt Inspection

To see what system prompt DroneCoil would build for a given agent and workflow, add a temporary debug print to `build_system_prompt()` and run:

```bash
GROQ_API_KEY=test python3 -c "
import sys
sys.modules['groq'] = __import__('unittest.mock', fromlist=['MagicMock']).MagicMock()
exec(open('dronecoil.py').read())
# Access the running session
"
```

Or use the `prompt show` REPL command (see §8) during a live dry-run session.

### 5.8 GUI Syntax Check

```bash
python3 -m py_compile dronecoil_gui.py && echo "GUI OK"
```

If you haven't changed `dronecoil_gui.py`, skip this step.

---

## 6. Pre-Push Checklist

Run through this list in order before committing any change to `dronecoil.py`:

```
[ ] 1.  python3 -m py_compile dronecoil.py            — zero errors
[ ] 2.  python3 -m py_compile dronecoil_gui.py        — zero errors (if GUI changed)
[ ] 3.  Dry-run boot: GROQ_API_KEY=test python3 dronecoil.py
        └─ Banner appears, prompt appears, no traceback on launch
[ ] 4.  REPL smoke test: type every built-in command, verify no traceback
[ ] 5.  If you added/changed a TOOL:
        └─ ToolBuilder method returns a non-empty string
        └─ TOOL_DISPATCH entry added
        └─ TOOL_BINARY entry added (for `which` check)
        └─ KWARG_SYNONYMS entry added (if LLM may use alternate arg names)
        └─ KALI_TOOLS category updated
[ ] 6.  If you added/changed an AGENT:
        └─ AGENT_SPECS entry has name, icon, color, persona, extra_rules
        └─ PHASE_TO_AGENT entries added for all relevant phases
[ ] 7.  If you added/changed a WORKFLOW:
        └─ WORKFLOWS entry has name, description, seed list
        └─ WORKFLOW_KB_MAP updated if specific KB sections are needed
        └─ All seed phases exist in PHASE_TO_AGENT
[ ] 8.  If you changed output tags (CORE_RULES):
        └─ parse_specialist_response() updated to handle the new tag
[ ] 9.  If you added a new REPL command:
        └─ show_help() text updated
        └─ docs/REFERENCE.md REPL commands table updated
[ ] 10. No hardcoded API keys, passwords, or secrets in any file
[ ] 11. grep -n "TODO\|FIXME\|HACK\|XXX" dronecoil.py  — review any you added
```

---

## 7. In-Session Terminal Commands

These are commands you type at the DroneCoil REPL prompt (`⚔ priest ›`) during a live session. They do **not** require restarting the tool.

### 7.1 Built-In Single-Word Commands

| Command | What it does |
|---|---|
| `workflow` | Open the 23-workflow selection menu |
| `target` | Set or update the engagement target |
| `findings` | Show all findings (verified + unverified) |
| `tree` | Render the Pentesting Task Tree |
| `graph` | Show the attack graph and pivot suggestions |
| `scope` | Show / toggle RoE enforcement |
| `mitre` | MITRE ATT&CK techniques used this session |
| `tools` | Tool availability check + auto-install missing |
| `model` | Show Groq provider chain + active model |
| `agent` / `agents` | List all specialist agents |
| `dashboard` / `status` | Concise session status panel |
| `save` | Save conversation log to file |
| `report` | Generate the engagement report now |
| `clear` | Clear AI memory (PTT + findings preserved) |
| `reset` | Full reset (PTT + findings + history + sudo cache) |
| `help` | Help menu |
| `exit` / `q` | End session and generate report |

### 7.2 Extended Sub-Commands (Added in v7.3+)

These allow in-session editing without touching the source file.

#### Workflow sub-commands

```
workflow add
```
Interactive wizard. Prompts for name, description, and seed tasks (title + phase pairs). Adds the workflow to the session's `WORKFLOWS` dict. **Session-only** — not persisted to `dronecoil.py`.

```
workflow edit <key>
```
Edit the name or description of an existing workflow. Example: `workflow edit 1`

```
workflow list
```
Show the full workflow menu with keys and descriptions (same as `workflow` but without launching).

#### Agent sub-commands

```
agent edit <key>
```
Edit the `persona` or `extra_rules` of a specialist agent in-session. The change affects the system prompt for all subsequent turns using that agent. Example: `agent edit recon`

Valid agent keys: `strategist`, `recon`, `web`, `network`, `ad`, `linux_privesc`, `windows_privesc`, `credential`, `exfil`, `evasion`, `reporter`

#### Model sub-commands

```
model set <n>
```
Force-set the active model to position `n` in the provider chain (1-indexed). Example: `model set 5` forces LLaMA 3.3 70B. Useful when a specific model performs better for the current task.

```
model list
```
Show the full provider chain with current active model highlighted (same as `model`).

#### System prompt inspection

```
prompt show
```
Preview the system prompt that would be built for the next LLM call, using the current agent and workflow state. Useful for debugging why the LLM is behaving unexpectedly.

---

## 8. Extended Sub-Commands Reference

Quick lookup for the sub-command syntax added in the extended REPL.

| Full command | Args | Action |
|---|---|---|
| `workflow` | *(none)* | Open workflow selection menu |
| `workflow list` | *(none)* | Show workflow list without launching |
| `workflow add` | *(none → interactive)* | Add new workflow (session-only) |
| `workflow edit <key>` | key = workflow number | Edit name/description of a workflow |
| `agent` / `agents` | *(none)* | List all agents |
| `agent edit <key>` | key = agent role name | Edit persona/extra_rules of an agent |
| `model` / `model list` | *(none)* | Show provider chain |
| `model set <n>` | n = 1-indexed position | Force-set active model |
| `prompt show` | *(none)* | Preview next system prompt |

---

## 9. Common Change Recipes

These are complete step-by-step recipes for the most frequent changes. All edits are in `dronecoil.py` unless noted.

### Recipe A — Add a New Workflow

1. Open `dronecoil.py`, go to `WORKFLOWS` (~line 3550).
2. Add a new key (next number or descriptive string):
   ```python
   "24": {
       "name":        "Your Workflow Name",
       "description": "short one-line description",
       "seed": [
           ("First task title",   "phase_key"),
           ("Second task title",  "phase_key"),
       ],
   },
   ```
3. Verify every phase key exists in `PHASE_TO_AGENT`. If not, add entries there too.
4. Add to `WORKFLOW_KB_MAP` (~line 1031) if specific KB sections apply.
5. Run pre-push checklist §6, especially items 1, 3, 4, 7.

**To do this without editing the file:** use `workflow add` in a live session.

---

### Recipe B — Edit an Existing Agent's Behaviour

1. Open `dronecoil.py`, go to `AGENT_SPECS` (~line 1135).
2. Find the agent key (e.g., `"recon"`).
3. Edit `persona` (strategic role description) or `extra_rules` (preferred tool ordering).
4. Run pre-push checklist §6, items 1, 3, 4.

**To test in-session without restarting:** use `agent edit recon` at the REPL.

---

### Recipe C — Add a New Tool

1. Add a `ToolBuilder` static method (~line 2464):
   ```python
   @staticmethod
   def your_tool(target: str, option: Optional[str] = None) -> str:
       parts = ["your-binary", target]
       if option:
           parts.extend(["--flag", option])
       return " ".join(parts)
   ```
2. Register in `TOOL_DISPATCH` (~line 2833): `"your_tool": ToolBuilder.your_tool`
3. Register in `TOOL_BINARY` (~line 2868): `"your_tool": "your-binary"`
4. Add to `KALI_TOOLS` (~line 334) under the appropriate category.
5. (Optional) Add `KWARG_SYNONYMS` entries (~line 106) for likely LLM arg name variations.
6. Run pre-push checklist §6, item 5.

---

### Recipe D — Change the System Prompt / LLM Voice

- **Global personality:** edit `MENTOR_PERSONA` (~line 3920 area).
- **Global format rules:** edit `CORE_RULES` (immediately after `MENTOR_PERSONA`).
  - ⚠️ If you add a new XML tag in `CORE_RULES`, you **must** also update `parse_specialist_response()` to extract it.
- **Per-agent tactical rules:** edit `AGENT_SPECS[key]["extra_rules"]`.

---

### Recipe E — Add a New REPL Command

1. Find the REPL `while True:` loop (~line 6100 in `repl()`).
2. Add a new `elif` branch:
   ```python
   elif cmd == "your_command":
       self._your_handler()
   ```
   **Important:** add it *before* the final `else: self._agent_loop(...)` clause.
3. Add the handler method to `DroneCoilSession`.
4. Update `show_help()` (~line 6063) with the command description.
5. Update `docs/REFERENCE.md` REPL commands table.
6. Run pre-push checklist §6, item 9.

**Sub-command pattern** (for commands like `workflow add`):

```python
elif tokens[0] == "workflow":
    if len(tokens) == 1:
        self.show_workflow_menu()
    elif tokens[1] == "add":
        self._workflow_add_wizard()
    elif tokens[1] == "edit" and len(tokens) >= 3:
        self._workflow_edit(tokens[2])
```

The REPL already splits `user_input` into `tokens = user_input.split()` — use `tokens[0]` for the primary command and `tokens[1]` for the sub-command.

---

### Recipe F — Force a Specific LLM Model

**In-session (no restart):**
```
model set 5
```
Sets the provider to position 5 (LLaMA 3.3 70B). Takes effect on the next LLM call.

**Permanently (for the session only, set at boot):**
```bash
GROQ_API_KEY=your_key python3 dronecoil.py
# then at REPL:
model set 5
```

**Permanently in code:** reorder `PROVIDER_CHAIN` so your preferred model is first.

---

### Recipe G — Debug Why the LLM is Behaving Unexpectedly

1. At the REPL, type `prompt show` to see the exact system prompt that will be sent.
2. Check the `[THOUGHT]` tag in the LLM output — it reveals the model's reasoning.
3. Check `~/.dronecoil/logs/session_*.txt` — every turn's prompt, response, and extracted output is logged there (ANSI stripped).
4. If the model keeps producing `[CONF]red[/CONF]`, check:
   - Is the target set? (`target` command)
   - Is the PTT populated? (`tree` command)
   - Is scope blocking the command? (`scope` command)
5. If tool dispatch fails, the error goes into `_pending_dispatch_error` and is prepended to the next system prompt automatically — watch for it in `prompt show`.

---

## 10. Danger Zones — What NOT to Touch Without Care

| Area | Risk | Mitigation |
|---|---|---|
| `parse_specialist_response()` | Regex breakage silently swallows LLM output | Run REPL smoke test after any change |
| `CORE_RULES` | Changing tag syntax breaks the response parser | Always update `parse_specialist_response()` in sync |
| `run_command()` | Subprocess security — user commands hit the shell | Never remove the scope check before this call |
| `ScopeConfig.check()` | RoE gate — removing it runs commands on any target | Do not weaken or bypass this function |
| `_think_with_fallback()` | All LLM calls flow through here | Be careful with error handling; swallowed exceptions cause silent failures |
| `PROVIDER_CHAIN` order | First model is cheapest/fastest — reordering burns tokens | Keep cheap models early in the chain |
| `PTT.add_finding()` | All findings flow through this | Don't change the `fid` generation scheme or MITRE tagging logic |
| Top-level `WORKFLOWS` / `AGENT_SPECS` dicts | These are module-level globals — mutating them at runtime affects all sessions | Mutations done by sub-commands are session-local by design |

---

## 11. Debug Mode & Log Inspection

### Log files

Every session writes a log to:
```
~/.dronecoil/logs/session_YYYYMMDD_HHMMSS.txt
```
ANSI escape codes are stripped. Each entry is prefixed:
- `[PRIEST]` — operator input
- `[DRONECOIL]` — DroneCoil's print output
- `[CMD]` / `[TOOL]` — dispatched commands
- `[OUTPUT]` — subprocess stdout (trimmed)
- `[FINDING]` — extracted findings

### Force re-run the boot check

The tool availability check is cached for 6 hours at `/tmp/dronecoil_session.lock`. Delete it to force re-check:
```bash
rm -f /tmp/dronecoil_session.lock
```

### Verbose subprocess output

`run_command()` already prints all output to the terminal. If you need the raw bytes (before compression), add a temporary `print(repr(raw_stdout))` inside `run_command()` after the `subprocess.run()` call.

### Tracing the agent selection path

To see why a given PTT node routed to a specific agent:
```bash
grep -n "_select_agent\|PHASE_TO_AGENT" dronecoil.py | head -20
```
Then trace `ptt_node.phase` → `PHASE_TO_AGENT[phase]` → `AGENT_SPECS[key]`.

### Checking scope enforcement

```
scope        ← at the REPL, shows current allowed CIDRs / domains
```
Or inspect `~/.dronecoil/scope.json` directly.

### Resetting everything without restarting

```
reset        ← at the REPL, wipes PTT, findings, history, sudo cache, turn counters
```

---

*Last updated: v7.3 — See `docs/DEVELOPER_GUIDE.md` for the complete architecture reference and `docs/CUSTOMIZATION.md` for step-by-step recipes.*
