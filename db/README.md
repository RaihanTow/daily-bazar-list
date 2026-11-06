# Twogether — Database Design

Oracle Database design for the **Twogether** mobile-first household wish-list app (Oracle APEX).

## 1. Naming conventions

All database objects use the `TG$` prefix.

| Object | Pattern | Example |
|---|---|---|
| Table | `TG$<ENTITY>_TAB<NNN>` | `TG$ITEM_TAB001` |
| Sequence | `TG$<ENTITY>_SEQ<NNN>` | `TG$ITEM_SEQ001` |
| View | `TG$<ENTITY>_VW<NNN>` | `TG$ITEM_VW001` |
| Package | `TG$<ENTITY>_PKG` | `TG$ITEM_PKG` |
| Procedure | `TG$<ENTITY>_PRC` | `TG$ITEM_PRC` |
| Function | `TG$<ENTITY>_FUN` | `TG$ITEM_FUN` |
| Trigger | `TG$<ENTITY>_TAB<NNN>_TRG<M>` | `TG$ITEM_TAB001_TRG1` |
| Index | `TG$<ENTITY>_TAB<NNN>_IX<M>` | `TG$ITEM_TAB001_IX1` |
| PK / UK / FK / CK | `<table>_PK`, `<table>_UK<M>`, `<table>_FK<M>`, `<table>_CK<M>` | `TG$ITEM_TAB001_PK` |
| Type | `TG$<ENTITY>_TYP` | `TG$ITEM_TYP` |
| Synonym | `TG$<ENTITY>_SYN` | `TG$ITEM_SYN` |
| Materialized view | `TG$<ENTITY>_MV<NNN>` | `TG$ITEM_MV001` |

**Assumption:** the 3-digit number is appended after the type suffix (`_TAB001`, `_SEQ001`). If you prefer `_TAB_001`, we can rename globally.

## 2. Required columns on every table

| Column | Type | Purpose |
|---|---|---|
| `STAMPUSER` | `VARCHAR2(255)` | Last user who changed the row |
| `STAMPDATE` | `TIMESTAMP WITH TIME ZONE` | Last change timestamp |
| `CREATEDDATE` | `TIMESTAMP WITH TIME ZONE` | Row creation timestamp |
| `CREATEDBY` | `VARCHAR2(255)` | Row creator |
| `ACCESSCODE` | `VARCHAR2(30)` | Household/tenant discriminator; `GLOBAL` on setup rows |

These are maintained by one `BEFORE INSERT OR UPDATE` trigger per table.

## 3. Recommended additional standard columns

| Column | Type | Where | Why |
|---|---|---|---|
| `UUID` | `RAW(16)` | All tables | Alternate key for offline/mobile sync, imports, deep links. **Not the PK.** |
| `VERSIONNO` | `NUMBER(10)` | All tables | Optimistic locking; incremented by trigger |
| `ISDELETED` | `CHAR(1)` | All tables | Soft delete (`Y`/`N`) |
| `DELETEDDATE`, `DELETEDBY` | `TIMESTAMP WITH TIME ZONE`, `VARCHAR2(255)` | Data tables | Audit of soft delete |
| `ISACTIVE` | `CHAR(1)` | Setup tables | Enable/disable a lookup value |
| `ISDEFAULT` | `CHAR(1)` | Setup tables | Default lookup value |
| `SORTNO` | `NUMBER(10)` | Setup tables | Display order |
| `STATUSCODE` | `VARCHAR2(30)` | Data tables | Lifecycle state (FK to `TG$STATUS_TAB001`) |
| `SRC_SYSTEM`, `SRC_ID` | `VARCHAR2(30)`, `VARCHAR2(100)` | Optional | Integration lineage |
| `HASH` | `VARCHAR2(64)` | Optional | Change detection for mobile sync |
| `LOCALE`, `TIMEZONE`, `CURRENCYCODE` | `VARCHAR2` | Optional | Localisation |
| `EFFECTIVE_FROM`, `EFFECTIVE_TO` | `DATE` | Optional | Validity window for setup rows |

**Why not UUID as the primary key?** Oracle indexes on random `RAW(16)` values fragment and cluster poorly. Keep the numeric `RSN` as PK and `UUID` as a unique alternate key.

## 4. Key strategy: CODE vs RSN vs UUID

