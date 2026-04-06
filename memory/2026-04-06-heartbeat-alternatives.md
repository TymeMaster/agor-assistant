# PM Heartbeat Alternatives — Analýza a rozhodnutí

> **Datum:** 2026-04-06
> **Kontext:** 3-layer orchestration model (Opus orchestrator → Sonnet PM/TL → Codex/Sonnet workers)
> **Problém:** PM potřebuje periodický "tick" impuls ke kontrole TL sessions. Všechny in-session timer mechanismy selhaly (Exp.4).

---

## Pozadí problému

PM role v orchestračním modelu funguje jako heartbeat controller — periodicky kontroluje Team Leady, zda postupují, a pushuje ty, kteří stagnují. Exp.4 (2026-04-04) ověřil, že žádný dostupný timer mechanismus nefunguje:

| Mechanismus | Výsledek | Příčina selhání |
|-------------|----------|-----------------|
| `CronCreate` (session-scoped) | NEFUNKČNÍ | Joby se vytvoří ale nikdy nefirují, zmizí |
| `CronCreate durable:true` | NEFUNKČNÍ | Ignoruje durable flag |
| `RemoteTrigger` | NEPOUŽITELNÝ | HTTP 500 + nemá přístup k lokálnímu Agor MCP |
| `/loop` skill | NEFUNKČNÍ | Wrapper nad CronCreate, stejný problém |
| Agor `schedule_enabled` | NEIMPLEMENTOVÁNO | Pole existuje na worktrees, chybí MCP API |

**Kořenová příčina:** `CronCreate` vyžaduje REPL v idle stavu. V Agor-managed sessions se tento stav buď nedosahuje, nebo joby předčasně expirují. `RemoteTrigger` běží v Anthropic cloudu a nemá přístup k lokálnímu Agor MCP.

---

## Soupis alternativ

### A. Event-driven (push model) — eliminace potřeby timeru

#### A1. TL self-reporting po každém sub-tasku
- **Princip:** TL po dokončení každého worker tasku sám promptne PM session s hlášením (`agor_sessions_prompt`)
- **Změna:** Do TL prompt template přidat instrukci reportovat PM po každém tasku
- **Pro:** Žádný timer, PM se aktivuje přirozeně s postupem práce, nízký token cost
- **Proti:** Nedetekuje stall (pokud TL zamrzne, žádný event nepřijde)
- **Proveditelnost:** Vysoká — ověřené API (Exp.2, Exp.3)

#### A2. Callback chain přes Opus
- **Princip:** TL sessions mají `enableCallback=true`. Každý callback do Opus = příležitost zkontrolovat i ostatní TLs
- **Změna:** Opus po přijetí jakéhokoli callbacku automaticky provede mini-heartbeat (check all TLs)
- **Pro:** Žádná nová session, žádný timer, organicky se děje během práce
- **Proti:** Opus token burn navíc; pokud všechny TLs mlčí, žádný trigger
- **Proveditelnost:** Vysoká — ale porušuje princip D1 (Opus token optimization)

