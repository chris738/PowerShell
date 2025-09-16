# XML-basierte GPO-Erstellung - Anleitung

## Übersicht

Diese Anleitung beschreibt die Verwendung der neuen XML-basierten PowerShell-Skripte zur Erstellung von drei Gruppenrichtlinienobjekten (GPOs):

1. **Globales Laufwerk einbinden** (G: Laufwerk für alle Benutzer)
2. **Abteilungslaufwerk einbinden** (T: Laufwerk mit Item-Level-Targeting)
3. **Suchleiste in der Taskbar deaktivieren** (Registry-basierte Konfiguration)

## Neue Skripte

| Skript | Zweck | Beschreibung |
|--------|--------|--------------|
| `Create-ThreeGPOs-XML.ps1` | **Hauptskript** | Erstellt die drei GPOs mit vollständiger XML-Konfiguration |
| `Link-ThreeGPOs-XML.ps1` | **Verknüpfungsskript** | Verknüpft die GPOs mit den entsprechenden OUs |

## Voraussetzungen

- Windows Server mit Active Directory
- PowerShell-Module: `ActiveDirectory`, `GroupPolicy`
- Ausreichende Berechtigungen für GPO-Erstellung und -Verknüpfung
- SYSVOL-Zugriff für XML-Datei-Erstellung

## Verwendung

### 1. GPOs erstellen

```powershell
# Basis-Verwendung mit Standard-Abteilungen
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$"

# Mit spezifischer CSV-Datei
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$" -CsvFile "meine-benutzer.csv"

# Mit benutzerdefinierten GPO-Namen
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$" -GlobalGpoName "Mein_G_Drive" -DepartmentGpoName "Mein_T_Drive" -SearchGpoName "Mein_Search_Disable"

# Test-Modus (WhatIf) - zeigt was passieren würde ohne Änderungen zu machen
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$" -WhatIf
```

### 2. GPOs verknüpfen

```powershell
# Standard-Verknüpfung mit allen OUs
.\Link-ThreeGPOs-XML.ps1

# Mit spezifischer CSV-Datei
.\Link-ThreeGPOs-XML.ps1 -CsvFile "meine-benutzer.csv"

# Test-Modus (WhatIf)
.\Link-ThreeGPOs-XML.ps1 -WhatIf
```

### 3. Alles in einem Durchgang

```powershell
# GPOs erstellen und verknüpfen
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$"
.\Link-ThreeGPOs-XML.ps1
```

## Erstellte GPO-Struktur

### GPO 1: Globales G: Laufwerk (`XML_Global_G_Drive`)

**Konfiguration:**
- **Laufwerk:** G:
- **Ziel:** Alle Benutzer in der Domain
- **Share-Pfad:** Wie im Parameter `-GlobalSharePath` angegeben
- **Verknüpfung:** Domain-Ebene
- **XML-Datei:** `User\Preferences\Drives\Drives.xml`

**XML-Struktur:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">
  <Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" name="G:" status="G:" image="2" changed="..." uid="...">
    <Properties action="U" thisDrive="NOCHANGE" allDrives="NOCHANGE" userName="" cpassword="" path="\\server\Global$" label="Global Share" persistent="1" useLetter="1" letter="G" />
  </Drive>
