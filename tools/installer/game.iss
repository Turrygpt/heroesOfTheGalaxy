; Версия и пути передаются только из build_release.ps1.
#ifndef AppVersion
  #error Требуется запуск через tools/build_release.ps1
#endif
#if Edition == "Demo"
  #define ProductName "Heroes of the Galaxy — Демо"
  #define ProductId "HeroesOfTheGalaxyDemo"
#else
  #define ProductName "Heroes of the Galaxy"
  #define ProductId "HeroesOfTheGalaxy"
#endif

[Setup]
; Постоянный идентификатор позволяет обновлять ту же редакцию игры.
AppId={#ProductId}
AppName={#ProductName}
AppVersion={#AppVersion}
AppVerName={#ProductName} {#AppVersion}
VersionInfoVersion={#AppVersion}.0
VersionInfoProductVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\{#ProductId}
DefaultGroupName={#ProductName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#ProductId}-{#AppVersion}-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#ProductId}.exe
CloseApplications=yes
RestartApplications=no
SetupLogging=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; Flags: unchecked

[Files]
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#ProductName}"; Filename: "{app}\{#ProductId}.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\{#ProductName}"; Filename: "{app}\{#ProductId}.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#ProductId}.exe"; Description: "Запустить игру"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
