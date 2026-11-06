# Twogether — Database Design

Oracle Database design for the **Twogether** mobile-first household wish-list app (Oracle APEX).

## 1. Naming conventions

All database objects use the `TG$` prefix and follow `TG$<ENTITY>_<OBJECT_TYPE>`.

| Object | Pattern | Example |
|---|---|---|
| Table | `TG$<ENTITY>_TAB` | `TG$ITEM_TAB` |
| Valid / lookup table | `TG$VALID_<ENTITY>_TAB` | `TG$VALID_STATUS_TAB` |
| Sequence | `TG$<ENTITY>_SEQ` | `TG$ITEM_SEQ` |
| View | `TG$<ENTITY>_VW` | `TG$ITEM_VW` |
| Package | `TG$<ENTITY>_PKG` | `TG$ITEM_PKG` |
| Procedure | `TG$<ENTITY>_PRC` | `TG$ITEM_PRC` |
| Function | `TG$<ENTITY>_FUN` | `TG$ITEM_FUN` |
| Trigger | `TG$<ENTITY>_TAB_TRG<M>` | `TG$ITEM_TAB_TRG1` |
| Index | `TG$<ENTITY>_TAB_IX<M>` | `TG$ITEM_TAB_IX1` |
| PK / UK / FK / CK | `<table>_PK`, `<table>_UK<M>`, `<table>_FK<M>`, `<table>_CK<M>` | `TG$ITEM_TAB_PK` |
| Type | `TG$<ENTITY>_TYP` | `TG$ITEM_TYP` |
| Synonym | `TG$<ENTITY>_SYN` | `TG$ITEM_SYN` |
| Materialized view | `TG$<ENTITY>_MV` | `TG$ITEM_MV` |

**Valid tables** carry a numeric `<ENTITY>CODE` (primary key, assigned from `TG$VALID_<ENTITY>_SEQ`) and a unique `<ENTITY>DESC` (display text), plus the same standard columns as every other table (audit, `UUID`, `ACCESSCODE`, `DISPLAYORDER`, `ISACTIVE`, `ISDEFAULT`, `ISDELETED`). Entity-specific attributes may be added when the lookup needs them: `TG$VALID_PRIORITY_TAB` also keeps `PRIORITYNO`, `COLORCODE` and `ICONCODE`.

```sql
CREATE TABLE TG$VALID_STATUS_TAB (
  STATUSCODE    NUMBER(19)    NOT NULL,
  STATUSDESC    VARCHAR2(200) NOT NULL,
  DESCRIPTION   VARCHAR2(4000),
  DISPLAYORDER  NUMBER(10)    DEFAULT 0 NOT NULL,
  ISACTIVE      CHAR(1)       DEFAULT 'Y' NOT NULL,
  ISDEFAULT     CHAR(1)       DEFAULT 'N' NOT NULL,
  UUID          RAW(16)       DEFAULT SYS_GUID() NOT NULL,
  ACCESSCODE    VARCHAR2(30)  DEFAULT 'GLOBAL' NOT NULL,
  STAMPUSER     VARCHAR2(255) NOT NULL,
  STAMPDATE     TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  STAMPSESSION  VARCHAR2(4000) DEFAULT SYS_CONTEXT('APEX$SESSION','APP_SESSION'),
  CREATEDDATE   TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CREATEDBY     VARCHAR2(255) NOT NULL,
  CREATESESSION VARCHAR2(4000) DEFAULT SYS_CONTEXT('APEX$SESSION','APP_SESSION'),
  APPID         VARCHAR2(100)  DEFAULT SYS_CONTEXT('APEX$SESSION','APP_ID'),
  VERSIONNO     NUMBER(10)    DEFAULT 1 NOT NULL,
  ISDELETED     CHAR(1)       DEFAULT 'N' NOT NULL,
  CONSTRAINT TG$VALID_STATUS_TAB_PK  PRIMARY KEY (STATUSCODE),
  CONSTRAINT TG$VALID_STATUS_TAB_UK1 UNIQUE (UUID),
  CONSTRAINT TG$VALID_STATUS_TAB_UK2 UNIQUE (STATUSDESC),
  CONSTRAINT TG$VALID_STATUS_TAB_CK1 CHECK (ISACTIVE  IN ('Y','N')),
  CONSTRAINT TG$VALID_STATUS_TAB_CK2 CHECK (ISDEFAULT IN ('Y','N')),
  CONSTRAINT TG$VALID_STATUS_TAB_CK3 CHECK (ISDELETED IN ('Y','N'))
);
```

