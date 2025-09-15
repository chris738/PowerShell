# Group Policy Preferences für Laufwerkszuordnungen

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

## Automatisierte GPO-Erstellung

Für die Erstellung der GPOs steht das PowerShell-Skript `Setup-GPO-DriveMapping.ps1` zur Verfügung:

```powershell
# Alle GPOs erstellen
.\Setup-GPO-DriveMapping.ps1

# Mit spezifischer CSV-Datei
.\Setup-GPO-DriveMapping.ps1 -CsvFile "alternative-benutzer.csv"

# Als Teil des Gesamtprozesses
.\Run-All-Scripts.ps1
```

**Das Skript erstellt automatisch:**
- Eine globale GPO für G: Laufwerk (für alle Benutzer)
- Separate GPOs für T: Laufwerke (pro Abteilung)
- Registry-Einstellungen zur Deaktivierung der Taskbar-Suchleiste
- Verknüpfungen mit entsprechenden OUs

**Nach der Skript-Ausführung müssen Sie manuell:**
1. Group Policy Management Console (gpmc.msc) öffnen
2. Die erstellten GPOs bearbeiten
3. Drive Mapping Preferences konfigurieren (siehe Anweisungen oben)
4. Sicherheitsfilterung auf DL-Gruppen setzen

> **Hinweis:** Die eigentlichen Laufwerkszuordnungen können nicht vollständig über PowerShell konfiguriert werden und erfordern manuelle Konfiguration über Group Policy Preferences.