#### A3. Zone trigger jako event source
- **Princip:** Board zóny mají `trigger` field + `triggerTemplate`. Přesun worktree do zóny = automatický prompt do cílové session
- **Použití:** TL po dokončení tasku přesune worktree do odpovídající zóny → zone trigger pošle prompt PM session
- **Pro:** Vizuální workflow na boardu + automatický trigger v jednom
- **Proti:** Zone triggers mají známé bugy (preset-io/agor#352: execution issues, settings mismatch, no re-trigger); TL musí aktivně přesouvat worktree
- **Proveditelnost:** Nízká (aktuálně) — zone trigger mechanismus je buggy, nespolehlivý pro produkční orchestraci

---

### B. Eliminace PM role

#### B4. PM merge do Opus (opportunistic monitoring)
- **Princip:** PM jako samostatná session zmizí. Opus při každé interakci (callback, human prompt) zkontroluje všechny TLs
- **Změna:** Opus prompt rozšířit o "při každém callbacku zkontroluj stav všech aktivních TLs"
- **Pro:** Jednodušší architektura, žádná PM session, žádný timer problém
- **Proti:** Opus token burn roste; Opus přestává být "thin passive layer"
- **Proveditelnost:** Vysoká — ale porušuje design princip D1 (token optimization je primary constraint)

#### B5. TL peer-monitoring (decentralizovaný PM)
- **Princip:** Každý TL po dokončení svého tasku zkontroluje i ostatní TL sessions
- **Změna:** TL prompt rozšířit o seznam session IDs ostatních TLs + instrukci "zkontroluj peer TLs"
- **Pro:** Žádný PM, žádný timer, monitoring je distribuovaný
- **Proti:** TLs nemají znát ostatní (porušuje izolaci); komplexní prompt; extra token burn
- **Proveditelnost:** Střední — technicky funguje, architektonicky sporné

---

### C. Externí timer (mimo Claude session)

#### C6. Linux system cron + Agor API
- **Princip:** System-level cron job volá `agor_sessions_prompt` přes Agor REST API (curl)
- **Implementace:** `*/10 * * * * curl -X POST agor.live/api/sessions/<PM_ID>/prompt -d '{"prompt":"heartbeat"}'`
- **Pro:** Spolehlivý, nezávislý na Claude session lifecycle, plně automatický
- **Proti:** Vyžaduje Agor REST API auth token + endpoint dokumentaci; údržba mimo ekosystém; auth token management
- **Proveditelnost:** Střední — závisí na dostupnosti a stabilitě Agor REST API pro external callers

#### C7. Human timer (low-tech)
- **Princip:** Člověk si nastaví phone/calendar reminder a manuálně triggeruje PM
- **Pro:** Nulový engineering, 100% spolehlivost, human zůstává in the loop
- **Proti:** Ruční práce; nescaluje; závisí na dostupnosti člověka
- **Proveditelnost:** Okamžitá

---

### E. Oprava zdrojového problému (Agor platform)

#### E1. GitHub issue: Request native session scheduling v Agor MCP
- **Princip:** Nahlásit chybějící funkcionalitu jako feature request do preset-io/agor
- **Scope:** Požadavek na MCP tool typu `agor_sessions_schedule(sessionId, cron, prompt)` — platforma nativně triggeruje prompt do session na základě cron výrazu
- **Kontext:** Pole `schedule_enabled` na worktrees již existuje (naznačuje plánovanou funkci), ale chybí MCP API
- **Relevantní existující issues:**
  - preset-io/agor#352 — Zone triggers: execution issues (buggy trigger mechanismus)
  - preset-io/agor#104 — feat: notifications and hooks (obecný request na event/hook systém)
- **Pro:** Řeší problém systémově, benefituje celou komunitu, je to "správné" místo pro řešení
- **Proti:** Závisí na prioritizaci Agor týmu; timeline neznámý; neřeší akutní potřebu
- **Proveditelnost:** Issue lze vytvořit okamžitě; realizace závisí na Agor roadmap
- **Akce:** Vytvořit issue s odkazem na Exp.4 výsledky a use case popis

#### E2. Vlastní fix/PR do Agor codebase
- **Princip:** Implementovat session scheduling přímo v Agor kódu a otevřít PR
- **Scope:** Doimplementovat `schedule_enabled` worktree field → propojit s cron systémem v Agor backendu
- **Pro:** Plná kontrola nad implementací; rychlejší než čekat na Agor tým
- **Proti:** Vyžaduje znalost Agor internals; review/merge závisí na maintainerech; může kolidovat s jejich roadmap
- **Proveditelnost:** Střední až nízká — závisí na contributor-friendliness Agor codebase a komplexitě scheduling subsystému
- **Akce:** Nejprve E1 (issue), pak nabídnout PR pokud bude zájem

#### E3. Workaround: CronCreate fix investigation
- **Princip:** Prozkoumat proč CronCreate nefiruje v Agor sessions — je to bug v Claude Code, nebo v Agor session lifecycle?
- **Hypotéza:** Agor sessions možná nikdy nedosáhnou "REPL idle" stavu potřebného pro cron fire
- **Akce:** Otevřít issue v claude-code repo (pokud je bug na jejich straně) nebo v Agor (pokud Agor session lifecycle blokuje idle stav)
- **Proveditelnost:** Střední — vyžaduje hlubší diagnostiku

---

## Srovnávací matice

| Varianta | Timer nutný | Token cost | Stall detection | Složitost | Proveditelnost | Timeline |
|----------|:-----------:|:----------:|:---------------:|:---------:|:--------------:|:--------:|
| A1 TL self-report | Ne | Nízký | Ne | Nízká | Vysoká | Dny |
| A2 Opus callback | Ne | Vysoký | Ne | Nízká | Vysoká | Dny |
| A3 Zone trigger | Ne | Nízký | Ne | Střední | Nízká (bugy) | ? |
| B4 PM→Opus merge | Ne | Vysoký | Ne | Nízká | Vysoká | Dny |
| B5 Peer monitoring | Ne | Vysoký | Částečně | Vysoká | Střední | Dny |
| C6 System cron | Ano (OS) | Nízký | Ano | Střední | Střední | Týdny |
| C7 Human timer | Ano (člověk) | Nízký | Ano | Nulová | Okamžitá | Hned |
| **D8 = A1+C7** | **Částečně** | **Nízký** | **Ano** | **Nízká** | **Vysoká** | **Dny** |
| D9 = A1+A3 | Ne | Nízký | Ne | Střední | Nízká (bugy) | ? |
| E1 Agor issue | — | — | Ano | Nulová | Okamžitá (issue) | ? (fix) |
| E2 Agor PR | — | — | Ano | Vysoká | Střední | Týdny–měsíce |
| E3 CronCreate fix | — | — | Ano | Střední | Střední | ? |

---

## Rozhodnutí

### Zvolená cesta: D8 (TL self-report + human fallback)

**Krátkodobě (implementovat teď):**
1. **A1 — TL self-reporting:** Upravit TL prompt template — TL po každém dokončeném worker tasku sám volá `agor_sessions_prompt` na PM session se status reportem
2. **C7 — Human timer jako fallback:** Pro stall detection — human trigger PM každých 15-20 min (nebo Opus po callbacku)
3. PM se mění z periodického polleru na **reaktivní event processor**

**Střednědobě (paralelně):**
4. **E1 — GitHub issue do Agor:** Nahlásit potřebu native session scheduling s referencí na Exp.4 výsledky. Preferovaný směr pro systémové řešení
5. Sledovat vývoj preset-io/agor#352 (zone triggers) a preset-io/agor#104 (hooks/notifications)

**Dlouhodobě (pokud E1 neuspěje):**
6. **C6 — System cron:** Jako vlastní workaround implementovat Linux cron + Agor API volání, pokud Agor tým neposkytne nativní řešení

### Změny v prompt templates

**TL prompt — přidat po sekci "How to Work":**
```
## PM Status Reporting
After completing each worker task (step 2f), report to PM:
  agor_sessions_prompt(
    sessionId: "[PM_SESSION_ID]",
    mode: "continue",
    prompt: "TL report: [AREA_NAME] — Task [N]/[TOTAL] complete. Status: [DONE/BLOCKED/IN_PROGRESS]. Details: [brief summary]"
  )
This is mandatory. PM relies on your reports to track progress.
```

**PM prompt — přidat změnu modelu:**
```
## Activation Model
You are EVENT-DRIVEN, not periodic. You activate when:
1. A TL sends you a status report (normal flow)
2. Human or Opus triggers you for stall detection sweep (fallback)

When activated by TL report: process the report, update your internal state, respond only if action needed.
When activated by human/Opus: run full sweep of all TLs (check agor_sessions_get for each).
```

---

## Otevřené otázky

1. **Agor REST API auth:** Je k dispozici pro external callers (pro budoucí C6)?
2. **`schedule_enabled` field:** Je na Agor roadmap? Stojí za to se ptát v issue?
3. **Zone trigger reliability:** Kdy bude preset-io/agor#352 opraven? Pokud brzy, A3 se stává životaschopnou
