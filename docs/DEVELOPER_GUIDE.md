# DroneCoil Developer Guide

> **Version:** 7.3 · **Target Platform:** Kali NetHunter / Kali Linux / Debian
> **For:** New developers taking over or contributing to the project.

---

## Table of Contents

1. [What Is DroneCoil?](#1-what-is-dronecoil)
2. [Repository Layout](#2-repository-layout)
3. [Top-Down Architecture](#3-top-down-architecture)
4. [Core Data Models](#4-core-data-models)
5. [Component Deep-Dives](#5-component-deep-dives)
   - 5.1 [DroneCoilSession — The Brain](#51-dronecoilsession--the-brain)
   - 5.2 [Pentesting Task Tree (PTT)](#52-pentesting-task-tree-ptt)
   - 5.3 [Agent System](#53-agent-system)
   - 5.4 [Workflow System](#54-workflow-system)
   - 5.5 [Tool Dispatch Layer](#55-tool-dispatch-layer)
   - 5.6 [Knowledge Base (KB)](#56-knowledge-base-kb)
   - 5.7 [Prompt Construction Pipeline](#57-prompt-construction-pipeline)
   - 5.8 [Context Manager](#58-context-manager)
   - 5.9 [Scope / RoE Enforcement](#59-scope--roe-enforcement)
   - 5.10 [Attack Graph](#510-attack-graph)
   - 5.11 [Finding Extraction](#511-finding-extraction)
   - 5.12 [Groq Provider Chain](#512-groq-provider-chain)
6. [Turn Execution Flow](#6-turn-execution-flow)
7. [GUI Architecture (dronecoil_gui.py)](#7-gui-architecture-dronecoil_guipy)
8. [Install & Runtime Paths](#8-install--runtime-paths)
9. [Key Constants Cheat-Sheet](#9-key-constants-cheat-sheet)

---

## 1. What Is DroneCoil?

DroneCoil is an **AI-driven offensive security agent** that wraps a Groq-hosted LLM (free tier) around a structured pentesting engine. The operator provides a target and an objective; DroneCoil:

1. Seeds a **Pentesting Task Tree (PTT)** — a hierarchical to-do list for the engagement.
2. For each tree node, selects a matching **specialist agent** (recon, web, AD, etc.).
3. Builds a compressed **system prompt** containing only the context the agent needs.
4. Calls the **LLM** and receives a structured response with `[THOUGHT]`, `[CMD]` or `[TOOL]/[ARGS]`, and a confidence tag.
5. Parses the response, checks **scope**, asks the operator for `y/n/q`, runs the command via **subprocess**.
6. Extracts **findings** from real subprocess output (never from the AI's prose).
7. Updates the PTT, attack graph, and loops until done.

Everything is orchestrated inside `dronecoil.py`. The GUI (`dronecoil_gui.py`) is a GTK4 shell that spawns `dronecoil.py` as a child process and parses its output into visual cards.

---

## 2. Repository Layout

```
DroneCoil/
├── dronecoil.py          # 6 275 lines — the entire CLI engine
├── dronecoil_gui.py      # 1 566 lines — GTK4 / libadwaita GUI shell
├── dronecoil-gui         # Bash launcher script for the GUI
├── bootstrap.sh       # One-shot remote installer (curl | bash)
├── install.sh         # Local install script (symlinks, deps, desktop entry)
├── requirements.txt   # Python deps: groq>=0.4.0, networkx>=3.0
├── io.thepriest.DroneCoil.desktop  # XDG desktop entry
├── io.thepriest.DroneCoil.svg      # Application icon
├── docs/              # ← YOU ARE HERE
│   ├── DEVELOPER_GUIDE.md
│   ├── CUSTOMIZATION.md
│   └── REFERENCE.md
└── README.md
```

`dronecoil.py` is **intentionally monolithic** — all configuration lives as top-level constants so operators can fork, diff, and patch without a build system.

---

## 3. Top-Down Architecture

```mermaid
graph TD
    Operator["👤 Operator<br/>(CLI or GUI)"]
    
    subgraph GUI["dronecoil_gui.py — GTK4 Shell"]
        DroneCoilProcess["DroneCoilProcess<br/>spawns dronecoil.py as subprocess"]
        PanelParser["PanelParser<br/>parses ANSI output → card events"]
        ConversationView["ConversationView<br/>renders cards in scroll view"]
        InputBar["InputBar<br/>y/n/q / free text"]
    end

    subgraph Engine["dronecoil.py — Engine"]
        REPL["REPL / show_workflow_menu()<br/>main() entry point"]
        Session["DroneCoilSession<br/>all stateful runtime data"]
        
        subgraph Turn["Per-Turn Loop (_agent_loop)"]
            SelectAgent["_select_agent()<br/>PTT node → agent role"]
            BuildPrompt["build_system_prompt()<br/>assembles system prompt"]
            CallLLM["_think_with_fallback()<br/>Groq API + fallback chain"]
            ParseResponse["parse_specialist_response()<br/>extracts XML-ish tags"]
            DispatchTool["dispatch_tool()<br/>ToolBuilder → shell string"]
            ScopeCheck["ScopeConfig.check()<br/>RoE enforcement"]
            RunCmd["run_command()<br/>subprocess + timeout"]
            ExtractFindings["extract_findings_from_stdout()<br/>regex on real output"]
            UpdateState["Update PTT / AttackGraph<br/>/ history / context"]
        end
    end

    subgraph State["Persistent State (~/.dronecoil/)"]
        PTT["PTT<br/>(Pentesting Task Tree)"]
        Findings["Findings<br/>(tagged + source-stamped)"]
        AttackGraph["AttackGraph<br/>(networkx DiGraph)"]
        Scope["scope.json<br/>(RoE config)"]
        Logs["logs/<br/>(per-session .txt)"]
    end

    subgraph LLM["Groq API"]
        ProviderChain["PROVIDER_CHAIN<br/>LLaMA 3.1 8B → ... → Compound Beta"]
    end

    Operator -->|"type command / y/n/q"| REPL
    REPL --> Session
    Session --> Turn
    Turn --> LLM
    Turn --> State
    DroneCoilProcess -->|"stdin/stdout pipe"| Session
    PanelParser --> ConversationView
    Operator -->|"GTK4 UI"| InputBar
    InputBar --> DroneCoilProcess
```

---

## 4. Core Data Models

```mermaid
classDiagram
    class DroneCoilSession {
        +target_info: Dict
        +lhost: str
        +history: List~Dict~
        +current_agent: str
        +current_workflow_key: str
        +stuck_counter: int
        +ptt: PTT
        +scope: ScopeConfig
        +graph: AttackGraph
        +context_mgr: ContextManager
        +cred_fanout_queue: List~Tuple~
        +attack_techniques_used: Dict
        +groq_client: Groq
        +_turn_no: int
        +_prompt_turn: int
        +think_turn(prompt) Dict
        +_agent_loop(prompt, workflow_key)
        +run_command(cmd, label) str
        +run_workflow(key)
    }

    class PTT {
        +goal: str
        +nodes: Dict~str, PTTNode~
        +findings: List~Finding~
        +root_id: str
        +add_node(parent_id, title, phase)
        +set_status(nid, status)
        +find_in_progress() PTTNode
        +find_next_pending() PTTNode
        +add_finding(value, ftype, source_cmd)
        +to_natural_language() str
        +to_terminal() str
    }

    class PTTNode {
        +nid: str
        +title: str
        +phase: str
        +status: str  ✓ todo|in_progress|done|dead_end
        +confidence: str  ✓ green|yellow|red
        +attempts: int
        +last_cmd: str
        +findings: List~str~
        +children: List~str~
        +parent_id: str
    }

    class Finding {
        +fid: str
        +value: str
        +ftype: str  ✓ ip|port|svc|user|hash|cve|cred...
        +source_cmd: str
        +verified: bool
        +node_id: str
        +attack_id: str
        +timestamp: str
    }

    class ContextManager {
        +last_node_id: str
        +recent_conf: str
        +recent_stuck: int
        +tokens_saved_estimate: int
        +history_slice_size() int
        +should_attach_full_ptt() bool
        +should_attach_graph() bool
    }

    class ScopeConfig {
        +enabled: bool
        +allowed_cidrs: List~str~
        +blocked_cidrs: List~str~
        +allowed_domains: List~str~
        +blocked_domains: List~str~
        +time_window: Dict
        +check(cmd, target_hint) Tuple~bool,str~
    }

    class AttackGraph {
        +graph: DiGraph
        +add_host(ip, attrs)
        +add_service(host_ip, port, name, version)
        +add_credential(value, user)
        +add_hash(value, htype, user)
    }

    DroneCoilSession "1" --> "1" PTT
    DroneCoilSession "1" --> "1" ContextManager
    DroneCoilSession "1" --> "1" ScopeConfig
    DroneCoilSession "1" --> "1" AttackGraph
    PTT "1" --> "*" PTTNode
    PTT "1" --> "*" Finding
    PTTNode "1" --> "*" PTTNode : children
```

---

## 5. Component Deep-Dives

### 5.1 DroneCoilSession — The Brain

**File:** `dronecoil.py` · **Line:** ~4194

`DroneCoilSession` is the single runtime object that owns all engagement state. It is instantiated once in `main()` and lives for the session.

```
__init__()
  ├── _init_provider()        → validate GROQ_API_KEY, create Groq client
  ├── _start_log()            → open ~/.dronecoil/logs/session_YYYYMMDD_HHMMSS.txt
  ├── _run_boot_check()       → verify Kali tools availability (cached 6h)
  ├── get_lhost()             → detect attacker IP (hostname -I, /proc/net/route)
  └── ensure_rockyou()        → gunzip /usr/share/wordlists/rockyou.txt.gz if needed
```

**Key methods:**

| Method | Purpose |
|---|---|
| `think_turn(prompt, workflow_key)` | Single LLM turn — selects agent, builds prompt, calls API, parses response, dispatches tool |
| `_agent_loop(initial_prompt, workflow_key)` | Main execution loop — calls `think_turn` repeatedly, handles y/n/q, updates PTT |
| `run_command(cmd, label)` | subprocess execution with timeout, sudo retry, output compression |
| `run_workflow(key)` | Seeds PTT from `WORKFLOWS[key]` and starts `_agent_loop` |
| `_select_agent(node, free_form)` | Deterministic agent picker: node.phase → PHASE_TO_AGENT → AGENT_SPECS |
| `_resolve_target()` | Returns `target_info["host"]` or prompts operator |
| `show_findings()` | Pretty-prints all findings from PTT |
| `show_ptt()` | Renders PTT as a tree |
| `generate_report()` | Invokes reporter agent to produce structured report |

---

### 5.2 Pentesting Task Tree (PTT)

**File:** `dronecoil.py` · **Line:** ~1388

The PTT is a **rooted tree** of `PTTNode` objects representing every task in the engagement. It replaces the flat findings dict from v6.x.

```
Root (goal)
  ├── 1   Host discovery
  │   └── 1.1  Top-port scan
  │       └── 1.1.1  Service version detection
  ├── 2   Web enumeration
  │   ├── 2.1  Directory brute-force
  │   └── 2.2  SQLi testing
  └── 3   Privilege escalation
      └── 3.1  SUID hunt
```

**Node statuses:** `todo` → `in_progress` → `done` / `dead_end`

**Node confidence:** `green` (high confidence) | `yellow` (uncertain) | `red` (need more info)

The tree is serialised to natural language via `to_natural_language()` and injected into system prompts so the LLM always knows the full engagement state.

---

### 5.3 Agent System

**File:** `dronecoil.py` · **Line:** ~1133  
**Dict:** `AGENT_SPECS`

DroneCoil has **11 specialist agents**. Each is a named system-prompt fragment, not a separate API call. The dispatcher is deterministic — zero extra tokens spent on routing.

```mermaid
graph TD
    Input["Operator input / PTT node phase"]
    Dispatcher["_select_agent()<br/>PHASE_TO_AGENT lookup"]
    
    Dispatcher --> strategist["♔ Strategist<br/>routes between agents"]
    Dispatcher --> recon["🔍 Recon<br/>nmap · masscan · rustscan"]
    Dispatcher --> web["🕸 Web<br/>feroxbuster · sqlmap · nikto"]
    Dispatcher --> network["🌐 Network<br/>SMB · SSH · FTP · RDP"]
    Dispatcher --> ad["🏰 Active Directory<br/>kerbrute · impacket · certipy"]
    Dispatcher --> linux["🐧 Linux PrivEsc<br/>SUID · sudo · linpeas"]
    Dispatcher --> windows["🪟 Windows PrivEsc<br/>winpeas · PrintSpoofer"]
    Dispatcher --> credential["🔑 Credential<br/>hashcat · hydra · nxc"]
    Dispatcher --> exfil["📤 Exfiltration<br/>HTTPS · DNS · ICMP"]
    Dispatcher --> evasion["🥷 Evasion<br/>-T1 · frags · decoys · MAC"]
    Dispatcher --> reporter["📋 Reporter<br/>structured report output"]
```

**Each agent entry in `AGENT_SPECS` has:**

| Key | Purpose |
|---|---|
| `name` | Display name (e.g. `"RECON SPECIALIST"`) |
| `icon` | Emoji shown in UI |
| `color` | ANSI colour code for the agent's output |
| `persona` | System-prompt paragraph describing the agent's role and approach |
| `extra_rules` | Tactical rules injected only for this agent (preferred tools, ordering, etc.) |

**Phase → Agent mapping** (`PHASE_TO_AGENT` dict, line ~1315):

```
"recon" / "enum"             → recon
"web" / "web_recon" / ...    → web
"network" / "service_exploit"→ network
"ad" / "ad_recon" / ...      → ad
"linux_post" / "linux_privesc"→ linux_privesc
"windows_post" / ...         → windows_privesc
"credential" / "cracking"    → credential
"exfil"                      → exfil
"evasion"                    → evasion
"report"                     → reporter
```

---

### 5.4 Workflow System

**File:** `dronecoil.py` · **Line:** ~3550  
**Dict:** `WORKFLOWS`

Workflows are **PTT seeders** — they pre-populate the task tree with a known engagement path. There are **23 built-in workflows**.

```mermaid
graph LR
    Menu["workflow command<br/>show_workflow_menu()"] -->|"key 1-23"| RunWF["run_workflow(key)"]
    RunWF --> Seed["_seed_ptt_from_workflow(key, target)<br/>adds PTTNode per seed entry"]
    Seed --> Loop["_agent_loop(prompt, workflow_key=key)"]
    Loop --> ThinkTurn["think_turn() × N"]
    ThinkTurn -->|"WORKFLOW_COMPLETE"| NextNode["advance to next pending node"]
    NextNode --> ThinkTurn
    NextNode -->|"all nodes done"| Done["Engagement complete"]
```

**Workflow structure:**

```python
WORKFLOWS = {
    "1": {
        "name": "Network Recon",
        "description": "ARP sweep → port scan → service detection → CVE correlation",
        "seed": [
            ("Host discovery (arp-scan / ping sweep)", "recon"),   # (title, phase)
            ("Top-port scan with version detection",   "recon"),
            ("Full TCP scan (-p-) for stragglers",     "recon"),
            ...
        ],
    },
    ...
}
```

Each `seed` entry is a `(title, phase)` tuple. `_seed_ptt_from_workflow()` converts each into a `PTTNode`, assigning node IDs like `1`, `1.1`, `1.2`, etc.

---

### 5.5 Tool Dispatch Layer

**File:** `dronecoil.py` · **Line:** ~2464  
**Classes/Dicts:** `ToolBuilder`, `TOOL_DISPATCH`, `TOOL_BINARY`, `KWARG_SYNONYMS`

The tool layer has three parts:

```mermaid
graph LR
    LLM["LLM output<br/>[TOOL]nmap[/TOOL][ARGS]{...}[/ARGS]"]
    Dispatch["dispatch_tool(name, args_json)"]
    Synonyms["_apply_kwarg_synonyms()<br/>normalise LLM arg name variations"]
    Binary["_tool_binary_present()<br/>which nmap — skip if not installed"]
    Builder["ToolBuilder.nmap(**kwargs)<br/>returns shell string"]
    Shell["nmap -sS -T4 --min-rate 5000 -p- 10.0.0.1"]

    LLM --> Dispatch
    Dispatch --> Synonyms
    Dispatch --> Binary
    Synonyms --> Builder
    Builder --> Shell
```

**`ToolBuilder`** (line ~2464) — 28 static methods, each returns a properly-formed shell string.

**`TOOL_DISPATCH`** (line ~2833) — maps tool name strings to `ToolBuilder` methods:

```python
TOOL_DISPATCH = {
    "nmap":              ToolBuilder.nmap,
    "rustscan":          ToolBuilder.rustscan,
    "masscan":           ToolBuilder.masscan,
    "gobuster_dir":      ToolBuilder.gobuster_dir,
    "feroxbuster":       ToolBuilder.feroxbuster,
    "ffuf":              ToolBuilder.ffuf,
    "whatweb":           ToolBuilder.whatweb,
    "nikto":             ToolBuilder.nikto,
    "nuclei":            ToolBuilder.nuclei,
    "hydra":             ToolBuilder.hydra,
    "sqlmap":            ToolBuilder.sqlmap,
    "searchsploit":      ToolBuilder.searchsploit,
    "smbclient_list":    ToolBuilder.smbclient_list,
    "crackmapexec":      ToolBuilder.crackmapexec,
    "enum4linux":        ToolBuilder.enum4linux,
    "hashcat":           ToolBuilder.hashcat,
    "hashid":            ToolBuilder.hashid,
    "curl_basic":        ToolBuilder.curl_basic,
    "kerbrute_userenum": ToolBuilder.kerbrute_userenum,
    "impacket_asreproast":   ToolBuilder.impacket_asreproast,
    "impacket_kerberoast":   ToolBuilder.impacket_kerberoast,
    "impacket_secretsdump":  ToolBuilder.impacket_secretsdump,
    "msfvenom_payload":  ToolBuilder.msfvenom_payload,
    "sslscan":           ToolBuilder.sslscan,
    "testssl":           ToolBuilder.testssl,
    "dnsrecon":          ToolBuilder.dnsrecon,
    "theharvester":      ToolBuilder.theharvester,
    "gobuster_vhost":    ToolBuilder.gobuster_vhost,
}
```

**`KWARG_SYNONYMS`** (line ~106) — per-tool dict mapping LLM-emitted arg name variations to canonical parameter names, preventing dispatch failures from minor naming differences.

**`KALI_TOOLS`** (line ~334) — a broader registry of 200+ Kali tools organised by category (recon, web, exploitation, post, etc.), used to build the tool summary injected into the first two system prompts.

---

### 5.6 Knowledge Base (KB)

**File:** `dronecoil.py` · **Line:** ~720  
**Dict:** `KB`

The KB is a numbered dict of tactical reference sections. Each entry is a multi-line string containing command cheat-sheet material for a specific attack phase.

| Section | Topic |
|---|---|
| `KB[1]` | Operator Mindset / noise discipline |
| `KB[2]` | Network Recon (nmap, masscan, tcpdump) |
| `KB[3]` | Web Exploitation (SQLi, XSS, SSRF, LFI, SSTI, JWT) |
| `KB[4]` | Active Directory Kill Chain |
| `KB[5]` | Linux Privesc (GTFOBins, SUID, cron, caps) |
| `KB[6]` | Windows Privesc (SeImpersonate, unquoted paths) |
| `KB[7+]` | Credential attacks, evasion, exfil, reporting, etc. |

**`WORKFLOW_KB_MAP`** (line ~1031) maps each workflow key to the set of KB section numbers to inject into its prompts. `get_kb_sections(workflow_key, agent_role)` returns the union of relevant sections, capped at 4 per turn to control token usage.

---

### 5.7 Prompt Construction Pipeline

**File:** `dronecoil.py` · **Function:** `build_system_prompt()` (~line 3920)

Every LLM call produces a system prompt assembled from these layers, in order:

```mermaid
graph TD
    A["1. MENTOR_PERSONA<br/>DroneCoil's voice + teaching duty"] --> P
    B["2. Agent persona<br/>AGENT_SPECS[role]['persona']"] --> P
    C["3. Agent extra_rules<br/>AGENT_SPECS[role]['extra_rules']"] --> P
    D["4. CORE_RULES<br/>output format, tag syntax, safety rules"] --> P
    E["5. Target info<br/>host, ports, services, OS"] --> P
    F["6. PTT summary<br/>to_natural_language() — always included"] --> P
    G["7. Active node detail<br/>current title, phase, attempts"] --> P
    H["8. KB sections<br/>4 relevant sections (workflow-dependent)"] --> P
    I["9. Tools block (turns 1-2 only)<br/>kali_tool_summary + tool_registry"] --> P
    J["10. Context attachments<br/>[NEED]-triggered: ptt/history/graph/findings"] --> P
    K["11. Scope summary<br/>if scope.enabled"] --> P
    P["Final system prompt<br/>passed as messages[0]"]
```

After the system prompt, history is appended as `[{role: user/assistant, content: ...}]` (windowed to `DEFAULT_HISTORY_SLICE = 3` turns normally, `EXPANDED_HISTORY_SLICE = 6` when stuck or low-confidence). The latest user message is appended last.

**Token savings (v7.3):** The tools block (~2 800 chars) is only sent on turns 1–2. After that the model has already seen the tool set. The LLM can request it back with `[NEED]tools[/NEED]`.

---

### 5.8 Context Manager

**File:** `dronecoil.py` · **Class:** `ContextManager` (~line 3499)

`ContextManager` is a lightweight stateful advisor that decides what context to send each turn without the LLM needing to ask:

| Signal | Triggered by | Effect |
|---|---|---|
| Node change | PTT advances to new node | Attaches PTT summary |
| `conf=yellow/red` | LLM returns low confidence | Expands history slice (3→6), attaches PTT + graph |
| `stuck_counter > 0` | Same command attempted 3× | Expands history slice |
| `[NEED]…[/NEED]` | LLM requests extra context | Fetches and re-calls API (max 2 per turn) |

---

### 5.9 Scope / RoE Enforcement

**File:** `dronecoil.py` · **Class:** `ScopeConfig` (~line 3108)  
**Config file:** `~/.dronecoil/scope.json`

Before any command hits subprocess, `ScopeConfig.check(cmd, target_hint)` validates it against:
- **Allowed CIDRs** — if scope is enabled, the target IP must match at least one.
- **Blocked CIDRs** — command is refused if target is in a blocked range.
- **Allowed/blocked domains** — wildcard-aware (`*.example.com`).
- **Time window** — ISO-8601 start/end strings; commands outside the window are refused.

Out-of-scope commands print a warning and skip execution. The operator is shown exactly why the command was blocked.

---

### 5.10 Attack Graph

**File:** `dronecoil.py` · **Class:** `AttackGraph` (~line 3279)

The attack graph is a `networkx.DiGraph` tracking relationships between discovered hosts, services, credentials, and hashes. It provides **pivot suggestions** — nodes that are reachable from current credentials.

Nodes are typed: `host`, `service`, `cred`, `hash`. Edges represent "leads to" or "authenticates to" relationships discovered during the engagement.

---

### 5.11 Finding Extraction

**File:** `dronecoil.py` · **Function:** `extract_findings_from_stdout()` (~line 1718)  
**Dict:** `FINDING_PATTERNS`

Findings are extracted **only from raw subprocess stdout**, never from the LLM's prose. This prevents the AI from hallucinating findings.

Supported finding types:

| Type | Example value |
|---|---|
| `ip` | `10.0.0.5` |
| `port` | `22` |
| `svc` | `OpenSSH 8.2p1` |
| `user` | `administrator` |
| `hash_ntlm` | `aad3b...` |
| `hash` | generic 32-64 char hex |
| `krb_hash` | `$krb5asrep$...` |
| `ntlmv2` | `user::dom:...` |
| `cve` | `CVE-2021-3156` |
| `domain` | `corp.local` |
| `url` | `https://...` |
| `cred` | `password: toor` |
| `smb_share` | `\\10.0.0.5\ADMIN$` |
| `email` | `admin@corp.com` |
| `ssh_key` | `-----BEGIN RSA PRIVATE KEY-----` |
| `aws_key` | `AKIA...` |

Each extracted finding is stamped with its source command, the PTT node that produced it, and a MITRE ATT&CK technique ID (via `attack_id_for_finding()`).

---

### 5.12 Groq Provider Chain

**File:** `dronecoil.py` · **Constant:** `PROVIDER_CHAIN` (~line 56)

DroneCoil uses a fallback chain of Groq-hosted models, starting with the cheapest/fastest:

```
1. llama-3.1-8b-instant       (cheapest, fastest)
2. gemma2-9b-it
3. meta-llama/llama-4-scout-17b-16e-instruct
4. qwen/qwen3-32b
5. llama-3.3-70b-versatile
6. deepseek-r1-distill-llama-70b
7. compound-beta-mini
8. compound-beta               (most capable, most expensive)
```

When a model returns a rate-limit error or fails, `_think_with_fallback()` advances `provider_index` to the next entry. The index resets after a configurable idle period. The `model` REPL command shows current chain status.

---

## 6. Turn Execution Flow

This is what happens every time the operator presses Enter (or `y` to a command suggestion):

```mermaid
flowchart TD
    Start([Operator input / y]) --> PendingErr{Pending dispatch<br/>error from last turn?}
    PendingErr -->|Yes| PrependError["Prepend error to prompt<br/>so LLM corrects itself"]
    PendingErr -->|No| SelectAgent
    PrependError --> SelectAgent

    SelectAgent["_select_agent()<br/>PTT node phase → agent role"] --> BuildSysPrompt
    BuildSysPrompt["build_system_prompt()<br/>assemble layered prompt"] --> WindowHistory
    WindowHistory["Window history<br/>(3 or 6 turns)"] --> CallGroq
    CallGroq["_think_with_fallback()<br/>Groq API call"] --> ParseResp

    ParseResp["parse_specialist_response()<br/>extract THOUGHT CMD TOOL ARGS CONF HANDOFF NEED VERIFY MANUAL"] --> NeedCheck{LLM emitted<br/>[NEED]?}
    NeedCheck -->|Yes, <2 fetches| AttachContext["Attach requested context<br/>(ptt/findings/graph/kb N/tools)"]
    AttachContext --> CallGroq
    NeedCheck -->|No or limit hit| CmdCheck

    CmdCheck{Got [CMD] or [TOOL]?} -->|No| RetryCheck{Retries < 2?}
    RetryCheck -->|Yes| CorrectiveHint["Send corrective hint prompt"]
    CorrectiveHint --> CallGroq
    RetryCheck -->|No| Bail[/"Break loop — bail"/]

    CmdCheck -->|Yes| WorkflowDone{WORKFLOW_COMPLETE<br/>in cmd?}
    WorkflowDone -->|Yes, 0 findings & 0 successes| RefuseComplete["Refuse — force real attempt"]
    WorkflowDone -->|Yes, has findings or success| AdvancePTT["Advance PTT to next node"]
    WorkflowDone -->|No| ToolDispatch

    RefuseComplete --> ToolDispatch
    AdvancePTT --> NextNode{More pending<br/>nodes?}
    NextNode -->|Yes| Start
    NextNode -->|No| Done([Engagement complete])

    ToolDispatch["dispatch_tool() if [TOOL]<br/>else use [CMD] as-is"] --> DispatchErr{Dispatch<br/>error?}
    DispatchErr -->|Yes| RecordErr["Record pending dispatch error<br/>for next turn's prompt"]
    DispatchErr -->|No| DisplayCmd

    DisplayCmd["Display command_card()<br/>(thought + command + confidence)"] --> YNQ{y / n / q?}
    YNQ -->|n| SkipCmd["Skip, advance PTT, next turn"]
    YNQ -->|q| Quit([Exit session])
    YNQ -->|y| ScopeCheck

    ScopeCheck["ScopeConfig.check(cmd)"] --> InScope{In scope?}
    InScope -->|No| RefuseScope["Print scope warning, skip"]
    InScope -->|Yes| RunCmd

    RunCmd["run_command()<br/>subprocess + timeout + sudo retry"] --> ExtractFindings
    ExtractFindings["extract_findings_from_stdout()<br/>FINDING_PATTERNS on raw output"] --> UpdatePTT
    UpdatePTT["Update PTT node status/confidence<br/>add findings, update attack graph"] --> UpdateHistory
    UpdateHistory["Append to history<br/>trim to MAX_HISTORY_MESSAGES"] --> CredFanout
    CredFanout["Run credential fanout queue<br/>(test new creds across services)"] --> Start
```

---

## 7. GUI Architecture (dronecoil_gui.py)

The GUI is a **GTK4 / libadwaita** shell that wraps `dronecoil.py` as a subprocess. It does **not** contain any LLM or pentesting logic — it only renders DroneCoil's output as cards.

```mermaid
graph TD
    subgraph GUI["dronecoil_gui.py"]
        App["Adw.Application<br/>DroneCoilApp"]
        Win["DroneCoilWindow<br/>Adw.ApplicationWindow"]
        ConvView["ConversationView<br/>scrollable card list"]
        InputBar["InputBar<br/>entry + send button"]
        Wizard["EngagementWizard<br/>target + goal dialog"]

        subgraph Cards["Card Widgets"]
            WelcomeCard
            ThoughtCard
            CommandCard["CommandCard<br/>(y/n/q buttons)"]
            ResultCard
            FindingsCard
            ErrorCard
            ManualPlaybookCard
            DispatchCard
            TurnHeader
        end

        DroneCoilProcess["DroneCoilProcess<br/>GObject, owns pty/subprocess"]
        PanelParser["PanelParser<br/>state machine on output lines"]
        LineBuffer["LineBuffer<br/>byte accumulator"]
    end

    dronecoil_py["dronecoil.py<br/>(subprocess)"]

    App --> Win
    Win --> ConvView
    Win --> InputBar
    Win --> Wizard
    ConvView --> Cards
    InputBar -->|"write to stdin"| DroneCoilProcess
    DroneCoilProcess -->|"spawn"| dronecoil_py
    dronecoil_py -->|"stdout (ANSI)"| LineBuffer
    LineBuffer -->|"lines"| PanelParser
    PanelParser -->|"events {type, title, body}"| ConvView
    ConvView -->|"classify_panel_title()"| Cards
```

**PanelParser** is the key bridge. It reads DroneCoil's ANSI-formatted output line by line and emits structured events like `{type: "panel", title: "THOUGHT", body: "..."}`. `ConversationView.handle_event()` then routes each event to the right card class.

**Panel → Card mapping** (`classify_panel_title()`):

| Panel title pattern | Card class |
|---|---|
| `THOUGHT` / `REASONING` | `ThoughtCard` |
| `CMD` / `COMMAND` | `CommandCard` (has y/n/q buttons) |
| `RESULT` / `OUTPUT` | `ResultCard` |
| `FINDINGS` | `FindingsCard` |
| `ERROR` / `FATAL` | `ErrorCard` |
| `MANUAL` / `PLAYBOOK` | `ManualPlaybookCard` |
| `DISPATCH` | `DispatchCard` |
| turn headers | `TurnHeader` |
| anything else | `PlainCard` |

---

## 8. Install & Runtime Paths

| Path | Purpose |
|---|---|
| `~/dronecoil/` (or wherever cloned) | Source code |
| `/usr/local/bin/dronecoil` | Symlink → `dronecoil.py` |
| `/usr/local/bin/dronecoil-gui` | Symlink → `dronecoil-gui` launcher script |
| `~/.dronecoil/` | Runtime data root |
| `~/.dronecoil/logs/session_*.txt` | Per-session ANSI-stripped logs |
| `~/.dronecoil/scope.json` | Engagement scope / RoE config |
| `~/.local/share/applications/io.thepriest.DroneCoil.desktop` | XDG desktop entry |
| `~/.local/share/icons/hicolor/scalable/apps/io.thepriest.DroneCoil.svg` | App icon |
| `/tmp/dronecoil_session.lock` | Boot-check cache (TTL: 6h) |

---

## 9. Key Constants Cheat-Sheet

These are the knobs you'll reach for most often when hacking on the engine:

| Constant | File line | Default | Effect |
|---|---|---|---|
| `VERSION` | ~54 | `"7.3"` | Displayed in UI headers |
| `PROVIDER_CHAIN` | ~58 | 8 entries | LLM fallback order |
| `MAX_HISTORY_MESSAGES` | ~85 | `32` | RAM turns kept |
| `DEFAULT_HISTORY_SLICE` | ~86 | `3` | Turns sent to API normally |
| `EXPANDED_HISTORY_SLICE` | ~87 | `6` | Turns sent when stuck/low-conf |
| `MAX_OUTPUT_CHARS` | ~88 | `4000` | Subprocess output cap |
| `MAX_TOKENS_DEFAULT` | ~89 | `1024` | LLM max_tokens per call |
| `TOOLS_BLOCK_TURNS` | ~95 | `2` | Include tools block only for first N turns |
| `STUCK_THRESHOLD` | ~101 | `3` | Repeated commands before pivot |
| `NODE_ATTEMPT_LIMIT` | ~102 | `4` | Max attempts per PTT node |
| `DEFAULT_COMMAND_TIMEOUT` | ~131 | `300` | Subprocess timeout (seconds) |
| `BOOT_LOCK_TTL_SECONDS` | ~137 | `21600` | How often to re-run boot check |
| `MAX_NEED_FETCHES` | ~99 | `2` | Max `[NEED]` re-calls per turn |
