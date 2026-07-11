# Spec: Milestone "Das Taktik- & Klassen-Fundament"

## 1. Problem Statement

Der aktuelle vertikale Prototyp (Meilenstein 1) hat genau eine Spielereinheit
(`MeleeUnit`), keine Ziel-Objekte außer einem statischen Dummy, und einen
Touch-Controller, der ausnahmslos alle eigenen Einheiten an einen Tippunkt
schickt. Um Richtung eines echten 1v1-Matches zu arbeiten, fehlen:

- Ein zerstörbares Siegbedingungs-Objekt (Kommandozentrale/HQ) pro Spieler.
- Die zwei fehlenden Grundklassen des Schere-Stein-Papier-Systems
  (Fernkampf, Mobil) neben dem bestehenden Nahkämpfer.
- Eine Selektionslogik, die zwischen "eine Einheit wählen" und "eine Gruppe
  von Einheiten wählen" unterscheidet, bevor ein Bewegungsbefehl sinnvoll
  auf mehrere Einheiten angewendet werden kann.

Dieser Meilenstein liefert das Fundament, auf dem später Rassen-Fähigkeiten,
Ressourcen und echte Gegner-KI aufbauen.

## 2. Requirements

### 2.1 Kommandozentrale (HQ)

- Neue Datei `scripts/structures/headquarters.gd`, Klasse `Headquarters`,
  **erbt von `Unit`** (Entscheidung: HQ erbt von Unit).
  - Override in `_ready()`: `move_speed = 0.0`, kein Bewegungsbefehl möglich
    (siehe 2.3 — HQs sind niemals selektierbar/beweglich).
  - `max_hp` Default `1000.0`.
  - HQ greift nicht an: `attack_range = 0.0`, `damage = 0.0` (analog zu
    `DummyUnit`, aber weiterhin über gemeinsame `Unit`-Basis statt eigener
    `_physics_process`-Overrides, wo vermeidbar).
  - Zusätzliches Signal `hq_destroyed(team: Unit.Team)`, emittiert aus
    `_die()`-Override, **zusätzlich** zum bestehenden `died`-Signal (nicht
    anstelle davon, damit generische HP-Bar-/Death-Logik der Basisklasse
    weiter funktioniert).
  - HQ wird über die normale Team-Gruppe (`team_player`/`team_enemy`)
    gefunden — Einheiten behandeln es wie jedes andere `Unit`-Ziel (siehe
    2.2 Ziel-Priorität).
- Je eine `Headquarters`-Szene/Instanz für Spieler und Gegner in `main.tscn`,
  an entgegengesetzten Enden des Spielfelds platziert (z. B. `x=40` Spieler,
  `x=600` Gegner, `y=180`, passend zur bestehenden 640×360-Viewport-Größe).
- Neue Szene `scenes/structures/headquarters.tscn` (analog zu den
  bestehenden Unit-Szenen: `CollisionShape2D`, `Polygon2D`-Silhouette in
  Team-Farbe, `HPBar`). HQ-Silhouette optisch klar größer/anders als
  Einheiten (z. B. Quadrat, deutlich größer skaliert), damit auf kleinem
  Bildschirm sofort als Gebäude erkennbar.

### 2.2 Ziel-Priorität für Angriffe

- **Entscheidung: "Nächstes Ziel zuerst"** — `Unit._find_target_in_range()`
  bleibt unverändert in seiner Logik (nächstes Objekt in der
  gegnerischen Gruppe, unabhängig davon ob es sich um eine reguläre Einheit
  oder ein HQ handelt). Da HQs regulär in `team_player`/`team_enemy`
  gruppiert sind, ergibt sich das gewünschte Verhalten (Rush am Heer vorbei
  möglich) automatisch, **ohne Sonderlogik** — das ist bewusst Teil der
  Spec, um unnötige Komplexität zu vermeiden.

### 2.3 Neue Einheitenklassen