`TG$VALID_STATUS_TAB_TRG1` assigns `STATUSCODE` from `TG$VALID_STATUS_SEQ` when it is not supplied.

## 2. Required columns on every table

Every table carries these columns:

| Column | Type | Purpose |
|---|---|---|
| `STAMPUSER` | `VARCHAR2(255)` | Last user who changed the row |
| `STAMPDATE` | `TIMESTAMP WITH TIME ZONE` | Last change timestamp |
| `STAMPSESSION` | `VARCHAR2(4000)` | APEX session (`APP_SESSION`) of the last change |
| `CREATEDDATE` | `TIMESTAMP WITH TIME ZONE` | Row creation timestamp |
| `CREATEDBY` | `VARCHAR2(255)` | Row creator |
| `CREATESESSION` | `VARCHAR2(4000)` | APEX session (`APP_SESSION`) that created the row |
| `APPID` | `VARCHAR2(100)` | APEX application ID (`APP_ID`) the row was created through |
| `ACCESSCODE` | `VARCHAR2(30)` | Household/tenant discriminator; `GLOBAL` on setup rows |

The APEX values are available as column `DEFAULT`s (`SYS_CONTEXT('APEX$SESSION', ...)`) for direct inserts, and are re-applied by the audit trigger. Outside an APEX session they are `NULL`, while `STAMPUSER`/`CREATEDBY` fall back to `USER`.

These are maintained by one `BEFORE INSERT OR UPDATE` trigger per table.

## 3. Recommended additional standard columns

| Column | Type | Where | Why |
|---|---|---|---|
| `UUID` | `RAW(16)` | All tables | Alternate key for offline/mobile sync, imports, deep links. **Not the PK.** |
| `VERSIONNO` | `NUMBER(10)` | All tables | Optimistic locking; incremented by trigger |
| `ISDELETED` | `CHAR(1)` | All tables | Soft delete (`Y`/`N`) |
| `DELETEDDATE`, `DELETEDBY` | `TIMESTAMP WITH TIME ZONE`, `VARCHAR2(255)` | Data tables | Audit of soft delete |
| `ISACTIVE` | `CHAR(1)` | Setup tables | Enable/disable a value |
| `ISDEFAULT` | `CHAR(1)` | Setup tables | Default value |
| `DISPLAYORDER` | `NUMBER(10)` | Setup tables | Display order |
| `STATUSCODE` | `NUMBER(19)` | Data tables | Lifecycle state (FK to `TG$VALID_STATUS_TAB.STATUSCODE`) |
| `SRC_SYSTEM`, `SRC_ID` | `VARCHAR2(30)`, `VARCHAR2(100)` | Optional | Integration lineage |
| `HASH` | `VARCHAR2(64)` | Optional | Change detection for mobile sync |
| `LOCALE`, `TIMEZONE`, `CURRENCYCODE` | `VARCHAR2` | Optional | Localisation |
| `EFFECTIVE_FROM`, `EFFECTIVE_TO` | `DATE` | Optional | Validity window |

**Why not UUID as the primary key?** Oracle indexes on random `RAW(16)` values fragment and cluster poorly. Keep the numeric `RSN` as PK and `UUID` as a unique alternate key.

## 4. Key strategy: CODE vs RSN vs UUID

| Key | Used by | Meaning |
|---|---|---|
| `<ENTITY>CODE` | Valid tables | Numeric surrogate PK generated by `TG$VALID_<ENTITY>_SEQ`; foreign keys store this value. |
| `<ENTITY>DESC` | Valid tables | Unique, human-readable business key used for display and seeding. |
| `SETTINGCODE` | `TG$SETTING_TAB` | Stable, human-readable settings key. |
| `RSN` | Data tables | Record Serial Number — compact numeric surrogate PK from a `_SEQ` sequence. |
| `UUID` | All tables | Environment-independent unique ID for sync, import and external references. |
| Business code (`ACCESSCODE`, `MEMBERCODE`, `LISTCODE`, `ITEMCODE`) | Data tables | Human-friendly unique key scoped by `ACCESSCODE`, useful for DML and imports. |

