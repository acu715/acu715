' Double-click this. It starts the launcher .bat with no console window.
'
' A .bat cannot hide its own window, and nothing inside one can either: cmd.exe
' creates the window before the script's first line runs, and on Windows 11
' that window belongs to Windows Terminal, a separate process.  WScript.Shell.Run
' with a window style of 0 is what actually keeps it off screen, so the entry
' point has to be this file.
'
' The self-relaunch trick in the older scripts here (start mshta vbscript:...) no
' longer works: Windows 11 24H2+ drops the VBScript and JScript engines from
' mshta, so it exits 0 having done nothing and the script never runs.

Option Explicit

Dim fso, sh, here, bat, cmd

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

here = fso.GetParentFolderName(WScript.ScriptFullName)
bat  = fso.BuildPath(here, "XMR_Rig-XMR-Auto_Github-less_core_doubleclick.bat")

If Not fso.FileExists(bat) Then
    MsgBox "Missing:" & vbCrLf & bat, 16, "XMR_Rig"
    WScript.Quit 1
End If

' Doubled quotes: cmd strips the outer pair, leaving the path as one argument,
' which is what keeps a folder name with spaces from being split in two.
cmd = "cmd.exe /c " & Chr(34) & Chr(34) & bat & Chr(34) & Chr(34)

' 0 = hidden, False = do not wait for it to finish.
sh.Run cmd, 0, False