- `scripts/units/ranged_unit.gd`, Klasse `RangedUnit`, erbt von `Unit`.
  - Defaults (überschreibbar im Editor): `max_hp = 60.0`, `damage = 6.0`,
    `attack_range = 160.0`, `move_speed = 130.0`, `attack_cooldown = 1.0`.
  - Verhalten: identisch zur Basisklasse (bleibt stehen und feuert per
    Timer-Schaden, sobald Ziel in `attack_range`) — **kein neuer Code in
    `Unit` nötig**, da `_physics_process` bereits "steht, wenn Ziel in
    Reichweite" umsetzt. Die hohe `attack_range` allein erzeugt das
    gewünschte Fernkampf-Gefühl. Kein Projektil-Node in diesem Meilenstein.
  - Eigene Szene `scenes/units/ranged_unit.tscn` mit eigener Silhouette
    (z. B. Dreieck/Diamant, dünnere Form) in Team-Farbe.
- `scripts/units/mobile_unit.gd`, Klasse `MobileUnit`, erbt von `Unit`.
  - Defaults: `max_hp = 80.0`, `damage = 14.0`, `attack_range = 40.0`,
    `move_speed = 260.0`, `attack_cooldown = 1.0`.
  - Kein Sonderverhalten nötig, reine Stat-Variante.
  - Eigene Szene `scenes/units/mobile_unit.tscn`, Silhouette z. B. Pfeil-
    /Rautenform, in Team-Farbe.
- Bestehende `melee_unit.gd`/`melee_unit.tscn` bleiben unverändert
  (Referenzwerte: `max_hp = 100`, `damage = 10`, `attack_range = 48`,
  `move_speed = 150`).
- Klarstellung zu "Fernkämpfer bleiben stehen und schießen": Das ist
  bereits aktuelles Verhalten der `Unit`-Basisklasse (`velocity = ZERO`
  sobald Ziel in Reichweite). Es ist **keine Änderung an `unit.gd`
  notwendig** — dieser Punkt der Anforderung ist durch die bestehende
  Implementierung bereits erfüllt und wird nur durch Tests bestätigt.

### 2.4 Multi-Unit-Selektion (Touch-Controller)

Erweiterung von `scripts/main/touch_input_controller.gd`. Neuer State:
`selected_units: Array[Unit]` (leer = "keine Auswahl" = altes Verhalten
für Rückwärtskompatibilität nicht nötig, da Zielverhalten sich ändert,
siehe unten).

- **Einfacher Tap:**
  - Tap auf eine eigene, lebende, selektierbare Einheit (Distanz-Check
    Tap-Weltposition zu Einheiten-Position, z. B. Treffer-Radius
    `selection_tap_radius = 24.0`) → `selected_units = [einheit]`,
    visuelles Feedback (siehe unten).
  - Tap auf leeren Boden (keine eigene Einheit getroffen) → wenn aktuell
    Einheiten selektiert sind: **Bewegungsbefehl** an alle
    `selected_units` (identisches Zielpunkt für alle, wie im bestehenden
    `_command_player_units_to`). Wenn keine Einheiten selektiert sind:
    kein Effekt (kein Fallback auf "alle Einheiten bewegen" mehr — das
    bisherige "Tap bewegt automatisch alle" Verhalten wird durch explizite
    Selektion ersetzt).
  - Tap auf eine **andere** eigene Einheit während bereits eine Auswahl
    existiert → Auswahl wird auf die neu angetippte Einheit **ersetzt**
    (kein Hinzufügen zur Gruppe per Einzel-Tap, das ist ausschließlich dem
    Doppel-Tap vorbehalten).
