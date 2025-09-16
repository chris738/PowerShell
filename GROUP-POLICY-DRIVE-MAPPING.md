# Group Policy Preferences für Laufwerkszuordnungen

## 🚀 NEUE VERSION 2.0 - VERBESSERTE IMPLEMENTIERUNG

**WICHTIGE VERBESSERUNG:** Das `Setup-GPO-DriveMapping.ps1` Skript wurde vollständig überarbeitet und kombiniert jetzt die bewährten Ansätze von `create_gpos.ps1` und `link_gpos.ps1` für eine optimale GPO-Verwaltung.

### ✨ Was ist neu in Version 2.0:
- **Drei separate GPOs** statt einer GPO pro Abteilung
- **XML-basierte Drive Mappings** (Group Policy Preferences Standard)
- **Automatische GPO-Verknüpfung** mit intelligenter OU-Erkennung
- **Item-Level-Targeting** für gruppenbasierte Laufwerkszuordnungen
- **Modulare Architektur** basierend auf bewährten Skripten
- **Erweiterte Fehlerbehandlung** und detaillierte Statusberichte

---

## Übersicht

Diese Anleitung ersetzt die benutzer-spezifischen Logon-Scripts für G: und S: Laufwerkszuordnungen durch Group Policy Preferences - eine moderne, zentrale Verwaltungslösung.

## Vorteile von Group Policy Preferences

- **Zentrale Verwaltung**: Keine individuellen Skripte pro Benutzer
- **Automatische Anwendung**: Basierend auf Benutzer- oder Computermitgliedschaften
- **Einfache Wartung**: Änderungen wirken sich sofort auf alle betroffenen Benutzer aus
- **Keine Script-Dateien**: Reduziert Dateisystem-Overhead und Sicherheitsrisiken
- **Integrierte Fehlerbehandlung**: Robuste Behandlung von Netzwerkproblemen

## Konfiguration

### 1. Group Policy Management Console öffnen

1. Öffnen Sie die **Group Policy Management Console** (gpmc.msc)
2. Navigieren Sie zu Ihrer Domäne
3. Erstellen Sie eine neue GPO oder bearbeiten Sie eine bestehende

### 2. Laufwerkszuordnungen konfigurieren

Navigieren Sie zu:
```
Computerkonfiguration → Einstellungen → Windows-Einstellungen → Laufwerkszuordnungen
```

### 3. Globales Laufwerk (G:) konfigurieren

**Neue Laufwerkszuordnung erstellen:**

| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Global$` |
| **Als** | `G:` |
| **Beschriftung** | `Global` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |
| **Alle Benutzer** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `Authentifizierte Benutzer`
- **Berechtigung**: `Lesen und Anwenden`

### 4. Abteilungslaufwerk (S:) konfigurieren

Für jede Abteilung eine separate Laufwerkszuordnung erstellen:

#### Geschäftsführung
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\Geschäftsführung` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung Geschäftsführung` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_Geschäftsführung-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

#### Bar
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\Bar` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung Bar` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_Bar-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

#### Events
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\Events` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung Events` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_Events-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

#### Shop
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\Shop` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung Shop` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_Shop-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

#### Verwaltung
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\Verwaltung` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung Verwaltung` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_Verwaltung-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

#### EDV
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\EDV` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung EDV` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_EDV-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

#### Facility
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\Facility` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung Facility` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_Facility-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

#### Gast
| Einstellung | Wert |
|-------------|------|
| **Aktion** | Ersetzen |
| **Speicherort** | `\\%LOGONSERVER%\Abteilungen$\Gast` |
| **Als** | `S:` |
| **Beschriftung** | `Abteilung Gast` |
| **Verbindung wiederherstellen** | ✅ Aktiviert |

**Sicherheitsfilterung:**
- **Anwenden auf**: `DL_Gast-FS_RW`
- **Berechtigung**: `Lesen und Anwenden`

## 5. GPO verknüpfen und testen

1. **GPO verknüpfen**: Verknüpfen Sie die GPO mit der entsprechenden Organisationseinheit
2. **Sofortige Anwendung**: `gpupdate /force` auf Client-Computern ausführen
3. **Testen**: Nach Neuanmeldung sollten G: und S: Laufwerke automatisch verfügbar sein

## Überwachung und Fehlerbehebung

### Event Logs prüfen
```
Windows Logs → System
Windows Logs → Application
Applications and Services Logs → Group Policy Operational
```

### Group Policy Results
```powershell
# GPO-Anwendung prüfen
gpresult /r

