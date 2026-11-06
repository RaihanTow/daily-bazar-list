-- ============================================================================
-- Twogether - Read views for APEX
-- Run order: 007 (after all tables/triggers)
-- ============================================================================
SET DEFINE OFF;

-- ----------------------------------------------------------------------------
-- TG$PRIORITY_VW001 - active priority lookup
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW TG$PRIORITY_VW001 AS
SELECT CODE,
       DISPLAYNAME,
       DESCRIPTION,
       PRIORITYNO,
       COLORCODE,
       ICONCODE,
       SORTNO,
       ISDEFAULT
FROM   TG$PRIORITY_TAB001
WHERE  ISACTIVE  = 'Y'
AND    ISDELETED = 'N';

-- ----------------------------------------------------------------------------
-- TG$ITEM_VW001 - item with joined lookup descriptions
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW TG$ITEM_VW001 AS
SELECT i.RSN,
       i.ACCESSCODE,
       i.ITEMCODE,
       i.ITEMNAME,
       i.ITEMDESC,
       i.LISTRSN,
       l.LISTCODE,
       l.LISTNAME,
       i.CATEGORYCODE,
       c.DISPLAYNAME              AS CATEGORYNAME,
       i.PRIORITYCODE,
       p.DISPLAYNAME              AS PRIORITYNAME,
       p.PRIORITYNO,
       p.COLORCODE                AS PRIORITYCOLOR,
       i.STATUSCODE,
       s.DISPLAYNAME              AS STATUSNAME,
       i.DUEDATE,
       i.QUANTITY,
       i.UOMCODE,
       i.ESTCOST,
       i.CURRENCYCODE,
       i.ASSIGNEDUSER,
       i.ISREMINDER,
       i.REMINDERDATE,
       i.COMPLETEDDATE,
       i.COMPLETEDBY,
       RAWTOHEX(i.UUID)           AS UUIDCHAR,
       i.CREATEDDATE,
       i.CREATEDBY,
       i.STAMPDATE,
       i.STAMPUSER,
       i.VERSIONNO
FROM   TG$ITEM_TAB001     i
JOIN   TG$LIST_TAB001     l ON l.RSN  = i.LISTRSN
JOIN   TG$PRIORITY_TAB001 p ON p.CODE = i.PRIORITYCODE
JOIN   TG$STATUS_TAB001   s ON s.CODE = i.STATUSCODE
LEFT   JOIN TG$CATEGORY_TAB001 c ON c.CODE = i.CATEGORYCODE
WHERE  i.ISDELETED = 'N';

-- ----------------------------------------------------------------------------
-- TG$DUE_VW001 - open items with due dates, ordered by urgency
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW TG$DUE_VW001 AS
SELECT RSN,
       ACCESSCODE,
       ITEMCODE,
       ITEMNAME,
       PRIORITYCODE,
       PRIORITYNAME,
       PRIORITYNO,
       PRIORITYCOLOR,
       STATUSCODE,
       STATUSNAME,
       DUEDATE,
       QUANTITY,
       UOMCODE,
       ASSIGNEDUSER,
       ISREMINDER,
       REMINDERDATE
FROM   TG$ITEM_VW001
WHERE  DUEDATE IS NOT NULL
AND    STATUSCODE NOT IN ('DONE', 'CANCELLED', 'ARCHIVED');
