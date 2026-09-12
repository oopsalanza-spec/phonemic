; PhoneMic PC Installer
; Bundles: VB-Audio Virtual Cable driver + PhoneMic receiver.exe
; Result: a single Setup.exe. The user just double-clicks it, clicks Next a
; few times, and everything (driver + app + startup shortcut) is installed.
; No command line needed by the end user.

#define MyAppName "PhoneMic"
#define MyAppVersion "1.0"
#define MyAppPublisher "PhoneMic"

[Setup]
AppId={{B6F4B6B0-6E1B-4C77-9B36-PHONEMIC0001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\PhoneMic
DefaultGroupName=PhoneMic
DisableProgramGroupPage=yes
OutputDir=dist_installer
OutputBaseFilename=PhoneMic-Setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
WizardStyle=modern

[Files]
; The compiled receiver (built by PyInstaller in CI before this runs)
Source: "build\receiver.exe"; DestDir: "{app}"; Flags: ignoreversion
; The VB-Cable driver installer, downloaded during CI build
Source: "build\VBCABLE_Setup_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\PhoneMic Receiver"; Filename: "{app}\receiver.exe"
Name: "{group}\Uninstall PhoneMic"; Filename: "{uninstallexe}"
Name: "{userstartup}\PhoneMic Receiver"; Filename: "{app}\receiver.exe"; Tasks: autostart

[Tasks]
Name: "autostart"; Description: "Start PhoneMic Receiver automatically when Windows starts"; GroupDescription: "Startup:"

[Run]
; Silently install the VB-Cable virtual audio driver first
Filename: "{tmp}\VBCABLE_Setup_x64.exe"; Parameters: "-i -h"; StatusMsg: "Installing virtual microphone driver..."; Flags: waituntilterminated
; Then launch the receiver right after setup finishes
Filename: "{app}\receiver.exe"; Description: "Launch PhoneMic Receiver now"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "{tmp}\VBCABLE_Setup_x64.exe"; Parameters: "-u -h"; RunOnceId: "RemoveCable"