</Drives>
```

### GPO 2: Abteilungs-T: Laufwerk (`XML_Department_T_Drive`)

**Konfiguration:**
- **Laufwerk:** T:
- **Ziel:** Benutzer basierend auf Gruppenmitgliedschaft
- **Share-Pfad:** `\\server\Abteilungen$\{Abteilungsname}`
- **Item-Level-Targeting:** Gruppe `DL_{Abteilung}-FS_RW`
- **Verknüpfung:** Jede Abteilungs-OU
- **XML-Datei:** `User\Preferences\Drives\Drives.xml`

**XML-Struktur mit Item-Level-Targeting:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">
  <Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" name="T:" status="T:" image="2" changed="..." uid="...">
    <Properties action="U" thisDrive="NOCHANGE" allDrives="NOCHANGE" userName="" cpassword="" path="\\server\Abteilungen$\IT" label="Abteilung IT" persistent="1" useLetter="1" letter="T" />
    <Filters>
      <FilterGroup bool="AND" not="0" name="Abteilung IT" sid="" userContext="1" primaryToken="0" localGroup="0">
        <q:Query xmlns:q="http://www.microsoft.com/GroupPolicy/Settings/Base" clsid="{6AC7EEA7-EE10-4d05-8B80-396A7AA4F820}">
          <q:GroupMembership name="DL_IT-FS_RW" sid="" userContext="1" primaryToken="0" localGroup="0"/>
        </q:Query>
      </FilterGroup>
    </Filters>
  </Drive>
  <!-- Weitere Drive-Einträge für andere Abteilungen -->
</Drives>
```

### GPO 3: Taskbar-Suchleiste deaktiviert (`XML_Disable_Search_Bar`)

**Konfiguration:**
- **Ziel:** Alle Benutzer in der Domain
- **Registry-Pfad:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Search`
- **Verknüpfung:** Domain-Ebene
- **XML-Datei:** `User\Preferences\Registry\Registry.xml`

**Registry-Einstellungen:**
- `SearchBoxTaskbarMode = 0` (Suchbox ausblenden)
- `BingSearchEnabled = 0` (Bing-Suche deaktivieren)
- `CortanaConsent = 0` (Cortana deaktivieren)

**XML-Struktur:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<RegistrySettings clsid="{A3CCFC41-DFDB-43a5-8D26-0FE8B954DA51}">
  <Registry clsid="{9CD4B2F4-923D-47f5-A062-E897DD1DAD50}" name="SearchBoxTaskbarMode" status="SearchBoxTaskbarMode" image="1" changed="..." uid="...">
    <Properties action="U" displayDecimal="0" default="0" hive="CurrentUser" key="Software\Microsoft\Windows\CurrentVersion\Search" name="SearchBoxTaskbarMode" type="REG_DWORD" value="0" />
  </Registry>
  <!-- Weitere Registry-Einträge -->
</RegistrySettings>
```

## Funktionsweise der XML-basierten Lösung

### Vorteile gegenüber Registry-basierter Konfiguration

1. **Standardkonform:** Verwendet Group Policy Preferences XML-Format
2. **SYSVOL-Integration:** XML-Dateien werden automatisch repliziert
3. **Item-Level-Targeting:** Ermöglicht granulare Zielgruppenadressierung
4. **Verwaltbarkeit:** Einfache Anpassung über Group Policy Management Console
5. **Robustheit:** Integrierte Fehlerbehandlung von Windows

### XML-Datei-Speicherorte

Die Skripte erstellen XML-Dateien in folgenden SYSVOL-Pfaden:

```
\\domain.local\SYSVOL\domain.local\Policies\{GPO-GUID}\User\Preferences\
├── Drives\
│   └── Drives.xml          # Laufwerkszuordnungen
└── Registry\
    └── Registry.xml        # Registry-Einstellungen
```

### Item-Level-Targeting

Das Abteilungs-GPO verwendet Item-Level-Targeting für gruppenbasierte Laufwerkszuordnungen:

- **Filterkriterium:** Mitgliedschaft in Gruppe `DL_{Abteilung}-FS_RW`
- **Logik:** Nur Benutzer in der entsprechenden Gruppe erhalten das T: Laufwerk
- **Flexibilität:** Einfache Anpassung der Gruppenmitgliedschaften

## Integration mit bestehenden Skripten

Die neuen XML-basierten Skripte ergänzen die bestehende Infrastruktur:

### Verwendung mit dem Master-Skript

```powershell
# Erweitere Run-All-Scripts.ps1 um die neuen GPOs
.\Run-All-Scripts.ps1
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\$serverName\Global$"
.\Link-ThreeGPOs-XML.ps1
```

### CSV-Integration

Die Skripte nutzen die gleiche CSV-Datei wie die bestehenden Skripte:

```csv
Vorname;Nachname;Abteilung;E-Mail
Max;Mustermann;IT;max.mustermann@firma.local
Jana;Schmidt;Verwaltung;jana.schmidt@firma.local
```

## Fehlerbehandlung und Debugging

### WhatIf-Modus

Testen Sie die Skripte immer zuerst mit dem `-WhatIf` Parameter:

```powershell
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$" -WhatIf
.\Link-ThreeGPOs-XML.ps1 -WhatIf
```

### Überprüfung der XML-Dateien

Kontrollieren Sie die erstellten XML-Dateien:

```powershell
# XML-Inhalt anzeigen
Get-Content "\\domain.local\SYSVOL\domain.local\Policies\{GPO-GUID}\User\Preferences\Drives\Drives.xml"

# XML-Struktur validieren
[xml]$xml = Get-Content "\\domain.local\SYSVOL\domain.local\Policies\{GPO-GUID}\User\Preferences\Drives\Drives.xml"
$xml.Drives.Drive | Format-Table name, @{n='Path';e={$_.Properties.path}}, @{n='Label';e={$_.Properties.label}}
```

### Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| XML-Datei nicht erstellt | SYSVOL-Berechtigung fehlt | Benutzerrechte prüfen |
| GPO-Verknüpfung fehlgeschlagen | OU existiert nicht | OU-Struktur überprüfen |
| Laufwerk nicht zugeordnet | Gruppenmitgliedschaft | Item-Level-Targeting prüfen |
| Registry nicht angewendet | GPO nicht verknüpft | GPO-Verknüpfung kontrollieren |

### Group Policy Logs

Überwachen Sie die Group Policy-Anwendung:

```powershell
# Group Policy Resultant Set of Policy
gpresult /r /user %username%

# Detaillierte HTML-Ausgabe
gpresult /h gp-report.html /user %username%

# Event Logs prüfen
Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" | Where-Object {$_.Id -eq 4016}
```

## Wartung und Updates

### GPO-Aktualisierung

```powershell
# Neue Abteilung hinzufügen
$newDept = "Marketing"
$newSharePath = "\\server\Abteilungen$\$newDept"

# XML für neue Abteilung erstellen (manuell oder Skript erweitern)
# GPO-Verknüpfung erstellen
New-GPLink -Name "XML_Department_T_Drive" -Target "OU=$newDept,DC=domain,DC=local"
```

### Sicherheitsfilterung anpassen

In der Group Policy Management Console:
1. GPO auswählen
2. Registerkarte "Delegierung"
3. Sicherheitsfilterung anpassen
4. Entsprechende AD-Gruppen hinzufügen/entfernen

## Migration von bestehenden GPOs

### Von Registry-basierten GPOs

1. Bestehende GPOs dokumentieren
2. XML-basierte GPOs parallel erstellen
3. Testbenutzer/-gruppen für Validierung verwenden
4. Schrittweise Migration durchführen
5. Alte GPOs deaktivieren/löschen

### Rollback-Strategie

```powershell
# GPOs deaktivieren (statt löschen)
Set-GPLink -Name "XML_Global_G_Drive" -Target "DC=domain,DC=local" -LinkEnabled No

# GPOs wieder aktivieren
Set-GPLink -Name "XML_Global_G_Drive" -Target "DC=domain,DC=local" -LinkEnabled Yes
```

## Best Practices

1. **Testen:** Immer mit `-WhatIf` Parameter testen
2. **Backup:** GPO-Backups vor Änderungen erstellen
3. **Dokumentation:** Änderungen in GPO-Kommentaren dokumentieren
4. **Monitoring:** Group Policy Logs überwachen
5. **Schrittweise Einführung:** Neue GPOs graduell ausrollen
6. **Sicherheitsfilterung:** Nur benötigte Gruppen/Benutzer einschließen

Diese XML-basierte Lösung bietet eine moderne, skalierbare und wartungsfreundliche Alternative zu traditionellen GPO-Konfigurationsmethoden.