| Key | Used by | Meaning |
|---|---|---|
| `CODE` | Setup tables | Stable, human-readable business key. Portable across environments. |
| `RSN` | Data tables | Record Serial Number — compact numeric surrogate PK from a `_SEQ` sequence. |
| `UUID` | All tables | Environment-independent unique ID for sync, import and external references. |
| Business code (`ACCESSCODE`, `MEMBERCODE`, `LISTCODE`, `ITEMCODE`) | Data tables | Human-friendly unique key scoped by `ACCESSCODE`, useful for DML and imports. |

## 5. Table inventory

| Table | Type | PK | Purpose |
|---|---|---|---|
| `TG$STATUS_TAB001` | Setup | `CODE` | Lifecycle statuses (ACTIVE, DONE, CANCELLED, ARCHIVED) |
| `TG$PRIORITY_TAB001` | Setup | `CODE` | Priority levels with colour/icon |
| `TG$UOM_TAB001` | Setup | `CODE` | Units of measure |
| `TG$CATEGORY_TAB001` | Setup | `CODE` | Item categories |
| `TG$ROLETYPE_TAB001` | Setup | `CODE` | Household roles (OWNER, MEMBER) |
| `TG$SETTING_TAB001` | Setup | `CODE` | Application settings (key/value) |
| `TG$ACCESS_TAB001` | Data | `RSN` | Household/couple access group |
| `TG$MEMBER_TAB001` | Data | `RSN` | Members of a household |
| `TG$LIST_TAB001` | Data | `RSN` | A shopping/wish list |
| `TG$ITEM_TAB001` | Data | `RSN` | Wish-list items with priority and due date |
| `TG$ITEM_HISTORY_TAB001` | Data | `RSN` | Change history for items (JSON snapshots) |

## 6. ACCESSCODE and security

`ACCESSCODE` identifies the couple/household that owns a row.

- Setup tables default to `GLOBAL` so configuration is shared.
- Data tables must always carry the owning `ACCESSCODE`, with an FK to `TG$ACCESS_TAB001(ACCESSCODE)`.
- Enforce isolation with either:
  - a VPD/RLS policy on data tables, or
  - an APEX authorization + `WHERE ACCESSCODE = :APP_ACCESSCODE` in every view/query.
- Never let APEX users query base tables directly; expose filtered views or packages.

If per-tenant setup overrides are needed later, change setup PKs to `(CODE, ACCESSCODE)` or add a dedicated override table.

## 7. Audit and triggers

- One `BEFORE INSERT OR UPDATE` trigger per table sets `STAMPUSER`, `STAMPDATE`, `CREATEDBY`, `CREATEDDATE`, `VERSIONNO` and, on data tables, `RSN`/`UUID`.
- The current user is read from `SYS_CONTEXT('APEX$SESSION','APP_USER')`, falling back to `USER` outside APEX.
- On update, `CREATEDBY`/`CREATEDDATE`/`RSN`/`UUID`/`ACCESSCODE` are preserved and `VERSIONNO` is incremented.
- `TG$ITEM_TAB001_TRG2` writes a JSON snapshot to `TG$ITEM_HISTORY_TAB001` on insert/update/delete.

## 8. Soft delete

Applications must set `ISDELETED = 'Y'`, `DELETEDDATE`, `DELETEDBY` instead of issuing `DELETE`. Views filter `ISDELETED = 'N'`.

## 9. Execution order

1. `ddl/001_setup_tables.sql`
2. `ddl/002_core_tables.sql`
3. `ddl/003_sequences.sql`
4. `ddl/004_setup_triggers.sql`
5. `ddl/005_data_triggers.sql`
6. `ddl/006_history_trigger.sql`
7. `ddl/007_views.sql`
8. `dml/001_setup_data.sql`
9. `dml/002_sample_data.sql`

Run DDL as the application schema owner. Setup DML must run before sample data because of FK dependencies.

## 10. Assumptions and next steps

- Assumes Oracle 12.2+ (128-character object names, `JSON_OBJECT`) and APEX 20+.
- Not included yet: VPD policy package, APEX application, grants/synonyms, unit tests, migration tooling (Flyway/Liquibase).
- Ask before using `TIMESTAMP WITH TIME ZONE` vs `DATE` if your APEX version or DBA standard differs.
