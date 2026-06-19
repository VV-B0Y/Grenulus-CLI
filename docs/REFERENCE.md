# Athena Quick Reference

> Fast lookup tables for all agents, workflows, tools, REPL commands, and output tags.

---

## Specialist Agents

| Key | Icon | Name | Phase keywords | Primary tools |
|---|---|---|---|---|
| `strategist` | ♔ | STRATEGIST | (routing only) | — |
| `recon` | 🔍 | RECON SPECIALIST | `recon`, `enum` | nmap, rustscan, masscan, whatweb, searchsploit |
| `web` | 🕸 | WEB EXPLOITATION | `web`, `web_recon`, `web_exploit` | feroxbuster, nikto, nuclei, sqlmap, ffuf |
| `network` | 🌐 | NETWORK EXPLOITATION | `network`, `service_exploit` | crackmapexec/nxc, enum4linux, smbclient |
| `ad` | 🏰 | ACTIVE DIRECTORY | `ad`, `ad_recon`, `ad_exploit` | kerbrute, impacket-*, certipy, bloodhound |
| `linux_privesc` | 🐧 | LINUX PRIVESC | `linux_post`, `linux_privesc` | linpeas, GTFOBins, linux-exploit-suggester |
| `windows_privesc` | 🪟 | WINDOWS PRIVESC | `windows_post`, `windows_privesc` | winpeas, PrintSpoofer, GodPotato, wesng |
| `credential` | 🔑 | CREDENTIAL ATTACK | `credential`, `cred_attack`, `cracking` | hashcat, john, hydra, nxc |
| `exfil` | 📤 | EXFILTRATION | `exfil` | curl, nslookup, ping, msfvenom |
| `evasion` | 🥷 | EVASION | `evasion` | macchanger, nmap -T1 -f --mtu, decoys |
| `reporter` | 📋 | REPORTER | `report` | (prose generation only) |

---

## Built-In Workflows (23 total)

| # | Name | Description |
|---|---|---|
| 1 | Network Recon | ARP sweep → port scan → service detection → CVE correlation |
| 2 | Web Enumeration | Tech fingerprint → vuln scan → dir/vhost brute |
| 3 | Linux Post-Exploitation | Identity → sudo → SUID → cron → caps → cred hunt |
| 4 | Metasploit Exploit | Verify module → resource script → non-interactive run |
| 5 | SQL Injection Assessment | Manual probe → sqlmap → dump → cred reuse |
| 6 | Hash Cracking | Identify → cached check → wordlist → rules → mask |
| 7 | Password Spraying | Service enum → policy check → spray → reuse |
| 8 | Active Directory Recon & Attack | Anon enum → AS-REP → spray → Kerberoast → DCSync |
| 9 | Payload Generation & Listener | msfvenom payloads → handler resource script |
| 10 | Bluetooth Recon | Interface check → classic + LE scan → service browse |
| 11 | OSINT Profiling | whois → DNS → certs → harvester → subdomains |
| 12 | SSL/TLS Audit | sslscan → testssl → cipher review |
| 13 | DNS Enumeration | dnsrecon → zone transfer → fierce → resolver checks |
| 14 | SMB Attack Chain | ms17-010 check → enum → share → relay → SAM |
| 15 | API Security Testing | Discovery → params → auth bypass → IDOR → JWT |
| 16 | Linux Privilege Escalation | linpeas → GTFOBins → kernel → docker/lxd |
| 17 | Windows Privilege Escalation | winpeas → tokens → service ACL → AlwaysInstallElevated |
| 18 | Lateral Movement | PTH → wmiexec → DCSync → pivot tunnels |
| 19 | Container & Cloud Escape | Container detect → docker socket → metadata → IAM |
| 20 | IDS/IPS Evasion | MAC spoof → fragment → decoy → timing → source-port |
| 21 | Data Exfiltration | Channel test → HTTPS → DNS → ICMP fallbacks |
| 22 | Forensics & Evidence | Hash → strings → binwalk → volatility |
| 23 | Steganography | Metadata → strings → steghide → zsteg → binwalk |

---

## Structured Tools (TOOL_DISPATCH)

These are the tools the LLM can invoke with `[TOOL]name[/TOOL][ARGS]{...}[/ARGS]`.

