# Design-Spec: Völker & Standorte (Modul 4.2) — Stammdaten-Kern

**Stand:** 2026-07-17 · **Status:** überarbeitet nach adversarialem Multi-Agent-Review (43 Findings, 36 bestätigt) · **Modell:** Fable 5 (DB/RLS/mandantenkritisch)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.2 · [App-Implikationen aus der Imkerei-Recherche](../../imkerei-fachwissen-app-implikationen.md) · Fachwissen: `../../../imkerei/02_Recherche/10`, `12`, `13`, `19`

---

## 1. Zweck

Das erste echte Fachmodul auf dem Auth-Fundament. **Jedes Volk wird ein Datensatz**, an dem später alles hängt (Durchsicht, Behandlung, Fütterung, Ernte, Waage, Bestandeskontrolle). Dazu die zwei Entitäten, ohne die ein Volk ab Volk 1 unvollständig ist: der **Standort** (kantonale Registrierungs-/Bestandeskontroll-Felder) und die **Königin** (Selektions- und Zuchtbasis).

**Realitätscheck:** Herbst 2026 = **1 Volk**, 2027 = 2, bis 2030 max. 8. Das **Datenmodell** wird auf 32/64 ausgelegt, die **UI** bewusst schlicht gehalten. **YAGNI gilt für die Bedienoberfläche, nicht für Datenintegrität.**

## 2. Scope

### In Scope
- Neue Tabellen `betriebs_einstellungen`, `standorte`, `koeniginnen`; `voelker` erweitern + aufräumen.
- Flutter-Feature `lib/features/voelker/`: Völkerliste, Volk-Detailseite (Drehscheibe), Formulare, Umweiselung.
- Jahresfarbe-Ableitung, Umweiselungs-RPC, RLS + Same-Tenant-Integrität + Tests + Advisor-Gate.
- **Zwei kleine Fremdeingriffe** (vom Review erzwungen, siehe §7): `Scale`-Model um `volkId` erweitern; die vier neuen Provider in `AuthController._datenNeuLaden()` registrieren.

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **Ampel-Status** (Weiselrichtigkeit, Varroa-Last, Futterstand) | Speist sich aus 4.3/4.5/4.6 — Tabellen existieren nicht. |
| **Ereignis-Timeline** | Dito. Wird als **Erweiterungspunkt** vorbereitet (Platzhalter-Sektion), damit 4.3/4.5 andocken statt umbauen. |
| **QR-/NFC-Etikett, Sammelaktionen (Bulk)** | YAGNI bei 1–8 Völkern. Sinnvoll ab ~32. |
| **Zuchtbuch voll** (Umlarv-Kalender, Leistungsprüfung, Pedigree-UI) | Modul 4.17, P3 (ab 2028). Das **Register** ist P1 und hier enthalten; das Datenmodell hält den Anschluss offen. |
| **Weiselzustand-Statuskette** (weisellos→verweiselt→begattet) | Gehört zu 4.16 Ableger + Ampel. Königinlosigkeit ist hier über `koenigin_id IS NULL` abbildbar (§6). |
| **Melde-/Fristen-Workflow** (`gemeldet_am`, Völkererhebung) | Modul 4.23. Die Standort-**Anker** (Status, Nummern) entstehen hier. |
| **Restliche F4-Settings** (Varroa-Schwellen, Winterfutter-Soll, Fristen) | Nur die von 4.2 benötigten Parameter jetzt; `betriebs_einstellungen` ist die Keimzelle. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Stammdaten-Kern.** Ampel/Timeline als vorbereitete Erweiterungspunkte statt Halbfertig-Bau.
2. **Betriebs-Defaults in eigener `betriebs_einstellungen`-Tabelle** (1:1 je Betrieb, typisierte Spalten) statt Spalten auf `betriebe` — trennt Identität von Konfiguration, F4-Keimzelle.
3. **Königin als eigene Entität** (nicht Felder am Volk) — Voraussetzung für **Umweiselung mit Zuordnungs-Spur** (§4.3) und 4.17-Anschluss.
4. **Rasse/Linie hängen an der Königin, nicht am Volk.** Die Königin bestimmt die Volksgenetik (alle Arbeiterinnen sind ihre Töchter, Volksumsatz ~6 Wochen; `02_Recherche/10`, `12`). Nach einer Umweiselung ist die Rasse damit automatisch korrekt — `voelker.rasse` entfällt (und mit ihr der `'Buckfast'`-Hardcode).

