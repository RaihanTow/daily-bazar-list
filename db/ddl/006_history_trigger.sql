-- ============================================================================
-- Twogether - Item change-history trigger
-- Run order: 006 (after 002_core_tables.sql and 005_data_triggers.sql)
-- Writes a JSON snapshot to TG$ITEM_HISTORY_TAB001 on every item change.
-- ============================================================================
SET DEFINE OFF;

CREATE OR REPLACE TRIGGER TG$ITEM_TAB001_TRG2
AFTER INSERT OR UPDATE OR DELETE ON TG$ITEM_TAB001
FOR EACH ROW
DECLARE
  l_user VARCHAR2(255) := COALESCE(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER);
BEGIN
  IF INSERTING THEN
    INSERT INTO TG$ITEM_HISTORY_TAB001
      (ACCESSCODE, ITEMRSN, ACTIONCODE, CHANGEDBY, CHANGEDDATE, CHANGEDATA)
    VALUES
      (:NEW.ACCESSCODE, :NEW.RSN, 'INSERT', l_user, SYSTIMESTAMP,
       JSON_OBJECT(
         'itemCode'     VALUE :NEW.ITEMCODE,
         'itemName'     VALUE :NEW.ITEMNAME,
         'priorityCode' VALUE :NEW.PRIORITYCODE,
         'statusCode'   VALUE :NEW.STATUSCODE,
         'dueDate'      VALUE TO_CHAR(:NEW.DUEDATE, 'YYYY-MM-DD')
       ));
  ELSIF UPDATING THEN
    INSERT INTO TG$ITEM_HISTORY_TAB001
      (ACCESSCODE, ITEMRSN, ACTIONCODE, CHANGEDBY, CHANGEDDATE, CHANGEDATA)
    VALUES
      (:NEW.ACCESSCODE, :NEW.RSN, 'UPDATE', l_user, SYSTIMESTAMP,
       JSON_OBJECT(
         'oldStatusCode'   VALUE :OLD.STATUSCODE,
         'newStatusCode'   VALUE :NEW.STATUSCODE,
         'oldPriorityCode' VALUE :OLD.PRIORITYCODE,
         'newPriorityCode' VALUE :NEW.PRIORITYCODE,
         'oldDueDate'      VALUE TO_CHAR(:OLD.DUEDATE, 'YYYY-MM-DD'),
         'newDueDate'      VALUE TO_CHAR(:NEW.DUEDATE, 'YYYY-MM-DD')
       ));
  ELSE
    INSERT INTO TG$ITEM_HISTORY_TAB001
      (ACCESSCODE, ITEMRSN, ACTIONCODE, CHANGEDBY, CHANGEDDATE, CHANGEDATA)
    VALUES
      (:OLD.ACCESSCODE, :OLD.RSN, 'DELETE', l_user, SYSTIMESTAMP,
       JSON_OBJECT(
         'itemCode' VALUE :OLD.ITEMCODE,
         'itemName' VALUE :OLD.ITEMNAME
       ));
  END IF;
END;
/
