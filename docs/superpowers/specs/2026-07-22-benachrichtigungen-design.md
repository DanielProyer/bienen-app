# F3 — Benachrichtigungen: täglicher Überblick via Telegram

**Datum:** 2026-07-22 · **Track:** App (+ Produktions-Migration + Edge Function) · **Status:** Design freigegeben (Abschnitte 1–3), Spec zur Review
**Modell-Strategie:** Migration (Extensions + RLS) → **Fable 5 hoch**, separat freizugeben · Edge Function + Einstellungs-UI → Opus 4.8.

---

## 1. Ziel & Kontext

Der Saison-Generator (36 Regeln) und die Vermehrungs-Ketten erzeugen laufend terminierte Aufgaben — Schwarmkontrolle alle 7 Tage, Behandlungsfenster, Weiselkontrolle Tag 25–30. **Nichts davon erinnert Daniel**; er muss die App aktiv öffnen. Bei Modul 4.4 wurde Push bewusst weggelassen, weil F3 fehlte. Mitten in der Saison ist das der größte praktische Hebel: Termine, die niemand ausspricht, werden verpasst.

**Ziel:** Eine verlässliche Morgen-Nachricht per Telegram mit dem, was heute ansteht und was liegengeblieben ist.

### Zwei Befunde, die die Architektur bestimmt haben
- **Web-Push scheidet aus.** `web/index.html` **entfernt bei jedem Laden alle Service Worker** („Service Workers killen") — Teil des hart erkämpften Versions-/Cache-Mechanismus. Web-Push braucht zwingend einen Service Worker; man müsste also ausgerechnet an dem Mechanismus sägen, der in diesem Projekt wiederholt schmerzhaft war. Dazu: auf iOS nur mit Homescreen-Installation, und das PWA-Manifest ist noch der unveränderte Flutter-Standard.
- **Es gab keinen Datenbank-Scheduler.** Installiert waren nur `pg_stat_statements`, `pgcrypto`, `plpgsql`, `supabase_vault`, `uuid-ossp` — **kein `pg_cron`, kein `pg_net`**. Der in der Memory notierte 15-Minuten-Cron für `sync-scale-data` war nie scharf. Beide Erweiterungen werden hier erstmals aktiviert.

### Grundhaltung
- **Mandantenfähig**, keine Arosa-Hardcodes: Empfänger, Sendezeit und **Zeitzone** sind Einstellungen je Mitglied, keine Konstanten.
- **Stille ist eine Aussage** — gibt es nichts zu tun, kommt nichts. Genau deshalb muss die App zeigen, wann zuletzt gesendet wurde (siehe §7).

---

## 2. Scope & YAGNI

**In Scope (v1):** ein täglicher Überblick je Mitglied via Telegram; Einstellungen (Chat-ID, aktiv, Sendestunde, Zeitzone) in der App; Testnachricht-Knopf; stündlicher Cron mit Zeitzonen-/Doppelversand-Logik.

**Bewusst NICHT:**
- **Web-Push und E-Mail** (Begründung oben; E-Mail bräuchte zusätzlich einen Versanddienst)
- **Rückkanal/Quittieren aus Telegram** — bräuchte einen eingehenden Webhook; die Nachricht verlinkt stattdessen in die App
- **Automatische Chat-ID-Verknüpfung per Deep-Link** — ebenfalls Webhook; v1 trägt die ID von Hand ein
- **Sofort-Alarme** (Meldepflicht, Schwarm-Alarm der Waage) — dieselbe Schiene, aber erst sinnvoll mit 4.9/Hardware
- **Ruhezeiten-Engine** — bei genau einer Nachricht am Morgen gegenstandslos

---

## 3. Architektur

```
pg_cron (stündlich)  →  pg_net.http_post  →  Edge Function `taeglicher-ueberblick`
                                                 ├─ liest Einstellungen + Aufgaben (Service-Key)
                                                 ├─ entscheidet je Mitglied: jetzt fällig?
                                                 └─ POST an Telegram Bot API
```

**Warum die Logik in der Edge Function und nicht in plpgsql:** Textaufbereitung in SQL wird unleserlich, und der Bot-Token läge in der Datenbank. In der Function ist die Logik lesbar und testbar, der Token bleibt ein Function-Secret.

**Warum stündlich statt einmal täglich (der wichtigste Punkt):** `pg_cron` plant in **UTC**. Ein fester UTC-Termin verrutscht durch die Sommer-/Winterzeit zweimal jährlich um eine Stunde. Deshalb läuft der Job **stündlich** (z. B. `5 * * * *`), und die Function prüft je Mitglied:

> „Ist es in dessen `zeitzone` gerade `sende_stunde` **und** ist `zuletzt_gesendet_am` nicht heute?"

Das hält die Uhrzeit ganzjährig korrekt, erlaubt unterschiedliche Zeiten je Person, und **schließt Doppelversand aus**.

---

## 4. Datenmodell

**Neue Tabelle `benachrichtigungs_einstellungen`** (eine Zeile je Mitglied und Betrieb):

| Spalte | Bedeutung |
|---|---|
| `betrieb_id` | NOT NULL, Default `private.aktive_betrieb_id()` |
| `user_id` | das Mitglied |
| `kanal` | text, CHECK `('telegram')` — Platz für spätere Kanäle |
| `telegram_chat_id` | text, nullable bis verknüpft |
| `aktiv` | boolean, **Default false** (fail-safe: erst nach erfolgreicher Verknüpfung an) |
| `sende_stunde` | smallint 0–23, Default 6 |
| `zeitzone` | text, Default `'Europe/Zurich'` (Einstellung, kein Hardcode) |
| `zuletzt_gesendet_am` | date — der Doppelversand-Riegel |
| `created_by`/`updated_by`/`created_at`/`updated_at` | Standard-Muster + `set_row_actor` |
| `unique (betrieb_id, user_id)` | eine Einstellung je Mitglied |

**RLS — bewusste Abweichung vom Hausmuster:** Sonst gilt „Mitglied sieht alles vom Betrieb". Hier **nicht**: SELECT/INSERT/UPDATE nur für die **eigene** Zeile (`user_id = private.current_app_user()` **und** Mitglied im Betrieb). Eine Chat-ID ist personenbezogen — Lorena darf Daniels ID nicht lesen und umgekehrt. Die Edge Function liest mit dem Service-Key an der RLS vorbei; das ist ihr Zweck.

**Kein neuer Errcode-Block** (kein RPC, reines CRUD) — **BA050 bleibt frei**.

---

## 5. Telegram-Verknüpfung

**Ein Bot für die ganze App** (einmalig bei @BotFather angelegt); der Token ist ein Function-Secret, kein Nutzer-Geheimnis.

Ablauf je Person: Telegram verlangt, dass der Mensch dem Bot **zuerst schreibt** (sonst darf der Bot nicht senden). Danach besorgt sich die Person ihre Chat-ID (z. B. über @userinfobot) und trägt sie in den App-Einstellungen ein. Hemdsärmelig, aber ohne eingehenden Webhook der ehrlichste Weg.

**Testnachricht-Knopf:** Sofort nach dem Eintragen prüfbar, ob die Verknüpfung sitzt — statt bis zum nächsten Morgen zu warten. Erfolg setzt `aktiv = true`.

---

## 6. Inhalt der Nachricht

```
🐝 Dienstag, 23. Juli

Heute fällig
• Schwarmkontrolle · Volk 1
• Gemülldiagnose · Volk 1

Überfällig
• Drohnenschnitt · Volk 1 (seit 3 Tagen)

→ In der App öffnen
```

- Auswahl: offene Aufgaben mit `faellig_am <= heute` (in der Zeitzone des Mitglieds), getrennt nach *heute* und *überfällig*, mit Volk-Name.
- **Nichts zu tun → keine Nachricht.**
- Mehr als 10 Einträge werden gekürzt („…und N weitere").
- Am Ende ein Link auf `/aufgaben`.

**Kaum doppelte Logik:** Die Auswahl ist eine WHERE-Bedingung, keine Geschäftslogik. Die komplexe Gruppierung (`aufgaben_gruppierung.dart`) bleibt der App vorbehalten und wird **nicht** gespiegelt.

---

## 7. Sicherheit & Fehlerverhalten

**Geheimnisse:** `TELEGRAM_BOT_TOKEN` und `CRON_SHARED_SECRET` als **Edge-Function-Secrets**; das Shared Secret zusätzlich im **Vault**, damit der Cron-Job es lesen kann. Nichts davon in Repo, Datenbank-Klartext oder Chat.

**Zwei Eingänge, strikt getrennt:**
| Aufruf | Legitimation | Wirkung |
|---|---|---|
| Cron | `CRON_SHARED_SECRET` im Header | Versand an **alle** fälligen Mitglieder |
| App (eingeloggt) | JWT des Nutzers | **nur** Testnachricht an die **eigene** Zeile |

Bewusst **nicht** der Service-Key für den Cron-Aufruf: `pg_net` legt Anfragen samt Headern in einer Tabelle ab — ein Zweck-Schlüssel hat dort den kleineren Schaden als der Generalschlüssel.

**Fehlerverhalten**
| Fall | Verhalten |
|---|---|
| Telegram nicht erreichbar | `zuletzt_gesendet_am` bleibt unverändert → der nächste Stundenlauf versucht es **am selben Tag** erneut (Selbstheilung, kein Doppelversand) |
| Bot blockiert (403) | `aktiv = false` statt endlos gegen eine Wand zu senden; in der App sichtbar |
| Einzelnes Mitglied schlägt fehl | die übrigen werden trotzdem bedient |
| Nichts zu tun | kein Versand, `zuletzt_gesendet_am` **trotzdem** gesetzt (der Tag gilt als erledigt) |

**Die ehrliche Schwäche:** „Nichts zu tun → keine Nachricht" macht **Stille zweideutig** — sie kann „alles erledigt" oder „Versand kaputt" heißen. Gegenmaßnahme: die Einstellungen zeigen **„zuletzt gesendet: TT.MM."**. Ohne das würde ein Ausfall erst auffallen, wenn ein Termin bereits verpasst ist.

---

## 8. Migration (Produktion — separat freizugeben)

`O01_benachrichtigungen.sql`:
1. `create extension if not exists pg_cron;` und `pg_net` (erstmalige Aktivierung auf dieser DB)
2. Tabelle `benachrichtigungs_einstellungen` + `set_row_actor`-Trigger + RLS-Policies (eigene Zeile, siehe §4)
3. Shared Secret im Vault ablegen (Wert setzt Daniel, nicht im Migrations-File)
4. `cron.schedule('ueberblick-stuendlich', '5 * * * *', …)` → `net.http_post` auf die Function-URL mit dem Shared-Secret-Header

`get_advisors(security)` + `(performance)` → **0 neue** Findings. Rollback-Kommentar im File (`cron.unschedule`, `drop table`, Extensions bewusst **nicht** zurückdrehen).

---

## 9. Tests

- **Rein (Deno/TypeScript):** der Textbau (Aufgabenliste → Nachricht) — heute/überfällig, Kürzung ab 10, leere Liste → keine Nachricht; und die Fälligkeits-Entscheidung (Zeitzone + `sende_stunde` + `zuletzt_gesendet_am`), inklusive eines Sommer-/Winterzeit-Falls.
- **Flutter:** Einstellungs-Provider/UI (Chat-ID speichern, aktiv-Schalter, „zuletzt gesendet"-Anzeige).
- **Migration:** manuell mit O01 — Extensions da, Cron-Job gelistet, RLS-Probe (fremde Zeile nicht lesbar), Advisors 0 neu.
- **Der echte Beweis:** die Testnachricht.

---

## 10. Was Daniel selbst erledigt (Zugangsdaten werden nicht von Claude eingegeben)
1. Bot bei **@BotFather** anlegen → Token. *(Der zwischenzeitlich im Chat geteilte Token gilt als kompromittiert und ist per `/revoke` zu ersetzen.)*
2. `TELEGRAM_BOT_TOKEN` und ein selbst erzeugtes `CRON_SHARED_SECRET` als Supabase-Secrets hinterlegen
3. Dem Bot einmal schreiben, Chat-ID besorgen, in den Einstellungen eintragen → **Testnachricht**
4. Die Produktions-Migration **O01** freigeben

---

## 11. Offen (spätere Zyklen)
- Sofort-Alarme (Meldepflicht, Schwarm-Alarm) auf derselben Schiene — mit 4.9/Waage
- Automatische Chat-ID-Verknüpfung per Deep-Link + eingehendem Webhook; Quittieren aus Telegram
- E-Mail als zweiter Kanal (`kanal`-Spalte ist dafür vorbereitet)
- Wochenvorschau statt nur „heute + überfällig"