## 4. Datenmodell

Alle neuen Tabellen folgen dem etablierten Mandanten-Muster:
- `betrieb_id uuid NOT NULL DEFAULT private.aktive_betrieb_id()` — **Ausnahme:** `betriebs_einstellungen`, siehe §4.1.
- `created_by`/`updated_by uuid`, `created_at`/`updated_at timestamptz DEFAULT now()`
- Trigger `set_row_actor` + `update_updated_at`
- RLS (Policy-Namen `<tabelle>_{sel_member|ins_writer|upd_writer|del_writer}`):
  - `SELECT`: `betrieb_id IN (SELECT private.meine_betrieb_ids())`
  - `INSERT`: `WITH CHECK private.kann_schreiben(betrieb_id)`
  - `UPDATE`: `USING` + `WITH CHECK private.kann_schreiben(betrieb_id)`
  - `DELETE`: `USING private.kann_schreiben(betrieb_id)` — **nicht** auf `betriebs_einstellungen` (§4.1)
- **`revoke all on <tabelle> from anon, public;` + `grant` nur an `authenticated`** (Default-ACL nicht vererben lassen).
- Enums als `text` + `CHECK` (migrationsfreundlicher als PG-Enums, folgt dem Bestandsstil).

### 4.0 Same-Tenant-Integrität (Pflicht für alle Beziehungen)

**Problem:** Postgres prüft Fremdschlüssel als Tabelleneigentümer — **RLS greift dabei nicht**. Ein einfacher FK würde erlauben, per direktem PostgREST-Zugriff ein Volk aus Betrieb A mit einer Königin aus Betrieb B zu verknüpfen (RLS prüft nur die `betrieb_id` der eigenen Zeile). Folgen: UUID-Existenz-Orakel über Mandantengrenzen, Cross-Tenant-Seiteneffekt (fremdes `ON DELETE SET NULL` schreibt in eigene Zeile und stempelt via `set_row_actor` einen fremden `updated_by`), dauerhaft korrupte Verknüpfungen.

**Lösung — verbindlich für jede FK dieses Moduls:**
1. `UNIQUE (betrieb_id, id)` auf `standorte`, `koeniginnen`, `voelker`.
2. **Zusammengesetzte FKs** mit spaltenbeschränktem SET NULL (PG 15+; Live-DB ist PG 17.6):
   ```sql
   foreign key (betrieb_id, standort_id) references public.standorte (betrieb_id, id)
     on delete set null (standort_id)
   ```
   Die **Spaltenliste hinter `SET NULL` ist Pflicht** — ohne sie würde `betrieb_id` mitgenullt (NOT-NULL-Verletzung).
3. Gilt für: `voelker.standort_id`, `voelker.koenigin_id`, `voelker.mutter_volk_id` (self), `koeniginnen.mutter_koenigin_id` (self), `koeniginnen.volk_id`.
4. **Bestandslücke gleich mitschliessen:** `scales.volk_id` ist heute ein einfacher FK → in C04 auf das Kompositmuster umstellen (`scales` hat `betrieb_id`).

### 4.1 `betriebs_einstellungen` (neu, 1 Zeile je Betrieb)

| Spalte | Typ | Notiz |
|---|---|---|
| `betrieb_id` | `uuid PK` → `betriebe(id) ON DELETE CASCADE` | PK **und** FK → erzwingt 1:1. **Kein `DEFAULT private.aktive_betrieb_id()`** (siehe unten) |
| `rasse_default` | `text NULL` | App-seitige **Vorbelegung** beim Anlegen einer Königin (editierbar) |
| `beutensystem_default` | `text NULL` | App-seitige Vorbelegung beim Anlegen eines Volks |
| `hoehe_default_m` | `int NULL` | **reine Formular-Vorbelegung** beim Anlegen eines Standorts — **kein fachlicher Fallback** |
| `saison_offset_default_tage` | `int NOT NULL DEFAULT 0` | Vorbelegung; 0 = Flachland-Normal |
| `kanton` | `text NULL` | Vorbelegung für `standorte.kanton` |
| `imker_identnummer` | `text NULL` | kantonale **Imker**-Identifikationsnummer (TSV Art. 18a Abs. 4) — gilt betriebsweit |
| + audit | | |

