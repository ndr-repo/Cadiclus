# Cadiclus
- My fork of tjnull's Cadiclus, with personal enhancements.
  - Originally presented at Wild West Hackin' Fest 2025, ["Powering Up Linux - Unleashing PowerShell for Penetration Testing and Red Teaming"](https://www.youtube.com/watch?v=XeqrwgXcWW8)

## Running from Windows Terminal
- If you want to add this to a native [Windows Terminal](https://ss64.com/nt/wt.html) profile, you can use the following command line 

```
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "Invoke-RestMethod -Method Get -Uri https://raw.githubusercontent.com/ndr-repo/Cadiclus/refs/heads/main/Cadiclus/cadiclus.ps1 | Invoke-Expression"
```
