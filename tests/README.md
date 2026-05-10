# agent-coop V1 – Test Cases

Mechanische Tests für `coop` und `coop-observe`. Diese Tests prüfen, ob die
Tools korrekt funktionieren – nicht, ob LLM-Agents das Protokoll einhalten.
Letzteres ist die offene Frage, die V1 in der echten Woche beantworten soll.

## Wie man die Tests ausführt

```bash
# Alle Tests
bash tests/run_tests.sh

# Einen einzelnen Test
bash tests/run_tests.sh test_claim_conflict
```

Exit-Code 0 = alle bestanden, 1 = mindestens einer fehlgeschlagen.

## Setup pro Test

Jeder Test bekommt eine frische, isolierte Sandbox in `mktemp -d` mit:

- leerem `.agent-coop/derived_state/`
- minimaler `events.jsonl` (nur INIT)
- leerer `claims.json`
- `COOP_ROOT` env-var auf die Sandbox gesetzt

So kann kein Test einen anderen verschmutzen, und es gibt keine versteckten
Wechselwirkungen mit dem echten Projekt.

## Letzte Test-Ausführung

Lokal ausgeführt am: 2026-05-10

```
========================================
  PASS: 13
  FAIL: 0
========================================
```

Alle Tests grün. Wenn du das Repo klonst und Änderungen am Code machst, sollte
diese Tabelle aktualisiert werden – entweder von Hand, oder besser per CI.

-----

## Test-Cases im Detail

Format pro Test: GIVEN (Ausgangslage), WHEN (Aktion), THEN (Erwartung) →
tatsächliches Ergebnis.

### TC-01: `test_claim_basic`

|Feld               |Wert                                                                                         |
|-------------------|---------------------------------------------------------------------------------------------|
|**Given**          |leere Sandbox, keine aktiven Claims                                                          |
|**When**           |`coop claim src/auth.ts --agent claude --reason "refactor"`                                  |
|**Then (erwartet)**|Exit-Code 0, Output "Claimed src/auth.ts", Eintrag in `claims`, CLAIM-Event in `events.jsonl`|
|**Tatsächlich**    |PASS – alle vier Erwartungen erfüllt                                                         |

### TC-02: `test_claim_conflict`

|Feld               |Wert                                                                |
|-------------------|--------------------------------------------------------------------|
|**Given**          |claude hat `src/auth.ts` geclaimt                                   |
|**When**           |`coop claim src/auth.ts --agent codex --reason "second"`            |
|**Then (erwartet)**|Exit-Code 2, Stderr enthält "CONFLICT" und nennt den Halter "claude"|
|**Tatsächlich**    |PASS – Conflict-Detection funktioniert, Halter wird benannt         |

### TC-03: `test_claim_refresh_same_agent`

|Feld               |Wert                                                         |
|-------------------|-------------------------------------------------------------|
|**Given**          |claude hat `src/auth.ts` mit TTL 5 min geclaimt              |
|**When**           |claude claimt dieselbe Datei erneut mit TTL 60 min           |
|**Then (erwartet)**|Exit-Code 0, kein Duplikat in `claims.json` (genau 1 Eintrag)|
|**Tatsächlich**    |PASS – Refresh überschreibt sauber, kein Duplikat            |

### TC-04: `test_release_basic`

|Feld               |Wert                                                                    |
|-------------------|------------------------------------------------------------------------|
|**Given**          |claude hat `src/auth.ts` geclaimt                                       |
|**When**           |`coop release src/auth.ts --agent claude`                               |
|**Then (erwartet)**|Exit-Code 0, Output "Released", `claims` ist leer, RELEASE-Event geloggt|
|**Tatsächlich**    |PASS                                                                    |

### TC-05: `test_release_nonexistent`

|Feld               |Wert                                                         |
|-------------------|-------------------------------------------------------------|
|**Given**          |keine aktiven Claims                                         |
|**When**           |`coop release src/auth.ts --agent claude`                    |
|**Then (erwartet)**|Exit-Code 1, Output "No active claim"                        |
|**Tatsächlich**    |PASS – Fehlschlag wird sauber gemeldet, kein silent-success  |

