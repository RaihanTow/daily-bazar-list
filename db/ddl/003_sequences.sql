-- ============================================================================
-- Twogether - Sequences for data-table surrogate keys (RSN)
-- Run order: 003 (after 002_core_tables.sql, before 004_setup_triggers.sql)
-- ============================================================================
SET DEFINE OFF;

CREATE SEQUENCE TG$ACCESS_SEQ001
  START WITH 1000 INCREMENT BY 1 CACHE 20 NOCYCLE;

CREATE SEQUENCE TG$MEMBER_SEQ001
  START WITH 1000 INCREMENT BY 1 CACHE 20 NOCYCLE;

CREATE SEQUENCE TG$LIST_SEQ001
  START WITH 1000 INCREMENT BY 1 CACHE 20 NOCYCLE;

CREATE SEQUENCE TG$ITEM_SEQ001
  START WITH 1000 INCREMENT BY 1 CACHE 20 NOCYCLE;

CREATE SEQUENCE TG$ITEM_HISTORY_SEQ001
  START WITH 1000 INCREMENT BY 1 CACHE 20 NOCYCLE;
