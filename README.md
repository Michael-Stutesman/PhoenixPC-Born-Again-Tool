🛠️ PhoenixPC Born Again Tool – README
🛠 Created by: Michael Stutesman
Version: 1.0
Last Updated: [6/21/25]

--Click Through--Launch Trailer--

[![PhoenixPC Preview](https://github.com/Michael-Stutesman/PhoenixPC-Born-Again-Tool/raw/a8b1fe76b39a2a166b27b4f834c6568b599eca9e/PhoenixPC%20Preview.png)](https://github.com/Michael-Stutesman/PhoenixPC-Born-Again-Tool/blob/a8b1fe76b39a2a166b27b4f834c6568b599eca9e/PhoenixPC%20Preview.png)


---

🔍 What It Is

PhoenixPC Born Again is a lightweight Windows utility that helps you resolve common PC issues without needing* to restart your system. It offers a simple GUI to run essential repair and system optimization tasks — all in one place.
*May be prompted to restart after resetting drivers; only use when experiencing issues.


---

⚙️ Core Features

🧠 Flush DNS
Clears the DNS cache to fix connection and loading issues.

🌐 Restart Network Stack
Restarts core networking components to fix connection problems.

🗂️ Restart Windows Explorer
Fixes freezing, unresponsive taskbars, and desktop issues.

🧹 Clear Temporary Files
Frees disk space by deleting temp system/user files.

💾 Clear Standby Memory (Requires RAMMap)
Flushes cached memory that slows performance over time.

🧠 Optimize RAM Usage (Requires ReduceMemory)
Frees up RAM consumed by idle or background processes.

🔌 Reinitialize Device Drivers (Requires DevCon)
Uses DevCon to soft-restart selected hardware (e.g., audio, GPU, USB), helpful after driver crashes or resets.
➤ The entire GUI app auto-elevates to administrator privileges on launch to ensure all driver reset and system commands work seamlessly.

🕒 Repeat Task Timer
A built-in interval timer allows selected tasks to run repeatedly at user-defined intervals. This is useful for ongoing optimization or monitoring — for example, keeping RAM usage low during heavy multitasking or automatically flushing DNS every few minutes. The timer runs until manually stopped.

🗂️ Launch Task Manager
Toggle to instantly open/close the Task Manager from the app to help you monitor CPU, memory, disk, and network activity in real time. This is especially useful when troubleshooting slowdowns or verifying the effects of optimization tasks.

💾 Auto-Save Configuration
The app automatically saves your tool paths, settings, preferences and your location on screen — so everything is ready next time you launch.

⚠️ Minimize to Tray
Keeps the app running quietly in the system tray, hiding the main window and taskbar button for a clean desktop.


---

🖥️ System Requirements

Windows 10 or later (Works with both 32 and 64 bit operating systems)

PowerShell 5.1+

Administrator privileges (for full functionality)


Optional Tools:

RAMMap64.exe – for clearing standby memory

ReduceMemory_x64.exe – for optimizing RAM

devcon.exe – for resetting specific drivers without rebooting (Download via Windows Driver Kit - WDK)



---

✅ How to Use

1. Select Tasks
Use the checkboxes to choose any combination of fixes you want to run.


2. Set Tool Paths (Optional)
Provide paths for RAMMap, ReduceMemory, or DevCon executables.
These are saved in %LOCALAPPDATA%\Phoenix PC SoftReboot for future use — no need to re-enter them every time.


3. Click “Run Selected Tasks”
The utility executes selected tasks in order.


4. Review the Output Log
Real-time status updates will appear in the output box.


5. Use the Interval Timer (Optional)
To run selected tasks on repeat, enter a time interval in seconds and click “Run Timer.” Tasks will continue executing on a loop until you click “Stop Timer.”


6. Auto-Resume Friendly
The tool remembers your last-used screen position and saved settings, so it always launches where you left off — making future use quicker and more convenient.




---

📂 Generic Paths Entries

🧠 RAMMap64.exe
/path/to/RAMMap/RAMMap64.exe

🧠 ReduceMemory_x64.exe
/path/to/ReduceMemory/ReduceMemory/ReduceMemory_x64.exe

🛠️ DevCon.exe
C:/Program Files (x86)/Windows Kits/10/Tools/<version>/x64/devcon.exe

> You may need to manually append /x64/devcon.exe after the version number (e.g., 10.0.26100.0).




---

⚙️ DevCon Support

The DevCon command-line tool allows restarting specific hardware drivers without rebooting. You can use it to fix:

🔊 Audio issues
🖥️ GPU crashes
🧩 USB device failures
🌐 Network card resets

Use DevCon restart IDs like:

devcon restart *VEN_10DE*        # NVIDIA  
devcon restart *HDAUDIO*         # Audio  
devcon restart *USB*             # USB devices

⚠️ Only include compatible device filters. DevCon must be downloaded from Microsoft's official sources or the Windows Driver Kit (WDK).


---

💡 Tips

Admin privileges unlock the full power of the tool.

Tool paths are saved after the first time you set them.

The app remembers its position on your screen and your previously selected tools and inputs — no reconfiguration needed each time.

Great for users who need quick fixes between gaming, editing, or streaming sessions.

Pair with Task Manager for optimal system monitoring, troubleshooting, and ongoing optimization.


> To always launch with admin rights:
Right-click the desktop shortcut → Properties → Advanced → Check “Run as Administrator”.




---

📁 Files Included

PhoenixPC Born Again.exe — Main app launcher

PhoenixPC.ico — Application icon

README.txt — This file

Performance Enhancing Recommendations — Bonus file



---

🔒 Safety Notice

All actions performed are safe and rely on Windows native commands or trusted tools like RAMMap, ReduceMemory, and DevCon.
Ensure you only use trusted sources when downloading external tools.


---

📄 License

MIT License
Copyright (c) 2025 Michael Stutesman

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


---

⚖️ Disclaimer & Terms of Use

PhoenixPC Born Again is provided “as is,” without warranties or guarantees of any kind. By using this tool, you agree to do so at your own risk. The creator is not liable for any damage, data loss, or system issues resulting from its use.

This tool uses or references third-party utilities (RAMMap, ReduceMemory, DevCon). These must be downloaded separately and are owned by their respective developers. Please ensure you only obtain them from official or trusted sources.

Redistribution and modification are permitted under the MIT License. However, please credit the original creator when sharing or adapting this tool.