### TC-06: `test_claim_expiry_allows_takeover`

|Feld               |Wert                                                                                                                                                                                                |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Given**          |claude claimt mit TTL 0 (sofort ablaufend), 2 Sekunden warten                                                                                                                                       |
|**When**           |codex versucht denselben Pfad zu claimen                                                                                                                                                            |
|**Then (erwartet)**|Exit-Code 0, Takeover gelingt (abgelaufene Claims werden geprunt)                                                                                                                                   |
|**Tatsächlich**    |PASS – TTL-basiertes Auto-Pruning funktioniert                                                                                                                                                      |
|**Anmerkung**      |Genau hier liegt der bekannte TTL-Footgun (siehe README): wenn der erste Agent zurückkommt, weiß er nicht, dass der zweite übernommen hat. Der Test prüft nur die Mechanik, nicht das Designproblem.|

### TC-07: `test_log_decision`

|Feld               |Wert                                                                                                    |
|-------------------|--------------------------------------------------------------------------------------------------------|
|**Given**          |leere Sandbox                                                                                           |
|**When**           |`coop log DECISION --agent claude --payload '{"topic":"auth","choice":"session","reasoning":"simpler"}'`|
|**Then (erwartet)**|Exit-Code 0, Event mit Type "DECISION" und allen Payload-Feldern im Log                                 |
|**Tatsächlich**    |PASS – Payload bleibt strukturell erhalten                                                              |

### TC-08: `test_log_invalid_json`

|Feld               |Wert                                                       |
|-------------------|-----------------------------------------------------------|
|**Given**          |bestimmte Anzahl Events im Log                             |
|**When**           |`coop log DECISION --agent claude --payload 'not json {{{'`|
|**Then (erwartet)**|Exit-Code 1, KEIN Event wird angehängt                     |
|**Tatsächlich**    |PASS – Fail-fast, Log bleibt sauber                        |

### TC-09: `test_events_filter_by_agent`

|Feld               |Wert                                                                 |
|-------------------|---------------------------------------------------------------------|
|**Given**          |2 Events von claude, 1 Event von codex                               |
|**When**           |`coop events --agent claude`                                         |
|**Then (erwartet)**|Genau 2 Events zurück, alle mit `"agent": "claude"`, kein codex-Event|
|**Tatsächlich**    |PASS – Filter ist exakt                                              |

### TC-10: `test_status_summary`

|Feld               |Wert                                                                                                |
|-------------------|----------------------------------------------------------------------------------------------------|
|**Given**          |1 Claim, 2 Events (DECISION, DONE)                                                                  |
|**When**           |`coop status`                                                                                       |
|**Then (erwartet)**|Output enthält "agent-coop status", Event-Typ-Zählung, "Active claims: 1", "claude owns src/auth.ts"|
|**Tatsächlich**    |PASS – alle Sektionen vorhanden                                                                     |

### TC-11: `test_observe_report_runs`

|Feld               |Wert                                                                                                       |
|-------------------|-----------------------------------------------------------------------------------------------------------|
|**Given**          |git-Repo mit einem Commit, ein Claim, ein DECISION-Event                                                   |
|**When**           |`coop-observe report`                                                                                      |
|**Then (erwartet)**|Output enthält Header "coop-observe report", "Total events"-Sektion, ehrliche Zeile "Numbers, not verdicts"|
|**Tatsächlich**    |PASS – Report-Struktur stabil, Disclaimer-Zeile vorhanden                                                  |

### TC-12: `test_observe_snapshot_creates_log`

|Feld               |Wert                                                             |
|-------------------|-----------------------------------------------------------------|
|**Given**          |git-Repo mit einem Commit, keine bisherigen Snapshots            |
|**When**           |`coop-observe snapshot`                                          |
|**Then (erwartet)**|Exit 0, `observations.jsonl` wird erstellt, enthält genau 1 Zeile|
|**Tatsächlich**    |PASS – Snapshot-Append funktioniert                              |