# Detaillierte Analyse
gpresult /h gp-report.html
```

### Häufige Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| Laufwerk wird nicht zugeordnet | Sicherheitsfilterung falsch | Gruppenmitgliedschaft prüfen |
| Zugriff verweigert | Berechtigungen fehlen | NTFS-Rechte auf Fileserver prüfen |
| Laufwerk verschwindet | Netzwerkproblem | Verbindung zum Server prüfen |

## Migration von Logon-Scripts

Die PowerShell-Skripte haben bereits folgende Schritte durchgeführt:

1. ✅ **Benutzer-spezifische Logon-Scripts entfernt**
2. ✅ **ScriptPath in AD auf null gesetzt**  
3. ✅ **Scripts-Verzeichnis und Share entfernt**
4. ✅ **H: Laufwerk weiterhin funktional über AD HomeDirectory**

Nach Implementierung der Group Policy Preferences sollten G: und S: Laufwerke automatisch für alle Benutzer verfügbar sein.

## Vorteile der neuen Lösung

| Aspekt | Vorher (Logon-Scripts) | Nachher (Group Policy) |
|--------|------------------------|------------------------|
| **Verwaltung** | 30+ individuelle Script-Dateien | Zentrale GPO-Konfiguration |
| **Performance** | Script-Ausführung bei jedem Login | Einmalige GPO-Anwendung |
| **Sicherheit** | Script-Dateien auf Fileserver | Integriert in AD-Sicherheitsmodell |
| **Wartung** | Manuelle Datei-Updates | Automatische GPO-Verteilung |
| **Fehlerbehandlung** | Begrenzt durch Script-Logik | Erweiterte GPO-Mechanismen |
| **Skalierbarkeit** | Lineare Zunahme der Dateien | Konstante Komplexität |

Diese moderne Lösung bietet bessere Verwaltbarkeit, höhere Sicherheit und einfachere Wartung.

## Automatisierte GPO-Erstellung (VERBESSERT)

Für die Erstellung der GPOs steht das **verbesserte** PowerShell-Skript `Setup-GPO-DriveMapping.ps1` zur Verfügung, das nun die modularen Ansätze von `create_gpos.ps1` und `link_gpos.ps1` kombiniert:

```powershell
# Alle GPOs erstellen und verknüpfen (neue verbesserte Version)
.\Setup-GPO-DriveMapping.ps1

# Mit spezifischer CSV-Datei
.\Setup-GPO-DriveMapping.ps1 -CsvFile "alternative-benutzer.csv"

# Mit benutzerdefinierten GPO-Namen
.\Setup-GPO-DriveMapping.ps1 -GlobalGpoName "Custom_G_Drive" -DepartmentGpoName "Custom_T_Drive" -SearchGpoName "Custom_Search_Disable"

# Als Teil des Gesamtprozesses
.\Run-All-Scripts.ps1
```

### NEUE FUNKTIONEN (Version 2.0):

**Das verbesserte Skript erstellt automatisch:**
- ✅ **Drei separate GPOs** (statt einer kombinierten)
  - Globales G: Laufwerk GPO (`Map_G_Drive`)
  - Abteilungs-T: Laufwerk GPO (`Map_T_Drive`) mit Item-Level-Targeting
  - Taskbar-Suchleiste GPO (`Disable_Search_Bar`)
- ✅ **XML-basierte Drive Mappings** (Group Policy Preferences Standard)
- ✅ **Item-Level-Targeting** für abteilungsspezifische Laufwerke
- ✅ **Automatische GPO-Verknüpfungen** mit entsprechenden OUs
- ✅ **Erweiterte Fehlerbehandlung** und Statusberichte
- ✅ **CSV-gesteuerte Abteilungserkennung**

### TECHNISCHE VERBESSERUNGEN:

| Bereich | Vorher | Nachher (Version 2.0) |
|---------|---------|----------------------|
| **GPO-Struktur** | Eine GPO pro Abteilung | Drei zentrale GPOs |
| **Drive Mapping** | Registry-basiert | XML-basierte Preferences |
| **Targeting** | OU-basiert | Gruppenbasiert (Item-Level) |
| **Verknüpfung** | Manuell pro OU | Automatisch optimiert |
| **Verwaltung** | Multiple GPOs | Drei konfigurierbare GPOs |
| **Skalierbarkeit** | Linear wachsend | Konstant (3 GPOs) |

### MODULARE ARCHITEKTUR:

Das neue Skript basiert auf den bewährten Modulen:
- **`create_gpos.ps1`**: XML-Erstellung und GPO-Management
- **`link_gpos.ps1`**: Automatisierte GPO-Verknüpfung
- **`Common-Functions.ps1`**: CSV-Integration und Hilfsfunktionen

**Nach der Skript-Ausführung (Version 2.0):**
1. ✅ **Drei GPOs automatisch erstellt und verknüpft**
2. ✅ **XML-basierte Drive Mappings konfiguriert**
3. ✅ **Item-Level-Targeting für Abteilungsgruppen**
4. ✅ **Suchleiste-Registry komplett konfiguriert**

**Optionale manuelle Anpassungen:**
1. Group Policy Management Console (gpmc.msc) öffnen
2. Sicherheitsfilterung für Department-GPO verfeinern
3. Zusätzliche Drive Mapping Preferences hinzufügen
4. WMI-Filter für erweiterte Zielgruppenadressierung

> **Hinweis:** Die neue Version 2.0 bietet eine vollständig automatisierte Lösung, die nur minimale manuelle Nachbearbeitung erfordert.