| Tool name | Binary | Key args |
|---|---|---|
| `nmap` | `nmap` | `target`, `ports`, `top_ports`, `version`, `os_detect`, `scripts`, `stealth`, `timing` |
| `rustscan` | `rustscan` | `target`, `ports`, `batch_size`, `timeout` |
| `masscan` | `masscan` | `target`, `ports`, `rate`, `use_sudo`, `interface` |
| `gobuster_dir` | `gobuster` | `url`, `wordlist`, `extensions`, `threads` |
| `feroxbuster` | `feroxbuster` | `url`, `wordlist`, `extensions`, `depth`, `threads` |
| `gobuster_vhost` | `gobuster` | `url`, `wordlist`, `threads` |
| `ffuf` | `ffuf` | `url`, `wordlist`, `location` (`path`/`param`/`header`), `filter_size` |
| `whatweb` | `whatweb` | `url`, `aggression` (1-4) |
| `nikto` | `nikto` | `target` |
| `nuclei` | `nuclei` | `target`, `severity`, `templates` |
| `hydra` | `hydra` | `target`, `service`, `userlist`, `passlist`, `threads`, `timeout` |
| `sqlmap` | `sqlmap` | `url`, `batch`, `level`, `risk`, `dbs`, `dump`, `data`, `cookie` |
| `searchsploit` | `searchsploit` | `query`, `json_out` |
| `smbclient_list` | `smbclient` | `target`, `anonymous` |
| `crackmapexec` | `crackmapexec` / `nxc` | `protocol`, `target`, `username`, `password`, `hash`, `command` |
| `enum4linux` | `enum4linux` | `target` |
| `hashcat` | `hashcat` | `hash_file`, `mode`, `wordlist`, `rules`, `show_only` |
| `hashid` | `hashid` | `hash_or_file` |
| `curl_basic` | `curl` | `url`, `head_only`, `headers`, `data`, `method`, `follow_redirects` |
| `kerbrute_userenum` | `kerbrute` | `domain`, `dc_ip`, `wordlist` |
| `impacket_asreproast` | `impacket-GetNPUsers` | `domain`, `dc_ip`, `userfile` |
| `impacket_kerberoast` | `impacket-GetUserSPNs` | `domain`, `dc_ip`, `username`, `password` |
| `impacket_secretsdump` | `impacket-secretsdump` | `domain`, `user`, `password`, `target` |
| `msfvenom_payload` | `msfvenom` | `payload`, `lhost`, `lport`, `output_file`, `format` |
| `sslscan` | `sslscan` | `target` |
| `testssl` | `testssl.sh` | `target`, `severity` |
| `dnsrecon` | `dnsrecon` | `domain`, `dns_type` |
| `theharvester` | `theHarvester` | `domain`, `sources`, `limit` |

---

## LLM Output Tags

The LLM must emit its response using these XML-style tags. Athena's parser (`parse_specialist_response()`) extracts them:

| Tag | Required | Purpose |
|---|---|---|
| `[THOUGHT]…[/THOUGHT]` | ✅ Always | Reasoning, teaching note, CVE citations |
| `[CMD]…[/CMD]` | One of CMD or TOOL | Raw shell command (for ad-hoc commands) |
| `[TOOL]…[/TOOL]` + `[ARGS]…[/ARGS]` | One of CMD or TOOL | Structured tool dispatch (preferred) |
| `[CONF]green\|yellow\|red[/CONF]` | ✅ Always | Confidence level |
| `[HANDOFF]<agent>[/HANDOFF]` | Optional | Hand off to another specialist agent |
| `[NEED]target[/NEED]` | Optional | Request more context (ptt/history/findings/graph/tools/kb N) |
| `[VERIFY]…[/VERIFY]` | Optional | Command to verify a finding |
| `[MANUAL]…[/MANUAL]` | Optional | Human-required steps (interactive shell, browser, etc.) |
| `WORKFLOW_COMPLETE` | Optional | Signal that the current PTT node is complete (in `[CMD]` body) |

---

## REPL Commands

| Command | Action |
|---|---|
| `workflow` | Open the 23-workflow menu |
| `workflow list` | Show all workflows with keys and descriptions |
| `workflow add` | Interactively add a new workflow (session-only) |
| `workflow edit <key>` | Edit name/description of an existing workflow |
| `target` | Set or update the engagement target |
| `findings` | Show all extracted findings (verified + unverified) |
| `tree` | Render the Pentesting Task Tree |
| `graph` | Show attack graph + pivot suggestions |
| `scope` | Show / toggle engagement scope (RoE) |
| `mitre` | MITRE ATT&CK techniques used this session |
| `tools` | Tool availability check + auto-install missing |
| `model` | Show Groq provider chain status |
| `model list` | Alias for `model` |
| `model set <n>` | Force-set active model to position n (1-indexed) |
| `agent` | List all specialist agents |
| `agent edit <key>` | Edit persona/extra_rules of an agent (session-only) |
| `prompt show` | Preview the system prompt for the next LLM call |
| `dashboard` | Concise session status panel |
| `save` | Save conversation to file |
| `report` | Generate the engagement report now |
| `clear` | Clear AI memory (PTT preserved) |
| `reset` | Full reset (PTT + findings + history + sudo cache) |
| `help` | Help menu |
| `exit` / `q` | End session and generate report |

