-- ============================================================================
-- Twogether - Read views for APEX
-- Run order: 007 (after all tables/triggers)
-- ============================================================================
SET DEFINE OFF;

-- ----------------------------------------------------------------------------
-- TG$VALID_PRIORITY_VW - active priority lookup
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW TG$VALID_PRIORITY_VW AS
SELECT PRIORITYCODE,
       PRIORITYDESC,
       DESCRIPTION,
       PRIORITYNO,
       COLORCODE,
       ICONCODE,
       DISPLAYORDER,
       ISDEFAULT
FROM   TG$VALID_PRIORITY_TAB
WHERE  ISACTIVE  = 'Y'
AND    ISDELETED = 'N';

-- ----------------------------------------------------------------------------
-- TG$ITEM_VW - item with joined lookup descriptions
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW TG$ITEM_VW AS
SELECT i.RSN,
       i.ACCESSCODE,
       i.ITEMCODE,
       i.ITEMNAME,
       i.ITEMDESC,
       i.LISTRSN,
       l.LISTCODE,
       l.LISTNAME,
       i.CATEGORYCODE,
       c.CATEGORYDESC,
       i.PRIORITYCODE,
       p.PRIORITYDESC,
       p.PRIORITYNO,
       p.COLORCODE                AS PRIORITYCOLOR,
       p.ICONCODE                 AS PRIORITYICON,
       i.STATUSCODE,
       s.STATUSDESC,
       i.DUEDATE,
       i.QUANTITY,
       i.UOMCODE,
       u.UOMDESC,
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
FROM   TG$ITEM_TAB             i
JOIN   TG$LIST_TAB             l ON l.RSN          = i.LISTRSN
JOIN   TG$VALID_PRIORITY_TAB   p ON p.PRIORITYCODE = i.PRIORITYCODE
JOIN   TG$VALID_STATUS_TAB     s ON s.STATUSCODE   = i.STATUSCODE
LEFT   JOIN TG$VALID_CATEGORY_TAB c ON c.CATEGORYCODE = i.CATEGORYCODE
LEFT   JOIN TG$VALID_UOM_TAB   u ON u.UOMCODE      = i.UOMCODE
WHERE  i.ISDELETED = 'N';

-- ----------------------------------------------------------------------------
-- TG$DUE_VW - open items with due dates, ordered by priority then due date
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW TG$DUE_VW AS
SELECT RSN,
       ACCESSCODE,
       ITEMCODE,
       ITEMNAME,
       PRIORITYCODE,
       PRIORITYDESC,
       PRIORITYNO,
       PRIORITYCOLOR,
       STATUSCODE,
       STATUSDESC,
       DUEDATE,
       QUANTITY,
       UOMCODE,
       UOMDESC,
       ASSIGNEDUSER,
       ISREMINDER,
       REMINDERDATE
FROM   TG$ITEM_VW
WHERE  DUEDATE IS NOT NULL
AND    STATUSDESC NOT IN ('Done', 'Cancelled', 'Archived')
ORDER  BY PRIORITYNO, DUEDATE;
