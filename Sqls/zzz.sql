DELETE FROM MAINTREE;

INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (100, 0, 2, 'Node 1', 0, 3, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (200, 0, 2, 'Node 2', 0, 3, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (101, 100, 1, 'Node 11', 0, 11, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (201, 200, 1, 'Node 21', 0, 12, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (3, -1, 2, 'Структура объектов', 0, 1, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (300, 3, 2, 'Сотрудники ОК', 0, 300, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (301, 300, 1, 'Образование', 0, 301, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (302, 300, 1, 'Состав семьи', 0, 302, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (350, 3, 2, 'Члены семьи', 0, 302, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (351, 350, 1, 'Родители', 0, 350, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (1000, 0, 2, 'Отдел кадров', 0, 3, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (1100, 1000, 1, 'Сотрудники', 0, 300, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (352, 350, 1, 'Дети', 0, 350, 0, 0);

COMMIT WORK;
-------------------------------------------------------------------

DELETE FROM APPVWR;

INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (3, 'TvwrTop', 'Другие папки');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (11, 'TvwrOne', 'Тест 1');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (12, 'TvwrTwo', 'Test 2');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (300, 'TvwrEmployee', 'Карточка сотрудника');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (301, 'TvwrEmpEducation', 'ОК образование сотрудника');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (302, 'TvwrEmpFamily', 'ОК состав семьи');

COMMIT WORK;
-------------------------------------------------------------------

DELETE FROM EMPLOYEES;

INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (1, NULL, 'Иванов', 'Иван', 'Иванович', NULL);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (2, NULL, 'Петров', 'Петр', 'Петрович', NULL);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (3, NULL, 'Сидоров', 'Сидор', 'Сидорович', NULL);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (4, 1, 'Иванова', 'Галина', 'Ивановна', 2);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (5, 1, 'Иванов', 'Василий', 'Иванович', 3);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (6, 1, 'Иванова', 'Мария', 'Семеновна', 1);

COMMIT WORK;
-------------------------------------------------------------------
CREATE TABLE SQLS (
    ID_METHOD CHAR(16),
    SQL_BODY VARCHAR(128)
);

DELETE FROM SQLS;

INSERT INTO SQLS (ID_METHOD, SQL_BODY)
          VALUES (X'4F8A0FB77BE643108225A02051FCC1BB', 'select * from EMPLOYEES;');

COMMIT WORK;

CREATE OR ALTER VIEW SQLS$VW(
    ID_METHOD,
    SQL_BODY)
AS
select uuid_to_char(ID_METHOD), SQL_BODY from SQLS
;