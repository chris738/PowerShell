# PowerShell Scripts für Active Directory Setup

Diese PowerShell-Skripte automatisieren die Einrichtung von Active Directory Benutzern, Gruppen und Fileserver-Strukturen basierend auf einer CSV-Datei.

## Neue Features

**CSV-gesteuert**: Alle Skripte lesen Abteilungen automatisch aus der CSV-Datei  
**Keine manuellen Anpassungen**: Skripte müssen nicht mehr für verschiedene Abteilungen angepasst werden  
**Zentrale Konfiguration**: Eine CSV-Datei steuert alle Skripte  
**Master-Skript**: Führt alle Skripte mit einer CSV-Datei aus  

## 📋 CSV-Format

Die CSV-Datei muss folgende Spalten enthalten (Trennzeichen: Semikolon):
```
Vorname;Nachname;Abteilung;E-Mail
```

Beispiel siehe: `Userlist-EchtHamburg.csv`

## Verwendung

### Einzelne Skripte ausführen
```powershell
# Mit Standard-CSV (Userlist-EchtHamburg.csv)
.\Create-Users.ps1
.\Setup-Groups.ps1
.\Setup-GG-Membership.ps1

# Mit benutzerdefinierter CSV
.\Create-Users.ps1 -CsvFile "C:\path\to\users.csv"
.\Setup-Groups.ps1 -CsvFile "C:\path\to\users.csv"
```

### Alle Skripte auf einmal ausführen
```powershell
# Führt alle Skripte in der richtigen Reihenfolge aus
.\Run-All-Scripts.ps1

# Mit benutzerdefinierter CSV
.\Run-All-Scripts.ps1 -CsvFile "C:\path\to\users.csv"

# Einzelne Schritte überspringen
.\Run-All-Scripts.ps1 -SkipUsers -SkipHomeFolders -SkipNetworkShares -SkipGPO -SkipSharePermissions
```

## Skripte

| Skript | Beschreibung | CSV-gesteuert |
|--------|-------------|---------------|
| `Create-Users.ps1` | Erstellt AD-Benutzer | Ja |
| `Setup-Groups.ps1` | Erstellt Gruppen pro Abteilung | Ja |
| `Setup-GG-Membership.ps1` | Fügt Benutzer in Gruppen hinzu | Ja |
| `Create-HomeFolders.ps1` | Erstellt Home-Verzeichnisse | Ja |
| `Setup-Fileserver.ps1` | Erstellt Fileserver-Struktur | Ja |
| `Setup-NetworkShares.ps1` | **NEU** - Erstellt Netzwerkfreigaben (SMB Shares) | Ja |
| `Setup-Fileserver-Rights.ps1` | Setzt Fileserver-Berechtigungen | Ja |
| `Setup-GPO-DriveMapping.ps1` | **NEU** - Erstellt GPOs für Laufwerkszuordnungen | Ja |
| `Setup-SharePermissions.ps1` | **NEU** - Konfiguriert Share-Berechtigungen | Ja |
| `Create-ThreeGPOs-XML.ps1` | **NEUE XML-LÖSUNG** - Erstellt drei GPOs via XML | Ja |
| `Link-ThreeGPOs-XML.ps1` | **NEUE XML-LÖSUNG** - Verknüpft XML-basierte GPOs | Ja |
| `Complete-GPO-Setup-XML.ps1` | **NEUE XML-LÖSUNG** - Vollständiges XML-GPO-Setup | Ja |
| `Run-All-Scripts.ps1` | **Master-Skript** - führt alle aus | Ja |
| `Common-Functions.ps1` | Gemeinsame Funktionen | - |
| `Test-Scripts.ps1` | Testet alle Skripte | - |
| `Test-DriveMapping.ps1` | Testet Laufwerkskonfiguration | - |
| `Test-SamAccountChanges.ps1` | Demonstriert SAM Account Änderungen | - |
| `Test-NetworkShares.ps1` | **NEU** - Testet Netzwerkfreigaben-Setup | - |

## Laufwerkszuordnungen

Die Skripte erstellen folgende Laufwerkskonfiguration:

| Laufwerk | Pfad | Beschreibung | Konfiguration |
|----------|------|--------------|---------------|
| **H:** | `\\server\Home$\Vorname.Nachname` | Persönliches Home-Verzeichnis | Automatisch über AD HomeDirectory |
| **G:** | `\\server\Global$` | Globales Verzeichnis (alle Benutzer) | **Group Policy Preferences empfohlen** |
| **T:** | `\\server\Abteilungen$\{Abteilung}` | Abteilungsverzeichnis | **Group Policy Preferences empfohlen** |

**SAM Account Format**: `vorname.nachname` (z.B. `jan.janssen`)  
**Server-Erkennung**: Automatische Domain Controller Erkennung mit Fallback

**Wichtiger Hinweis**: Benutzer-spezifische Logon-Scripts wurden entfernt. Das H: Laufwerk wird automatisch über die AD HomeDirectory Eigenschaft zugeordnet. Für G: und T: Laufwerke wird die Verwendung von Group Policy Preferences empfohlen.

## Group Policy Laufwerkszuordnung

Das neue `Setup-GPO-DriveMapping.ps1` Skript automatisiert die Erstellung von Group Policy Objekten für Laufwerkszuordnungen:

| Laufwerk | Verwendung | GPO-Scope | Zusätzliche Features |
|----------|------------|-----------|----------------------|
| **G:** | Globales Verzeichnis | Domain-weit | Taskbar-Suchleiste deaktiviert |
| **T:** | Abteilungsverzeichnisse | Pro OU/Abteilung | Taskbar-Suchleiste deaktiviert |

**Das Skript erstellt:**
- GPO-Grundstruktur mit Registry-Einstellungen
- Automatische OU-Verknüpfungen
- Deaktivierung der Windows Taskbar-Suchleiste

**Manuelle Nachbearbeitung erforderlich:**
Nach der Skript-Ausführung müssen die Drive Mapping Preferences manuell über die Group Policy Management Console konfiguriert werden. Detaillierte Anweisungen finden Sie in `GROUP-POLICY-DRIVE-MAPPING.md`.

## Netzwerkfreigaben

Das neue `Setup-NetworkShares.ps1` Skript erstellt automatisch folgende SMB-Netzwerkfreigaben:

| Freigabe | Pfad | Beschreibung | Berechtigungen |
|----------|------|--------------|---------------|
| **Home$** | `F:\Shares\Home` | Home-Verzeichnisse | Authenticated Users (Change) |
| **Global$** | `F:\Shares\Global` | Globales Verzeichnis | DL_Global-FS_RW (Change) |
| **Abteilungen$** | `F:\Shares\Abteilungen` | Abteilungsverzeichnisse | DL_{Abteilung}-FS_RW (Change) |
| **Scripts$** | `F:\Shares\Scripts` | Logon-Scripts | Authenticated Users (Read) |

**Hinweis**: Dieses Skript funktioniert nur auf Windows Servern mit SMB-Features.

## Share-Berechtigungen

Das neue `Setup-SharePermissions.ps1` Skript konfiguriert automatisch die SMB-Share-Berechtigungen:

| Share | Gruppe | Berechtigung | Zweck |
|-------|--------|--------------|-------|
| **Global$** | DL_Global-FS_RW | Full | Vollzugriff für alle Benutzer |
| **Global$** | DL_Global-FS_R | Read | Lesezugriff für alle Benutzer |
| **Abteilungen$** | DL_{Abteilung}-FS_RW | Full | Vollzugriff pro Abteilung |
| **Abteilungen$** | DL_{Abteilung}-FS_R | Read | Lesezugriff pro Abteilung |
| **Home$** | Authenticated Users | Change | Zugriff auf eigenes Home-Verzeichnis |

**Wichtig**: Diese Berechtigungen arbeiten zusammen mit NTFS-Berechtigungen. Beide Ebenen müssen korrekt konfiguriert sein für funktionierenden Zugriff.

### Deutsche Lokalisierung

Das Skript unterstützt sowohl deutsche als auch englische Windows Server:
- **Deutsche Server**: Verwendet lokalisierte Kontennamen wie "Jeder" und "Authentifizierte Benutzer"
- **Englische Server**: Verwendet Standard-Kontennamen wie "Everyone" und "Authenticated Users"
- **Automatischer Fallback**: Bei Problemen mit der Namensauflösung werden SIDs verwendet

Dies behebt den Fehler "*Zuordnungen von Kontennamen und Sicherheitskennungen wurden nicht durchgeführt*" auf deutschen Windows Servern.

## Testen

```powershell
# Teste alle Skripte und CSV-Integration
.\Test-Scripts.ps1
```

## Automatische Abteilungserkennung

Die Skripte erkennen automatisch alle eindeutigen Abteilungen aus der CSV-Datei:
- **Aktuell erkannt**: Geschäftsführung, Bar, Events, Shop, Verwaltung, EDV, Facility, Gast
- **Früher fest codiert**: IT, Events, Facility, Vorstand, Shop, Verwaltung, Gast

Diese XML-basierte Lösung bietet eine moderne, skalierbare und wartungsfreundliche Alternative zu traditionellen GPO-Konfigurationsmethoden.

## XML-basierte GPO-Erstellung (NEUE LÖSUNG)

Für eine moderne, XML-basierte GPO-Verwaltung stehen drei neue Skripte zur Verfügung:

### Grundlegende Verwendung
```powershell
# Erstellt drei GPOs via XML (Global G:, Abteilungs-T:, Suchleiste deaktiviert)
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$"

# Verknüpft die GPOs automatisch mit den entsprechenden OUs
.\Link-ThreeGPOs-XML.ps1

# Vollständiges Setup in einem Durchgang
.\Complete-GPO-Setup-XML.ps1 -GlobalSharePath "\\server\Global$"

# Test-Modus (WhatIf) - zeigt Änderungen an ohne sie durchzuführen
.\Create-ThreeGPOs-XML.ps1 -GlobalSharePath "\\server\Global$" -WhatIf
```

### Eigenschaften der XML-Lösung
- **Drei separate GPOs:** `XML_Global_G_Drive`, `XML_Department_T_Drive`, `XML_Disable_Search_Bar`
- **Group Policy Preferences:** Standard-XML-Format für optimale Kompatibilität
- **Item-Level-Targeting:** Gruppenbasierte Laufwerkszuordnung für Abteilungen
- **Automatische SYSVOL-Integration:** XML-Dateien werden korrekt platziert
- **CSV-gesteuert:** Nutzt die gleiche CSV-Datei wie bestehende Skripte

### Detaillierte Dokumentation
Siehe `XML-GPO-CREATION-GUIDE.md` für umfassende Anweisungen, Beispiele und Troubleshooting.

Keine manuellen Anpassungen der Skripte mehr nötig!