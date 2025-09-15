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
.\Run-All-Scripts.ps1 -SkipUsers -SkipHomeFolders
```

## Skripte

| Skript | Beschreibung | CSV-gesteuert |
|--------|-------------|---------------|
| `Create-Users.ps1` | Erstellt AD-Benutzer | Ja |
| `Setup-Groups.ps1` | Erstellt Gruppen pro Abteilung | Ja |
| `Setup-GG-Membership.ps1` | Fügt Benutzer in Gruppen hinzu | Ja |
| `Create-HomeFolders.ps1` | Erstellt Home-Verzeichnisse und Laufwerkszuordnungen | Ja |
| `Setup-Fileserver.ps1` | Erstellt Fileserver-Struktur | Ja |
| `Setup-Fileserver-Rights.ps1` | Setzt Fileserver-Berechtigungen | Ja |
| `Run-All-Scripts.ps1` | **Master-Skript** - führt alle aus | Ja |
| `Common-Functions.ps1` | Gemeinsame Funktionen | - |
| `Test-Scripts.ps1` | Testet alle Skripte | - |

## Laufwerkszuordnungen

Die Skripte erstellen automatisch folgende Laufwerkszuordnungen für jeden Benutzer:

| Laufwerk | Pfad | Beschreibung |
|----------|------|--------------|
| **H:** | `\\server\Home$\Vorname.Nachname` | Persönliches Home-Verzeichnis |
| **G:** | `\\server\Global$` | Globales Verzeichnis (alle Benutzer) |
| **S:** | `\\server\Abteilungen$\{Abteilung}` | Abteilungsverzeichnis |

Die Laufwerkszuordnungen werden über Logon-Scripts realisiert, die automatisch für jeden Benutzer erstellt werden.

## Testen

```powershell
# Teste alle Skripte und CSV-Integration
.\Test-Scripts.ps1
```

## Automatische Abteilungserkennung

Die Skripte erkennen automatisch alle eindeutigen Abteilungen aus der CSV-Datei:
- **Aktuell erkannt**: Geschäftsführung, Bar, Events, Shop, Verwaltung, EDV, Facility, Gast
- **Früher fest codiert**: IT, Events, Facility, Vorstand, Shop, Verwaltung, Gast

Keine manuellen Anpassungen der Skripte mehr nötig!