### TC-13: `test_observe_attribution_check`

|Feld               |Wert                                                                              |
|-------------------|----------------------------------------------------------------------------------|
|**Given**          |git-author "human-developer", coop-agent "claude" – Namen überschneiden sich nicht|
|**When**           |`coop-observe attribution-check`                                                  |
|**Then (erwartet)**|Output zeigt beide Namen separat und warnt mit "don't overlap"                    |
|**Tatsächlich**    |PASS – Attribution-Mismatch wird ehrlich gemeldet (statt heimlich zu raten)       |

-----

## Was diese Tests nicht abdecken

Bewusst nicht getestet, weil außerhalb dessen, was V1 mechanisch garantieren
kann:

- **Concurrent Writes** auf `events.jsonl` aus mehreren Prozessen. V1 nutzt
  einfaches Append ohne Locking. Bei zwei Agents, die gleichzeitig loggen,
  kann es theoretisch zu interleaved Schreibvorgängen kommen. In der Praxis
  sind LLM-Agent-Calls langsam genug, dass das vermutlich kein Problem ist –
  aber wir wissen es nicht. Eine echte Woche zeigt, ob das je auftritt.
- **Korruptes events.jsonl wiederherstellen.** Wenn jemand die Datei manuell
  editiert oder ein Crash mid-write passiert, kann das Log unparsbar werden.
  Es gibt keine Recovery-Logik. Das wäre V2-Material.
- **Sehr große Logs** (>100k Events). `coop status` und `coop-observe report`
  lesen das gesamte Log in Memory. Bei einer einwöchigen Beobachtung ist das
  völlig egal. Bei langer Nutzung wäre Streaming nötig.
- **Bösartige Inputs.** Pfad-Traversal in `--path`, JSON-Injection in
  Payloads, etc. V1 ist für kooperative Agents in einer Sandbox gebaut, nicht
  für Adversarial Use.
- **Verhalten echter LLM-Agents.** Das ist explizit Aufgabe der echten
  Beobachtungswoche, nicht dieser Suite.

## Wann die Tests scheitern sollten

Wenn diese Tests scheitern, nachdem du Code geändert hast, ist das fast
immer ein echter Regress. Die Tests sind alle deterministisch (kein
Sampling, keine LLM-Calls, keine Netzwerk-Abhängigkeiten).

Eine Ausnahme: TC-06 (`test_claim_expiry_allows_takeover`) verlässt sich auf
`sleep 2`. Bei extrem überlasteten Systemen könnte das theoretisch flaky
werden. Falls das je passiert, in `sleep 3` ändern – nicht das Test-Konzept
aufweichen.

## Vorab-Prognose für die echte Woche (Tag-1-Disziplin)

Die Tests oben prüfen Mechanik. Die *interessanten* Zahlen kommen erst aus
der Beobachtungswoche. Hier mein ehrlicher Tipp, wie er ohne Daten aussieht
– aufschreiben, bevor die Realität reinredet:

|Metrik                                   |Vorab-Prognose                 |Tatsächlich nach Woche 1|
|-----------------------------------------|-------------------------------|------------------------|
|Compliance-Ratio (file-changes mit Claim)|40–60%                         |*eintragen*             |
|DISAGREE-Events                          |0–2                            |*eintragen*             |
|DECISION-Events                          |10–25                          |*eintragen*             |
|Reproduzierbare Konflikte (CLAIM-Exit-2) |1–5                            |*eintragen*             |
|Multi-Agent vs Single-Agent (Qualität)   |gleich oder schlechter         |*eintragen*             |
|Coordination-Overhead (menschliche Zeit) |merklich höher als Single-Agent|*eintragen*             |

Wenn die tatsächlichen Werte näher an dieser Vorab-Prognose liegen als an
den optimistischen Annahmen der Architektur, ist das das eigentliche
Ergebnis – unabhängig davon, was die Architektur "verspricht".