> **⚠ Kein `DEFAULT private.aktive_betrieb_id()`:** `aktive_betrieb_id()` liest den JWT-Claim `app_metadata.betrieb_id`. Beim Aufruf von `betrieb_gruenden` ist der Gründer per `BA003`-Guard noch **mitgliedschaftslos** — sein Token trägt den Claim garantiert nicht. Ein Insert über den Spalten-Default liefert NULL → PK-Verletzung → **die live genutzte `betrieb_gruenden`-Transaktion bricht für jeden neuen Betrieb**. Die RPC übergibt `betrieb_id` deshalb **explizit**: `insert into public.betriebs_einstellungen (betrieb_id) values (v_betrieb);`

> **Keine DELETE-Policy:** Die 1:1-Zeile darf nicht löschbar sein (sonst dauerhaft erreichbarer Leerzustand für jeden Mandanten). Nur `sel_member` + `ins_writer` + `upd_writer`.

**Anlage:** (a) `betrieb_gruenden` legt die Zeile für neue Betriebe an (explizite `betrieb_id`, Neutralwerte). (b) **C01 enthält einen idempotenten Backfill** für bestehende Betriebe: `insert into public.betriebs_einstellungen (betrieb_id) select id from public.betriebe on conflict (betrieb_id) do nothing;` — Neutralwerte, **kein Arosa-Hardcode**.

### 4.2 `standorte` (neu)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK DEFAULT gen_random_uuid()` | |
| `name` | `text NOT NULL` | |
| `adresse` | `text NULL` | Pflichtangabe der kantonalen Standort-Meldung |
| `parzelle` | `text NULL` | dito |
| `gps_lat`, `gps_lng` | `numeric NULL` | einfache Koordinaten (PostGIS: YAGNI) |
| `hoehe_m` | `int NULL` | **fachlich massgebliche Höhe dieses Stands.** Höhenabhängige Logik liest ausschliesslich hier — **kein Fallback** auf den Betriebswert |
| `kanton` | `text NULL` | NULL = beim Anlegen aus `betriebs_einstellungen.kanton` vorbelegt. **Massgeblich für diesen Stand**: Registrierung, Standnummer, Inspektionskreis, Wander-Meldung hängen am Kanton des **Standes**, nicht am Betriebssitz (`02_Recherche/19` §2/§6) |
| `amtliche_standnummer` | `text NULL` | kantonale **Stand**-Identifikationsnummer (TSV Art. 18a Abs. 4); Kennzeichnungspflicht TSV Art. 19a Abs. 1 |
| `inspektionskreis` | `text NULL` | |
| `status` | `text NOT NULL DEFAULT 'besetzt'` | CHECK: `besetzt\|unbesetzt\|aufgeloest`. Auch **unbesetzte** Stände sind meldepflichtig |
| `aufgeloest_am` | `date NULL` | Beleg des Auflösungsdatums |
| `trachtnotiz` | `text NULL` | |
| `sperrbezirk` | `boolean NOT NULL DEFAULT false` | AFB/EFB-Flag (Anzeige-Anker; die führende Wahrheit kommt mit 4.14/4.23) |
| `notes`, `sort_order` | `text` / `int DEFAULT 0` | |
| + audit | | |

> **Kein `tvd_betriebsnummer`.** Bienenstände werden **nicht** in der Tierverkehrsdatenbank registriert; Imker erhalten keine TVD-Nummer — zuständig ist die kantonale Koordinationsstelle (`02_Recherche/19`, Faktencheck + §2.1/§6.1). Ein solches Feld würde zur Eintragung einer nicht existierenden oder fremden (landwirtschaftlichen) Nummer verleiten. Die real vergebene **Imker**-Nummer liegt in `betriebs_einstellungen.imker_identnummer` (§4.1).

