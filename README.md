<div align="center">

<img width="100%" src="https://capsule-render.vercel.app/api?type=waving&height=220&color=0:7928CA,100:FF0080&text=test_pbt_script_ol_pul&fontColor=ffffff&fontSize=46&fontAlignY=36&desc=One%20launcher.%20Every%20script.&descSize=20&descAlignY=58&animation=fadeIn" alt="test_pbt_script_ol_pul" />

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=20&duration=2800&pause=900&color=FF0080&center=true&vCenter=true&width=640&height=40&lines=Run+one+file.+It+pulls+the+repo.+%E2%9A%A1;Pick+a+script.+It+runs.+%F0%9F%9A%80;DNS+%E2%80%A2+network+%E2%80%A2+monitoring+%E2%80%A2+fresh+Windows+%F0%9F%93%A1" alt="Run one file, it pulls the repo. Pick a script, it runs. DNS, network, monitoring, fresh Windows." />

<br />

<img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows" />
<img src="https://img.shields.io/badge/Batch-CMD_%26_BAT-4EAA25?style=for-the-badge&logo=windowsterminal&logoColor=white" alt="Batch scripts: CMD and BAT" />
<img src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell" />
<img src="https://img.shields.io/badge/License-CC0_1.0-FF0080?style=for-the-badge" alt="License: CC0 1.0" />

</div>

## 🚀 Quick start

<div align="center">

[![Download the launcher](https://img.shields.io/badge/Download-__online__script1.cmd-FF0080?style=for-the-badge&logo=windowsterminal&logoColor=white)](https://github.com/xxPRABHATxx/extras/blob/main/_online_script1.cmd)

</div>

1. **Get the launcher**: press the button and use the download icon, or paste this in Command Prompt:

   ```bat
   $f="$env:TEMP\_online_script1.cmd"; irm "https://raw.githubusercontent.com/xxPRABHATxx/extras/main/_online_script1.cmd" -OutFile $f; & $f; Remove-Item $f -Force

   ```
   ```bat
   irm "https://raw.githubusercontent.com/xxPRABHATxx/extras/main/_online_script1.cmd" -OutFile "_online_script1.cmd"

   ```
2. **Double-click `_online_script1.cmd`.** It pulls this repo from GitHub automatically (the first run downloads and caches it).
3. **Type a number** to open a folder or run a script. Each script opens in its own window and the menu stays up.

> [!WARNING]
> The launcher runs whatever scripts are on the configured branch, and several change system or network settings. Read before running, and start the launcher with **Run as administrator** when a script needs it.

## ⚡ Scripts

| Script | What it does |
| --- | --- |
| 🎮 `_Valorant_Net_Kit.cmd` | Network kit for Valorant |
| 🛡️ `_auto_combined_dns_manager_failover.bat` | DNS manager with automatic failover |
| 🏓 `_ping_and_set_dns.cmd` | Ping DNS servers and set DNS |
| 📡 `connection_monitor_multi_opt.bat` | Connection monitor with multiple options |
| 🕸️ `scrape_ips_from_txt_or_website.cmd` | Scrape IPs from a text file or a website |
| 🖥️ `cmd_layout_changer/` | Command Prompt layout changer |
| 🕶️ `fake_hacker/` | "Fake hacker" terminal effect |
| 🧰 `updates&installs_4_fresh_windows/` | Updates and installs for a fresh Windows setup |

## 🧠 How it works

- 🔄 **Pulls once, caches it.** The repo is downloaded to `%TEMP%\GitHub-Script-Launcher`, so later runs start instantly and work offline.
- 📂 **Folders are categories.** Root scripts are listed as they are. Inside folders, only scripts named `run*` or `main*` are listed; the rest are helpers they can call.
- 🆕 **New scripts show up on their own.** There is no menu to edit. After pushing, quit with `0` then `1` to clear the cache and re-pull.
- 🧩 **Helpers just work.** Scripts start in their own folder, so files next to them can be called with relative paths.

<details>
<summary><b>⚙️ Settings and requirements</b></summary>

<br />

Edit the settings block at the top of `_online_script1.cmd`:

| Setting | Default | Purpose |
| --- | --- | --- |
| `GITHUB_REPO_URL` | `https://github.com/xxPRABHATxx/test_pbt_script_ol_pul` | Repository to pull (a public `github.com` link) |
| `GITHUB_BRANCH` | `uncompressed` | Branch to pull. Use `main` to pull this branch |
| `SHOW_CACHE_CLEAR_PROMPT` | `1` | `1` asks whether to clear the cache on quit; `0` keeps it silently |

Needs Windows PowerShell 5.0+ and internet on the first run. The repository must be public.

</details>

<div align="center">

📜 **[CC0 1.0](LICENSE)** · public domain · use it however you like

<img width="100%" src="https://capsule-render.vercel.app/api?type=waving&height=120&color=0:FF0080,100:7928CA&section=footer" alt="" />

</div>