- **Doppel-Tap (Zeitfenster, Entscheidung: "T"):**
  - Erkennung: Zwei Taps auf **dieselbe eigene Einheit** (erster Tap trifft
    eine eigene Einheit gemäß `selection_tap_radius`) innerhalb von
    `double_tap_window = 0.3s` und der zweite Tap liegt innerhalb von
    `double_tap_max_distance = 20.0px` Bildschirmabstand vom ersten
    Tap-Punkt.
  - Effekt (Entscheidung: "Nur auf eigener Einheit"): Wählt **alle**
    lebenden eigenen Einheiten aus, deren Weltposition innerhalb von
    `group_select_radius = 150.0` (Welteinheiten, nicht Pixel) um die
    **angetippte Einheit** liegt (nicht um den rohen Tap-Punkt).
  - Ein Doppel-Tap auf leeren Boden (kein Einheitentreffer beim ersten
    Tap) löst **keine** Flächenauswahl aus und wird wie zwei normale
    Bewegungsbefehle behandelt (bzw. wie zwei einzelne "leerer Tap"-
    Events gemäß obiger Einzel-Tap-Regel).
- **Visuelles Feedback für Selektion:** Jede `Unit`-Szene erhält einen
  optionalen Kindknoten `SelectionRing` (z. B. `Node2D` mit einfachem
  `_draw()`-Kreis oder ein einfaches `Polygon2D`, `visible = false` per
  Default). `Unit` bekommt eine Methode `set_selected(is_selected: bool)`,
  die nur `SelectionRing.visible` toggelt (kein Gameplay-Effekt). Der
  Touch-Controller ruft `set_selected(true)` für neu selektierte und
  `set_selected(false)` für zuvor selektierte, jetzt nicht mehr
  selektierte Einheiten auf.
- **Gegnerische Einheiten sind nie selektierbar** — Selektions-Hit-Test
  läuft ausschließlich über `get_tree().get_nodes_in_group("team_player")`.
- **HQs sind nie selektierbar und nie Ziel eines Bewegungsbefehls** — HQs
  befinden sich zwar in den Team-Gruppen (für Angriffszwecke, siehe 2.2),
  werden aber im Selektions-Hit-Test explizit ausgeschlossen (z. B. Check
  `not node is Headquarters`).

### 2.5 Match-Ende (Entscheidung: "Freeze + Log")

- `scripts/main/main.gd` verbindet sich in `_ready()` mit dem
  `hq_destroyed`-Signal **beider** HQ-Instanzen.
- Handler `_on_hq_destroyed(team: Unit.Team)`:
  - `print("Match Over — Team %s wins" % winning_team_name)` (Gewinner ist
    das Team, das **nicht** dem zerstörten HQ gehört).
  - Setzt `get_tree().paused = true` (Godot-Standardmechanismus, wirkt
    global auf alle Nodes mit Default `process_mode`).
  - Verhindert doppelte Auslösung, falls beide HQs im selben Frame auf 0
    fallen (Guard-Flag `match_over: bool`).

## 3. Acceptance Criteria

1. `main.tscn` enthält zwei `Headquarters`-Instanzen (`team_player` und
   `team_enemy`), je mit `max_hp = 1000`, an entgegengesetzten Seiten der
   Karte.
2. Eine `MeleeUnit`, eine `RangedUnit` und eine `MobileUnit` (alle Team
   `player`) können jeweils einzeln per Kommando zum gegnerischen HQ
   geschickt werden und zerstören es nach ausreichender Zeit (bestätigt via
   Headless-Testlauf: HP sinkt kontinuierlich bis 0, `hq_destroyed`-Signal
   wird ausgelöst).
3. Eine Einheit, die am gegnerischen HQ **näher** vorbeiläuft als an einer
   dazwischenstehenden gegnerischen Einheit, greift automatisch das HQ an
   (nicht die Einheit) — bestätigt die "nächstes Ziel"-Priorität.
4. Ranged-Unit bleibt stehen, sobald ein Ziel innerhalb von
   `attack_range = 160` ist, und verursacht Schaden im Cooldown-Rhythmus,
   ohne sich weiter zu bewegen (Positions-Log im Test zeigt `velocity` /
   Position konstant während Angriff läuft).
5. Einzel-Tap auf eine eigene Einheit selektiert genau diese eine Einheit
   (visuell via `SelectionRing`); ein nachfolgender Tap auf leeren Boden
   bewegt ausschließlich diese Einheit.