### 4.3 `koeniginnen` (neu)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK DEFAULT gen_random_uuid()` | |
| `kennung` | `text NULL` | Nummer/Zeichen des Imkers (Opalith) |
| `schlupfjahr` | `int NULL` | **Quelle der Jahresfarbe** (nicht gespeichert, §5) |
| `rasse` | `text NULL` | App belegt aus `betriebs_einstellungen.rasse_default` vor (editierbar) — **kein DB-Default** |
| `linie` | `text NULL` | z. B. „F1 Tino Hassler" |
| `herkunft` | `text NULL` | |
| `begattungsart` | `text NOT NULL DEFAULT 'unbekannt'` | CHECK: `standbegattung\|belegstelle\|instrumentell\|unbekannt` |
| `status` | `text NOT NULL DEFAULT 'aktiv'` | CHECK: `aktiv\|ersetzt\|tot\|verschollen` |
| `volk_id` | `uuid NULL` → `voelker` (komposit, §4.0) | **zuletzt zugeordnetes Volk — reine Historien-Spur**, bleibt bei `status='ersetzt'` stehen |
| `zugeordnet_am` | `date NULL` | Zusetzdatum (Bio-Dokumentation, `02_Recherche/12`) |
| `ersetzt_am` | `date NULL` | |
| `mutter_koenigin_id` | `uuid NULL` → `koeniginnen` (komposit, self) | Stammbaum-Anschluss für 4.17 |
| `notes` | `text NULL` | |
| + audit | | |

> **Quelle der Wahrheit (verbindlich, gegen Drift):** `voelker.koenigin_id` ist der **aktuelle** Zeiger und die Basis der `BA022`-Prüfung. `koeniginnen.volk_id`/`zugeordnet_am`/`ersetzt_am` sind **reine Historien-Spur** und werden **ausschliesslich vom RPC `volk_umweiseln`** geschrieben — nie per CRUD.

Damit ist die Zeitachse je Volk: `select * from koeniginnen where volk_id = X order by zugeordnet_am`. Eine eigene Zuordnungstabelle wäre bei 1–8 Völkern YAGNI und bleibt später verlustfrei aus diesen Spalten backfillbar.

### 4.4 `voelker` (erweitern — Tabelle ist **leer**, keine Datenmigration)

**Neu:**

| Spalte | Typ | Notiz |
|---|---|---|
| `standort_id` | `uuid NULL` → `standorte` (komposit, §4.0) | |
| `koenigin_id` | `uuid NULL` → `koeniginnen` (komposit, §4.0) | **aktuelle** Königin. `NULL` = weisellos/noch nicht erfasst (regulärer Zustand) |
| `mutter_volk_id` | `uuid NULL` → `voelker` (komposit, self) | Ableger-Herkunft (4.16-Anschluss) |
| `beutentyp` | `text NULL` | **kein** DB-Default; App belegt aus `betriebs_einstellungen.beutensystem_default` vor |
| `zargen` | `int NULL` | |
| `brutwaben` | `int NULL` | |
| `bio_status` | `text NOT NULL DEFAULT 'unbekannt'` | CHECK: `bio\|umstellung\|konventionell\|unbekannt` |
| `gesundheitsstatus` | `text NOT NULL DEFAULT 'unauffaellig'` | CHECK: `unauffaellig\|beobachtung\|krank\|sperre` |

**Aufräumen (Hardcode-/Altlast-Beseitigung):**
- **`DROP COLUMN rasse`** — Rasse gehört an die Königin (Entscheid 4). Der `'Buckfast'`-Default fällt mit der Spalte; ein separates `DROP DEFAULT` erübrigt sich.
- **`DROP COLUMN standort`** (Freitext) → ersetzt durch `standort_id`.
- **`DROP COLUMN koenigin_jahr`** → ersetzt durch `koeniginnen.schlupfjahr`.
- **`ALTER COLUMN status SET NOT NULL`** + `CHECK (status IN ('aktiv','aufgeloest','vereinigt','verkauft','verloren'))` (Default `'aktiv'` bleibt). Die Spalte war nullable und ohne CHECK — der geplante Status-Chip (§7) wäre sonst nicht implementierbar, und 4.15/4.23 brauchen definierte Abgangswerte.
- **`einweiselung_am` semantisch geklärt:** Datum der **Volks**-Übernahme/-Einweiselung, **nicht** der jeweiligen Königin (deren Datum ist `koeniginnen.zugeordnet_am`).

**Vorbedingung der Drops (im Plan als Prüfschritt):** (a) repo-seitig `grep -r "rasse\|koenigin_jahr\|\"standort\"" lib/` → keine Treffer; (b) **DB-seitiger Guard in C04**: `do $$ begin if (select count(*) from public.voelker) > 0 then raise exception 'voelker nicht leer — Drops abbrechen'; end if; end $$;`