## 5. Table inventory

| Table | Type | PK | Purpose |
|---|---|---|---|
| `TG$VALID_STATUS_TAB` | Valid | `STATUSCODE` | Lifecycle statuses (ACTIVE, DONE, CANCELLED, ARCHIVED) |
| `TG$VALID_PRIORITY_TAB` | Valid | `PRIORITYCODE` | Priority levels |
| `TG$VALID_UOM_TAB` | Valid | `UOMCODE` | Units of measure |
| `TG$VALID_CATEGORY_TAB` | Valid | `CATEGORYCODE` | Item categories |
| `TG$VALID_ROLETYPE_TAB` | Valid | `ROLETYPECODE` | Household roles (OWNER, MEMBER) |
| `TG$SETTING_TAB` | Setup | `SETTINGCODE` | Application settings (key/value) |
| `TG$ACCESS_TAB` | Data | `RSN` | Household/couple access group |
| `TG$MEMBER_TAB` | Data | `RSN` | Members of a household |
| `TG$LIST_TAB` | Data | `RSN` | A shopping/wish list |
| `TG$ITEM_TAB` | Data | `RSN` | Wish-list items with priority and due date |
| `TG$ITEM_HISTORY_TAB` | Data | `RSN` | Change history for items (JSON snapshots) |

## 6. ACCESSCODE and security

`ACCESSCODE` identifies the couple/household that owns a row.

- Valid tables are global reference data and default to `ACCESSCODE = 'GLOBAL'`.
- `TG$SETTING_TAB` defaults to `GLOBAL` so configuration is shared.
- Data tables must always carry the owning `ACCESSCODE`, with an FK to `TG$ACCESS_TAB(ACCESSCODE)`.
- Enforce isolation with either:
  - a VPD/RLS policy on data tables, or
  - an APEX authorization + `WHERE ACCESSCODE = :APP_ACCESSCODE` in every view/query.
- Never let APEX users query base tables directly; expose filtered views or packages.

If per-tenant setup overrides are needed later, add a dedicated override table rather than putting tenant-specific rows in a valid table.

## 7. Audit and triggers

- One `BEFORE INSERT OR UPDATE` trigger per table sets `STAMPUSER`, `STAMPDATE`, `STAMPSESSION`, `CREATEDBY`, `CREATEDDATE`, `CREATESESSION`, `APPID`, `VERSIONNO` and, on data tables, `RSN`/`UUID`. Valid-table triggers also assign `<ENTITY>CODE` from `TG$VALID_<ENTITY>_SEQ`.
- Valid tables get the same audit trigger (`TG$VALID_<ENTITY>_TAB_TRG1`); their setup attributes (`DISPLAYORDER`, `ISACTIVE`, `ISDEFAULT`) are managed by the application.
- The current user is read from `SYS_CONTEXT('APEX$SESSION','APP_USER')`, falling back to `USER` outside APEX.
- The APEX session identity is read from `SYS_CONTEXT('APEX$SESSION','APP_ID')` and `SYS_CONTEXT('APEX$SESSION','APP_SESSION')`. On insert `APPID`/`CREATESESSION`/`STAMPSESSION` are filled when the caller did not supply them.
- On update, `CREATEDBY`/`CREATEDDATE`/`CREATESESSION`/`APPID`/`RSN`/`UUID`/`ACCESSCODE` are preserved, `STAMPSESSION` is refreshed from the current session and `VERSIONNO` is incremented.
- `TG$ITEM_TAB_TRG2` writes a JSON snapshot to `TG$ITEM_HISTORY_TAB` on insert/update/delete.

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
- Valid tables use a numeric `<ENTITY>CODE` generated by `TG$VALID_<ENTITY>_SEQ`, plus `<ENTITY>DESC` as the unique human-readable key and the same standard columns as other tables.
- `SORTNO` is named `DISPLAYORDER` throughout the schema.
- `TG$SETTING_TAB.SETTINGCODE` stays a text key because settings are looked up by name.
- Not included yet: VPD policy package, APEX application, grants/synonyms, unit tests, migration tooling (Flyway/Liquibase).
- Ask before using `TIMESTAMP WITH TIME ZONE` vs `DATE` if your APEX version or DBA standard differs.