6. Doppel-Tap (zwei Taps auf dieselbe Einheit binnen 0.3s / 20px) selektiert
   alle eigenen Einheiten im Radius 150 um die angetippte Einheit; ein
   nachfolgender Tap auf leeren Boden bewegt alle selektierten Einheiten
   zum selben Zielpunkt.
7. Gegnerische Einheiten und beide HQs sind über den Touch-Controller
   niemals selektierbar oder direkt beweglich.
8. Wird ein HQ auf 0 HP reduziert, wird das Match pausiert
   (`get_tree().paused == true`) und eine Sieger-Meldung geloggt; ein
   zweites Auslösen im selben Frame erzeugt keine doppelte Meldung.
9. Alle neuen Skripte/Szenen sind über `godot4 --headless --path . --import`
   fehlerfrei ladbar.
10. Ein temporäres Headless-Verify-Skript (analog zum vorherigen Meilenstein,
    nicht Teil des finalen Commits) bestätigt Punkte 2–4 und 8 automatisiert
    und wird nach erfolgreicher Verifikation wieder entfernt.

## 4. Implementation Approach

1. **HQ-Grundlage:** `scripts/structures/headquarters.gd` (erbt `Unit`,
   Move-Speed/Angriffswerte auf 0, zusätzliches `hq_destroyed`-Signal,
   `_die()`-Override) + `scenes/structures/headquarters.tscn`
   (Silhouette, HPBar, CollisionShape2D, `max_hp = 1000`).
2. **Neue Einheitenklassen:** `scripts/units/ranged_unit.gd` +
   `scenes/units/ranged_unit.tscn`, sowie `scripts/units/mobile_unit.gd` +
   `scenes/units/mobile_unit.tscn`, jeweils mit den in 2.3 definierten
   Stat-Defaults und eigener Silhouettenform.
3. **Selection/Feedback-Grundlage in `Unit`:** `SelectionRing`-Kindknoten
   (in Basis-Unit-Szenen ergänzen: melee/ranged/mobile) + `set_selected()`
   -Methode in `unit.gd`. HQ-Szene bekommt **keinen** `SelectionRing`
   (HQs sind nicht selektierbar).
4. **Touch-Controller-Rewrite:** State (`selected_units`), Tap-Hit-Test
   gegen `team_player`-Gruppe (unter Ausschluss von `Headquarters`),
   Doppel-Tap-Erkennung mit Zeitfenster + Distanzcheck, Gruppen-Radius-
   Selektion, Bewegungsbefehl-Dispatch an `selected_units`.
5. **Match-Ende-Logik in `main.gd`:** Signal-Verbindung zu beiden HQs,
   Guard-Flag, `get_tree().paused = true`, Log-Ausgabe mit Gewinner-Team.
6. **main.tscn zusammensetzen:** Zwei HQ-Instanzen platzieren, vorhandene
   `DummyUnit` durch/neben die neuen Klassen ergänzen oder ersetzen (Dummy
   kann als einfaches Zwischenziel bestehen bleiben oder entfernt werden —
   in main.tscn mindestens eine Instanz jeder der drei Spieler-Klassen plus
   beide HQs).
7. **Headless-Verifikation:** Temporäres `_verify_milestone2.gd`
   (SceneTree-Skript wie im vorherigen Meilenstein) schreiben, das:
   - alle drei Einheitenklassen einzeln zum Gegner-HQ schickt und
     Zerstörung bestätigt,
   - eine Situation mit blockierender gegnerischer Einheit vs. direktem
     HQ-Rush testet,
   - Doppel-Tap-Selektionslogik direkt über Controller-Methoden
     (nicht über echte Input-Events, da Headless) testet,
   - HQ-Zerstörung → `get_tree().paused == true` prüft.
   Nach PASS-Bestätigung wird das Verify-Skript wieder gelöscht.
8. **Import-Validierung:** `godot4 --headless --path . --import` fehlerfrei.
9. **Cleanup & Zusammenfassung:** Temporäre Testskripte entfernen, Diff
   sichten, kurze Zusammenfassung der Änderungen liefern.