**Indizes:** `UNIQUE (betrieb_id, id)`; **`CREATE UNIQUE INDEX voelker_koenigin_uniq ON public.voelker (koenigin_id) WHERE koenigin_id IS NOT NULL`** (macht die BA022-Invariante zur DB-Garantie und schliesst den RPC-Race); FK-führende Indizes `voelker(standort_id)`, `voelker(mutter_volk_id)`, `koeniginnen(volk_id)`, `koeniginnen(mutter_koenigin_id)` (sonst 4 neue `unindexed_foreign_keys`-Advisor-Findings); `standorte(betrieb_id, sort_order)`, `koeniginnen(betrieb_id, status)`.

## 5. Jahresfarbe

Fixer internationaler 5er-Zyklus über die **Endziffer** des Schlupfjahrs — **kein Mandanten-Config**, keine DB-Spalte:

| Endziffer | 1/6 | 2/7 | 3/8 | 4/9 | 5/0 |
|---|---|---|---|---|---|
| Farbe | **weiss** | **gelb** | **rot** | **grün** | **blau** |

→ 2026 = weiss · 2027 = gelb · 2028 = rot · 2029 = grün · 2030 = blau.

Reine Dart-Funktion `jahresfarbe(int schlupfjahr) → Jahresfarbe` in der Domain-Schicht, vollständig unit-testbar. *(Quelle: `02_Recherche/11`, `12` — Fable-verifiziert.)*

## 6. Umweiselung (RPC `volk_umweiseln`)

Umweiseln muss **atomar** sein — sonst bleiben Volk-Zuordnung und Königin-Status inkonsistent zurück (Königin ohne Volk auf `aktiv`). **Königinlosigkeit ist dagegen ein regulärer Betriebszustand**, kein Fehler: bei Nachschaffung ist ein Volk ~25–35 Tage weisellos (`02_Recherche/12`, `13`).

```
volk_umweiseln(
  p_volk_id          uuid,
  p_neue_koenigin_id uuid DEFAULT NULL,          -- NULL = Volk bleibt bewusst weisellos
  p_alt_grund        text DEFAULT 'ersetzt',      -- ersetzt|tot|verschollen
  p_datum            date DEFAULT current_date
) → void
```

- `SECURITY DEFINER`, `SET search_path = ''`, alle Objekte voll qualifiziert.
- `REVOKE EXECUTE ... FROM anon, public` · `GRANT EXECUTE ... TO authenticated`.
- **Ablauf:** Volk mit `SELECT ... FOR UPDATE` laden (verhindert Lost-Update) → `private.kann_schreiben(v.betrieb_id)`, sonst `BA020`. Falls `p_neue_koenigin_id IS NOT NULL`: Königin laden und **`k.betrieb_id = v.betrieb_id` prüfen**, sonst `BA021`. Alte Königin (falls vorhanden) → `status = p_alt_grund`, `ersetzt_am = p_datum` (`volk_id` bleibt stehen). Neue Königin → `volk_id = p_volk_id`, `zugeordnet_am = p_datum`. `voelker.koenigin_id = p_neue_koenigin_id`. Eine Transaktion.
- **`unique_violation` (23505) abfangen → `BA022`** (deckt den Race ab).

> **Warum die Betriebs-Gleichheitsprüfung statt zweier `kann_schreiben()`-Checks:** `kann_schreiben(b_id)` ist pro Objekt wahr, sobald der Aufrufer in *diesem* Betrieb schreiben darf. Das Datenmodell lässt Mehrbetriebs-Mitgliedschaft zu (`meine_betrieb_ids()` ist `setof`; die Ein-Betrieb-Grenze ist nur ein RPC-Guard, kein Constraint). Ein Dual-Writer bestünde beide Einzelchecks und würde per DEFINER einen Cross-Betrieb-Link erzeugen.

### Fehlercodes — Registry

**BA001–BA013 sind vom Auth-Fundament belegt** (`A06_rpcs.sql`; BA010 = Owner-Berechtigung, BA012 = E-Mail ungültig). Modul 4.2 bekommt einen **eigenen Block ab BA020**; Lücken der Altserie werden **nicht** recycelt.

