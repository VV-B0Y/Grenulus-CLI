# DroneCoil Customization Guide

> How to add new agents, workflows, tools, prompts, KB sections, and supported models.
> All customization is done directly in `dronecoil.py` — no build step required.

---

## Table of Contents

1. [Adding a New Specialist Agent](#1-adding-a-new-specialist-agent)
2. [Adding a New Workflow](#2-adding-a-new-workflow)
3. [Adding a New Tool](#3-adding-a-new-tool)
4. [Customizing Agent Prompts](#4-customizing-agent-prompts)
5. [Adding Knowledge Base Sections](#5-adding-knowledge-base-sections)
6. [Adding a New LLM Provider / Model](#6-adding-a-new-llm-provider--model)
7. [Adding New Finding Types](#7-adding-new-finding-types)
8. [Adjusting Command Timeouts](#8-adjusting-command-timeouts)
9. [Customizing Scope / RoE Defaults](#9-customizing-scope--roe-defaults)
10. [Adding REPL Commands](#10-adding-repl-commands)
11. [Extending the GUI with a New Card Type](#11-extending-the-gui-with-a-new-card-type)

---

## 1. Adding a New Specialist Agent

Agents live in the `AGENT_SPECS` dict (~line 1135 in `dronecoil.py`). Adding one is three steps.

### Step 1 — Add the spec

```python
# dronecoil.py  ~line 1135
AGENT_SPECS = {
    # ... existing agents ...

    "iot": {                            # ← your key (used everywhere else)
        "name": "IoT SPECIALIST",
        "icon": "📡",
        "color": "96",                  # ANSI colour (96 = bright cyan)
        "persona": (
            "You are DroneCoil's IoT specialist. You enumerate embedded devices, "
            "firmware, default credentials, MQTT/CoAP/Zigbee, and exposed "
            "management interfaces (Telnet/serial/web dashboards)."
        ),
        "extra_rules": (
            "First: nmap -sV -p 23,80,443,1883,5683,8080,8443,8883 TARGET. "
            "Always test factory default credentials (admin/admin, admin/1234, "
            "root/root). Check for CVEs in firmware version via searchsploit. "
            "If MQTT open (1883): mosquitto_sub -h HOST -t '#' -v."
        ),
    },
}
```

### Step 2 — Map it to phases

Add entries to `PHASE_TO_AGENT` (~line 1315) for any PTT phases this agent should handle:

```python
PHASE_TO_AGENT = {
    # ... existing entries ...
    "iot":          "iot",
    "iot_recon":    "iot",
    "iot_exploit":  "iot",
    "firmware":     "iot",
}
```

### Step 3 — (Optional) Map it in `[AGENT]` tag handling

The strategist agent emits `[AGENT]<role>[/AGENT]` to hand off. The valid role names come from `AGENT_SPECS.keys()`. Since you already added the key, the handoff parser will accept it automatically.

**That's it.** The new agent will now be:
- Selected automatically when a PTT node has `phase="iot"` (or any mapped phase).
- Available for the strategist to route to via `[AGENT]iot[/AGENT]`.
- Listed in the `agent` REPL command output.

---

## 2. Adding a New Workflow

Workflows live in the `WORKFLOWS` dict (~line 3550). A workflow is a name, description, and a list of `(task_title, phase)` seed tuples.

```python
# dronecoil.py  ~line 3550
WORKFLOWS = {
    # ... existing 1-23 ...

    "24": {
        "name": "IoT / Embedded Device Assessment",
        "description": "Interface enum → default creds → MQTT recon → firmware CVE",
        "seed": [
            ("Port scan (23/80/443/1883/5683/8080)", "iot"),
            ("Default credential spray",              "iot"),
            ("MQTT topic discovery",                  "iot"),
            ("Web dashboard fingerprint",             "web"),
            ("Firmware version → CVE search",        "iot"),
            ("Coap enumeration (port 5683)",          "iot"),
        ],
    },
}
```

### Linking a workflow to KB sections

To ensure the right KB sections are injected into that workflow's prompts, add an entry in `WORKFLOW_KB_MAP` (~line 1031):

```python
WORKFLOW_KB_MAP = {
    # ... existing entries ...
    "24": {1, 2, 7},    # operator mindset + network recon + (your new KB section)
}
```

### Notes

- Seed phases must exist in `PHASE_TO_AGENT` (add them if you created a new agent).
- The workflow menu is printed by `show_workflow_menu()` — it iterates `WORKFLOWS` automatically, so no extra registration is needed.
- Workflow keys are strings; keep sequential or add a descriptive shorthand like `"iot_basic"`.

---

## 3. Adding a New Tool

Tools require changes in three places: `ToolBuilder`, `TOOL_DISPATCH`, and optionally `TOOL_BINARY`.

### Step 1 — Add a `ToolBuilder` static method

```python
# dronecoil.py  ~line 2464  (inside class ToolBuilder)
class ToolBuilder:
    # ... existing methods ...

    @staticmethod
    def mosquitto_sub(host: str, topic: str = "#",
                      port: int = 1883,
                      username: Optional[str] = None,
                      password: Optional[str] = None) -> str:
        """Subscribe to all MQTT topics on a broker."""
        parts = ["mosquitto_sub", "-h", host, "-p", str(port), "-t", topic, "-v"]
        if username:
            parts.extend(["-u", username])
        if password:
            parts.extend(["-P", password])
        return " ".join(parts)
```

**Rules for ToolBuilder methods:**
- Always return a plain shell string (no `subprocess` calls here).
- Use `Optional[str]` / `Optional[int]` for all optional params.
- Keep param names consistent with what an LLM would naturally emit.
- The method will be called with `**kwargs` unpacked from the LLM's JSON args.

### Step 2 — Register in `TOOL_DISPATCH`

```python
# dronecoil.py  ~line 2833
TOOL_DISPATCH = {
    # ... existing entries ...
    "mosquitto_sub": ToolBuilder.mosquitto_sub,
}
```

### Step 3 — Register the binary for pre-flight check

```python
# dronecoil.py  ~line 2868
TOOL_BINARY = {
    # ... existing entries ...
    "mosquitto_sub": "mosquitto_sub",    # binary name for `which` check
}
```

### Step 4 — (Optional) Add arg synonyms

If the LLM tends to emit slightly different arg names, add them to `KWARG_SYNONYMS`:

```python
# dronecoil.py  ~line 106
KWARG_SYNONYMS = {
    # ... existing entries ...
    "mosquitto_sub": {
        "broker":    "host",
        "server":    "host",
        "user":      "username",
        "pass":      "password",
        "t":         "topic",
    },
}
```

### Step 5 — Add it to `KALI_TOOLS` for the tools summary prompt

```python
# dronecoil.py  ~line 334
KALI_TOOLS = {
    # ... existing categories ...
    "iot": [
        "mosquitto_sub", "mosquitto_pub", "coap-client",
        "zigbee-scanner", "ubertooth-util",
    ],
}
```

After these changes the LLM can emit:
```
[TOOL]mosquitto_sub[/TOOL][ARGS]{"host":"192.168.1.50","topic":"#"}[/ARGS]
```
and DroneCoil will translate it to `mosquitto_sub -h 192.168.1.50 -p 1883 -t # -v`.

---

## 4. Customizing Agent Prompts

There are three levels of prompt text you can edit:

### 4.1 Global voice — `MENTOR_PERSONA` (~line 3920 area)

This is injected into **every** system prompt. It controls DroneCoil's tone, teaching style, and `[MANUAL]` behaviour. Edit `MENTOR_PERSONA` in `dronecoil.py` to change the personality globally.

```python
MENTOR_PERSONA = (
    "── DRONECOIL — VOICE & TEACHING DUTY ──\n"
    "You are DroneCoil: ex-NSA, fifteen years red-team. ..."
    # Change the persona paragraph here
)
```

### 4.2 Global rules — `CORE_RULES` (~line after MENTOR_PERSONA)

`CORE_RULES` defines the **output format** (`[THOUGHT]`, `[CMD]`, `[TOOL]`, `[CONF]`, etc.) and safety rules injected into every prompt. Edit here to:
- Add or remove output tags.
- Change the `[NEED]` mechanism.
- Add new safety restrictions.

> ⚠️ If you add a new tag here, you must also update `parse_specialist_response()` (~line after CORE_RULES) to extract it.

### 4.3 Per-agent `persona` and `extra_rules`

These are the values inside each `AGENT_SPECS` entry (see §1). Edit `persona` to change the agent's strategic approach; edit `extra_rules` to change its preferred tool ordering and tactical shortcuts.

---

## 5. Adding Knowledge Base Sections

KB sections are raw text injected into system prompts when relevant. They are cheap to add.

### Step 1 — Define the section

```python
# dronecoil.py  ~line 720  (after existing KB entries)
KB[15] = r"""
S15 IoT ATTACK PATTERNS:
Default credential lists: admin/admin, admin/password, root/root, guest/guest
MQTT: mosquitto_sub -h HOST -t '#' -v  (listen all topics)
CoAP: coap-client -m get coap://HOST/.well-known/core
Telnet: nc HOST 23  (then try defaults immediately)
Firmware: binwalk -e firmware.bin → check /etc/passwd, private keys, hardcoded creds
Web dashboard: look for /cgi-bin/, /api/v1/, /admin — default UI often unauthenticated
"""
```

### Step 2 — Map it to workflows and agent roles

```python
# dronecoil.py  ~line 1031
WORKFLOW_KB_MAP = {
    # ... existing ...
    "24": {1, 2, 15},    # network recon + your new IoT section
}
```

`get_kb_sections()` also accepts `agent_role` so you can add agent-based KB defaults:

```python
# dronecoil.py  inside get_kb_sections()  ~line 1073
AGENT_KB_MAP = {
    # ... add this if you want role-based KB injection ...
    "iot": {15},
}
```

> **Cap:** Only 4 KB sections are injected per turn to keep token usage low. If you need more, increase the cap in `get_kb_sections()`.

---

## 6. Adding a New LLM Provider / Model

### Add to `PROVIDER_CHAIN`

```python
# dronecoil.py  ~line 56
PROVIDER_CHAIN = [
    ("llama-3.1-8b-instant",                      "LLaMA 3.1 8B"),   # cheapest first
    # ... existing entries ...
    ("your-model-id-on-groq",                      "Your Model Name"),
]
```

The fallback logic in `_think_with_fallback()` iterates the chain in order, so put cheap/fast models first.

### Switching to a non-Groq provider

Currently all inference goes through the `groq` Python package. To use a different OpenAI-compatible endpoint:

1. Replace `from groq import Groq` and `Groq(api_key=...)` with your client library.
2. Update `_think_with_fallback()` — the call site is `self.groq_client.chat.completions.create(model=..., messages=..., max_tokens=...)`.
3. Update `PROVIDER_CHAIN` entries to your model IDs.

---

## 7. Adding New Finding Types

Finding extraction runs `FINDING_PATTERNS` against subprocess output. Add a new regex to capture a new artifact type:

```python
# dronecoil.py  ~line 487
FINDING_PATTERNS = {
    # ... existing ...

    # Capture API keys in ****** format
    "api_key": r'(?:Bearer|Authorization:\s*Bearer)\s+([A-Za-z0-9\-_\.]{20,})',

    # Capture WPA handshake file paths
    "handshake": r'(\S+\.cap)\s+(?:saved|captured)',
}
```

### Tagging findings with MITRE ATT&CK

`attack_id_for_finding(ftype)` (~line 704) maps finding types to ATT&CK technique IDs. Add your new type:

```python
# dronecoil.py  ~line 704  (inside attack_id_for_finding)
FINDING_ATTACK_MAP = {
    # ... existing ...
    "api_key":   ("T1552.001", "Credentials In Files", "TA0006"),
    "handshake": ("T1040",     "Network Sniffing",      "TA0007"),
}
```

---

## 8. Adjusting Command Timeouts

`COMMAND_TIMEOUTS` is a list of `(regex_pattern, seconds)` pairs (~line 108). First match wins. Add or tighten entries:

```python
# dronecoil.py  ~line 108
COMMAND_TIMEOUTS = [
    # ... existing entries ...

    # Custom: slow down mosquitto_sub so it doesn't run forever
    (r'\bmosquitto_sub\b',  30),

    # Custom: long timeout for firmware analysis
    (r'\bbinwalk\b.*-e',   300),
]
DEFAULT_COMMAND_TIMEOUT = 300   # catch-all
```

---

## 9. Customizing Scope / RoE Defaults

The default scope config is written to `~/.dronecoil/scope.json` on first launch if the file doesn't exist. Change `DEFAULT_SCOPE` (~line 3088) to set different defaults:

```python
# dronecoil.py  ~line 3088
DEFAULT_SCOPE = {
    "enabled":  True,               # ← flip to True to enforce scope by default
    "allowed_cidrs":   ["10.10.10.0/24"],   # tighter default
    "blocked_cidrs":   ["10.10.10.0/8"],    # explicitly block rest of RFC1918
    "allowed_domains": ["target.htb"],
    "blocked_domains": [],
    "time_window": {
        "start": "08:00",           # restrict to business hours by default
        "end":   "18:00",
    },
}
```

The operator can also edit `~/.dronecoil/scope.json` directly between sessions.

---

## 10. Adding REPL Commands

The main REPL loop lives at the bottom of `dronecoil.py` inside `main()` (or in the `DroneCoilSession.repl()` method). Find the `if cmd == "..."` block and add a new branch:

```python
# dronecoil.py  ~line 6150  (inside the REPL while loop)
elif cmd == "iot":
    # List all IoT-related findings
    iot_findings = [f for f in self.ptt.findings if f.ftype in ("ip", "port", "cred")]
    print(panel("IoT FINDINGS", [str(f.value) for f in iot_findings], color="96"))

elif cmd == "mqtt":
    # Quick MQTT reconnect shortcut
    target = self._resolve_target()
    if target:
        self.run_command(f"mosquitto_sub -h {target} -t '#' -v -W 10", "MQTT-RECON")
```

Then register the command in the help menu output at the bottom of the help block:

```python
# dronecoil.py  ~line 6070 (help block)
print("   \033[97mmqtt\033[0m      Quick MQTT topic dump")
```

---

## 11. Extending the GUI with a New Card Type

Cards live in `dronecoil_gui.py`. Each card is a `Gtk.Box` subclass.

### Step 1 — Create the card class

```python
# dronecoil_gui.py  ~line 800  (after existing card classes)
class MqttCard(Gtk.Box):
    def __init__(self, body: str):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        self.add_css_class("card")
        self.add_css_class("mqtt-card")        # for CSS styling

        title = Gtk.Label(label="📡 MQTT")
        title.add_css_class("card-title")
        self.append(title)

        content = _body_label(body)
        self.append(content)
```

### Step 2 — Register in `classify_panel_title()`

```python
# dronecoil_gui.py  ~line 856
def classify_panel_title(title: str) -> str:
    t = title.upper()
    # ... existing checks ...
    if "MQTT" in t:
        return "mqtt"
    return "plain"
```

### Step 3 — Route in `ConversationView._handle_panel()`

```python
# dronecoil_gui.py  ~line 951
def _handle_panel(self, title: str, body: str) -> Optional[str]:
    kind = classify_panel_title(title)
    # ... existing if/elif ...
    elif kind == "mqtt":
        self.append(MqttCard(body))
    # ...
```

### Step 4 — Add CSS for the card

```python
# dronecoil_gui.py  ~line 320  (inside load_css() CSS string)
CSS = """
/* ... existing ... */
.mqtt-card {
    background-color: alpha(@accent_bg_color, 0.08);
    border-left: 3px solid @accent_color;
}
"""
```

The GUI will now render a styled `MqttCard` whenever `dronecoil.py` emits a panel with title matching `MQTT`.