---

## Finding Types

| Type key | What it captures | Example |
|---|---|---|
| `ip` | IPv4 address | `10.0.0.5` |
| `port` | Open TCP/UDP port number | `22` |
| `svc` | Service + version string | `OpenSSH 8.2p1` |
| `user` | Username from tool output | `administrator` |
| `hash_ntlm` | LM:NTLM hash pair | `aad3b...:31d6c...` |
| `hash` | Generic hex hash (32-64 chars) | `5f4dcc3b5...` |
| `krb_hash` | Kerberos AS-REP or TGS-REP hash | `$krb5asrep$23$user@...` |
| `ntlmv2` | NetNTLMv2 hash | `user::DOM:...` |
| `cve` | CVE identifier | `CVE-2021-4034` |
| `domain` | Domain name | `corp.local` |
| `url` | HTTP/HTTPS URL | `https://corp.local/admin` |
| `cred` | Password from labeled field | `password: toor` |
| `smb_share` | UNC share path | `\\10.0.0.5\ADMIN$` |
| `email` | Email address | `admin@corp.com` |
| `ssh_key` | SSH private key header | `-----BEGIN RSA PRIVATE KEY-----` |
| `aws_key` | AWS access key ID | `AKIAIOSFODNN7EXAMPLE` |

---

## Key File Locations

| Path | Description |
|---|---|
| `athena.py` | Main engine (agents, tools, workflows, prompts, session logic) |
| `athena_gui.py` | GTK4 GUI shell |
| `~/.athena/scope.json` | Engagement scope / RoE (edit between sessions) |
| `~/.athena/logs/session_*.txt` | Per-session logs (ANSI stripped) |
| `~/.athena/` | Runtime data root |
| `/tmp/athena_session.lock` | Boot-check cache (6h TTL, delete to force re-check) |

---

## Groq Provider Chain (default order)

| # | Model ID | Friendly name |
|---|---|---|
| 1 | `llama-3.1-8b-instant` | LLaMA 3.1 8B ← starts here |
| 2 | `gemma2-9b-it` | Gemma 2 9B |
| 3 | `meta-llama/llama-4-scout-17b-16e-instruct` | LLaMA 4 Scout 17B |
| 4 | `qwen/qwen3-32b` | Qwen3 32B |
| 5 | `llama-3.3-70b-versatile` | LLaMA 3.3 70B |
| 6 | `deepseek-r1-distill-llama-70b` | DeepSeek R1 70B |
| 7 | `compound-beta-mini` | Compound Beta Mini |
| 8 | `compound-beta` | Compound Beta ← last resort |

---

## PTT Node Status Lifecycle

```
todo → in_progress → done
                   ↘ dead_end   (NODE_ATTEMPT_LIMIT reached with no findings)
```

## Confidence Levels

| Colour | Meaning | Effect on context |
|---|---|---|
| `green` | High confidence, direct attack | Minimal context (3 history turns) |
| `yellow` | Uncertain, proposes pivot | Expanded context (6 history turns + PTT + graph) |
| `red` | Needs more info before any command | Expanded context (6 history turns + PTT + graph) |

## Command Timeout Defaults

| Tool pattern | Timeout |
|---|---|
| `nmap -p 1-65535` / `nmap -p-` | 600 s |
| `masscan` / `rustscan` | 300 s |
| `nmap --top-ports` | 90 s |
| `nmap` (generic) | 180 s |
| `hydra` / `medusa` / `patator` | 1800 s |
| `hashcat` / `john` | 3600 s |
| `gobuster` / `feroxbuster` / `ffuf` | 600 s |
| `nikto` / `nuclei` / `wpscan` | 900 s |
| `sqlmap` | 900 s |
| `theharvester` / `amass` | 600 s |
| `searchsploit` | 30 s |
| `curl` | 45 s |
| `arp-scan` | 60 s |
| `ping` | 20 s |
| Everything else | 300 s |