| Code | Bedeutung |
|---|---|
| `BA020` | Volk nicht gefunden oder gehört nicht zu deinem Betrieb |
| `BA021` | Königin nicht gefunden oder gehört nicht zu deinem Betrieb |
| `BA022` | Königin ist bereits einem anderen Volk zugeordnet |
| `BA023` | Ungültiger Grund für die alte Königin (`ersetzt\|tot\|verschollen`) |

**Registry-Konvention:** BA001–BA013 = Auth-Fundament · BA020+ = Völker/Standorte · je Modul ein neuer Zehnerblock. Im Plan als Prüfschritt: `grep -rn "BA0" supabase/migrations lib` vor jeder neuen RPC.

## 7. App-Schicht (`lib/features/voelker/`)

```
features/voelker/
  domain/        volk.dart · standort.dart · koenigin.dart · betriebs_einstellungen.dart
                 jahresfarbe.dart (reine Funktion) · voelker_gateway.dart (Interface)
  data/          supabase_voelker_gateway.dart · fake_voelker_gateway.dart
  presentation/  providers/voelker_provider.dart
                 pages/voelker_page.dart · volk_detail_page.dart
                 widgets/volk_card.dart · koenigin_section.dart · standort_section.dart · volk_form.dart
```

- **Gateway:** CRUD für die vier Objekte + `umweiseln()`. Völkerliste lädt Standort + Königin **in einem** Select mit Relation (kein N+1). Mappt `BA02x` **und `23505`** (→ BA022-Klartext) auf Klartext — **keine stillen `catch`→`[]`-Fallbacks**.
- **Königin zuordnen:** Direktes Setzen von `koenigin_id` per CRUD ist nur für **freie Königin + königinloses Volk** zulässig. Sobald das Volk eine Königin hat oder die Königin vergeben ist, läuft es über `volk_umweiseln`; die Unique-Verletzung wird als BA022-Klartext gezeigt.
- **Rasse** wird aus der (per Relation geladenen) Königin gelesen. Für weisellose Völker (`koenigin_id IS NULL`) zeigt die UI `betriebs_einstellungen.rasse_default` als gekennzeichnete Vorbelegung — ein weiselloses Volk hat fachlich keine definierte Rasse.
- **Leerzustand Einstellungen:** `betriebsEinstellungenProvider` lädt mit **`maybeSingle()`**; `null` ist ein **legitimer Leerzustand** (kein Fehler, kein `catch`) → `BetriebsEinstellungen.leer()` (alle Defaults null, Offset 0). Formulare funktionieren dann ohne Vorbelegung.
- **⚠ Mandantenwechsel:** Alle vier Provider (`voelkerListProvider`, `standorteProvider`, `koeniginnenProvider`, `betriebsEinstellungenProvider`) **müssen in `AuthController._datenNeuLaden()`** (`lib/features/auth/presentation/auth_providers.dart`) registriert werden. Die Provider sind bewusst **nicht** `autoDispose` und cachen über den Auth-Wechsel hinweg — ohne Registrierung zeigt die App nach Login von Betrieb B weiterhin Völker/Standorte/Königinnen von Betrieb A aus dem Cache (RLS blockt nur den Server-Fetch, nicht den Cache).
- **⚠ Waage-Link:** `scales.volk_id` existiert **DB-seitig**, app-seitig fehlt die Verknüpfung: `lib/features/monitoring/data/models/scale.dart` parst `volk_id` nicht. Dieses Modul erweitert das `Scale`-Model um `volkId` (fromJson/toJson/copyWith) und definiert `scaleFuerVolkProvider(volkId)` (filtert `scalesProvider`, kein Extra-Query, kein DB-Change).
- **Löschen vs. Status:** Realer Abgang (Verlust/Verkauf/Vereinigung/Auflösung) = **Statuswechsel**, Hard-Delete nur für Fehleingaben. Gleiches für Standorte (`status='aufgeloest'` statt DELETE; aufgelöste Stände verschwinden aus der Auswahl, die Völker-Historie bleibt). Die DELETE-Policy bleibt für Bereinigung, die UI bietet sie nicht an.
- **State:** Riverpod `AsyncNotifier` ohne Codegen; Schreibaktionen invalidieren gezielt. `viewer` → read-only (Schreib-Buttons ausgeblendet); RLS bleibt die harte Grenze.
- **Screens:**
  1. `/voelker`: Karten je Volk — Name, Standort, Königin-Jahresfarbe als Punkt, Status-Chip. Liste filtert per Default auf `status='aktiv'`, sortiert nach `sort_order, name`. Empty-State „Erstes Volk anlegen".
  2. `/voelker/:id` — **Drehscheibe**: Sektionen Stammdaten · Königin · Beute · Standort · Waage + **Platzhalter-Sektion „Verlauf — kommt mit Durchsicht/Behandlung"**.
  3. Formulare als Bottom-Sheet/Dialog: Volk anlegen/bearbeiten, Königin anlegen/zuordnen, **Umweiseln** (inkl. „ohne neue Königin" + Grund), Standort verwalten.

> **Navigation (entschieden):** „Völker" wird **primärer Nav-Tab** (die Drehscheibe, an der künftig Durchsicht/Behandlung/Fütterung hängen). „Recherche" + „Entscheidungen" wandern in ein Overflow-/„Mehr"-Menü — Nachschlage-Inhalte, keine Feld-Aktionen am Stand. Die Bottom-Bar bleibt bei 5 handlichen Tabs. Umbau der Nav-Struktur ist Teil dieses Moduls.

## 8. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `C01` | `betriebs_einstellungen` + RLS (**ohne** DELETE) + Trigger + Grants/Revokes; **explizite `betrieb_id`** in `betrieb_gruenden` (additiv); **idempotenter Backfill** für bestehende Betriebe |
| `C02` | `standorte` + `UNIQUE (betrieb_id, id)` + CHECKs + RLS/Trigger/Grants/Indizes |
| `C03` | `koeniginnen` + `UNIQUE (betrieb_id, id)` + CHECKs + komposite Self-FK + RLS/Trigger/Grants/Indizes |
| `C04` | `voelker`: **Leer-Guard**, neue Spalten, **komposite FKs**, CHECKs, `status NOT NULL`, partieller Unique-Index, Drops (`rasse`, `standort`, `koenigin_jahr`), FK-Indizes; **`scales.volk_id` auf Kompositmuster härten** |
| `C05` | RPC `volk_umweiseln` + Grants/Revokes |

Reihenfolge folgt den FK-Abhängigkeiten (`koeniginnen.volk_id` → `voelker` wird in C04 nachgezogen, da beide Tabellen aufeinander zeigen). Jede Migration: Datei unter `supabase/migrations/` **und** via MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-SQL-Test**.

**Advisor-Gate (präzisiert):** `get_advisors(security)` → **0 neue Findings ausserhalb der bekannten, bewussten Klasse** (SECURITY-DEFINER-RPCs erzeugen wie schon beim Auth-Fundament erwartbare 0029-Hinweise). Neue `unindexed_foreign_keys` sind **nicht** akzeptabel — dafür die FK-Indizes in §4.4.

**Ops (keine Migration):** `supabase/ops/seed-arosa-einstellungen.sql` **UPDATE**et die Arosa-Werte auf die von C01 angelegte Zeile: `rasse_default='Buckfast'`, `beutensystem_default='Dadant Blatt 10er'`, `hoehe_default_m=1570`, `saison_offset_default_tage=42`, `kanton='GR'`. **Arosa ist Daten, kein Code.**

**Deploy:** `pubspec` `version:` bumpen → `bash deploy.sh` (manuell).

## 9. Tests

**SQL (Rollback-DO je Migration):**
- Mandanten-Isolation: fremder Betrieb sieht/schreibt weder `standorte`, `koeniginnen` noch erweiterte `voelker`.
- **Same-Tenant-FK:** Insert/Update mit fremder `standort_id`/`koenigin_id` scheitert mit FK-Fehler (23503) — identisch zu einer nicht existierenden UUID (kein Existenz-Orakel).
- **Königin-Eindeutigkeit:** direkter UPDATE, der dieselbe Königin einem zweiten Volk zuordnet, scheitert an `voelker_koenigin_uniq`.
- `betrieb_id`/`created_by` nicht fälschbar.
- `volk_umweiseln`: Erfolgsfall (alte → `p_alt_grund` + `ersetzt_am`, **behält `volk_id`**; neue → `volk_id`/`zugeordnet_am`; `voelker.koenigin_id` umgehängt) · **Erfolgsfall mit `p_neue_koenigin_id = NULL`** (Volk weisellos, alte auf `tot`) · `BA020`/`BA021`/`BA022`/`BA023` · Königin aus fremdem Betrieb → `BA021`.
- `betriebs_einstellungen`: **Auto-Anlage im Gründungspfad mit JWT-Claims OHNE `betrieb_id`** (realistische Simulation!) · Backfill: `count(betriebe) = count(betriebs_einstellungen)` · 1:1 erzwungen · kein DELETE möglich.
- CHECK-Verletzungen (`voelker.status`, `standorte.status`, `koeniginnen.status`, `begattungsart`, `bio_status`, `gesundheitsstatus`).
- `ON DELETE SET NULL`: Stand/Königin löschen lässt Völker leben (und nullt **nicht** `betrieb_id`).
- C04-Leer-Guard greift, wenn `voelker` nicht leer ist.

**Dart:** `jahresfarbe()` (alle 10 Endziffern, inkl. 2026=weiss) · Gateway gegen `FakeVoelkerGateway` (inkl. BA02x- und 23505-Mapping) · **Provider-Test: nach signOut/signIn ist der Cache aller vier Provider invalidiert** · **Formular funktioniert ohne `betriebs_einstellungen`-Zeile (Leerzustand statt Fehler)** · Rollen-Gating (viewer read-only) · `Scale.fromJson` liest `volkId`. `flutter analyze` sauber, alle Tests grün.

## 10. Erweiterungspunkte (bewusst offen gelassen)

| Punkt | Für |
|---|---|
| Platzhalter-Sektion „Verlauf" | 4.3 Durchsicht, 4.5 Behandlungen, 4.6 Fütterung |
| `mutter_koenigin_id`, `begattungsart`, `rasse`/`linie`, `volk_id`/`zugeordnet_am`/`ersetzt_am` | 4.17 Zucht (Stammbaum, Selektion, Leistungsprüfung) |
| `mutter_volk_id`; Weiselzustand-Statuskette | 4.16 Ableger/Schwärme |
| `standorte.status`/`aufgeloest_am`/`kanton`/`amtliche_standnummer`/`sperrbezirk`, `betriebs_einstellungen.imker_identnummer`, `voelker.status`-Abgangswerte | 4.23 Recht & Rückverfolgbarkeit (3-Arbeitstage-Meldung, jährliche Völkererhebung), 4.14 Gesundheit |
| `betriebs_einstellungen` | F4 Settings (Varroa-Schwellen, Winterfutter-Soll, Fristen); **standort-spezifischer Saison-Offset**, falls ein Mandant Stände in verschiedenen Höhen führt |

## 11. Risiken & offene Punkte

- **Spalten-Drops (`rasse`, `standort`, `koenigin_jahr`):** nur zulässig, weil `voelker` leer und kein Code sie referenziert → **doppelt abgesichert**: repo-seitiger `grep` im Plan **und** DB-seitiger Leer-Guard in C04 (§4.4).
- **`betrieb_gruenden` ändern** heisst, eine live genutzte RPC anfassen: rein additiv, mit Rollback-Test, und der Insert übergibt `betrieb_id` **explizit** (§4.1) — sonst bricht jede Neugründung.
- **Zwei Zeiger auf dieselbe Beziehung** (`voelker.koenigin_id` + `koeniginnen.volk_id`): Drift-Risiko ist durch die Regel „Historien-Spur nur vom RPC" (§4.3) und den partiellen Unique-Index gebannt — im Review als Auflage bestätigt.
- **Navigation** entschieden (§7): „Völker" wird primärer Tab, „Recherche"/„Entscheidungen" ins „Mehr"-Menü — Nav-Umbau ist Teil dieses Moduls.
- **Fachliche Richtwerte** (1570 m, Offset 42) sind Betriebsdaten; der Offset ist ein Startwert und wird anhand realer Beobachtung/Stockwaage kalibriert (`02_Recherche/02`).
- **Jahresfarbe** ist bewusst **kein** Mandanten-Parameter (international fixer Zyklus) — Abweichung wäre ein Fehler, keine Konfiguration.
- **Nicht in dieser Spec gelöst:** Die Scope-Spec (§4.5) nennt „Bio-Suisse-Grenzwert 5 mg/kg Wachs vs. Bund 500" — der 500er-Wert liess sich in der Recherche an keiner Primärquelle belegen und wurde dort verworfen. Beim Bau von 4.5 zu korrigieren.
