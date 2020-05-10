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
              VALUES (3, -1, 2, '��������� ��������', 0, 1, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (300, 3, 2, '���������� ��', 0, 300, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (301, 300, 1, '�����������', 0, 301, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (302, 300, 1, '������ �����', 0, 302, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (350, 3, 2, '����� �����', 0, 302, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (351, 350, 1, '��������', 0, 350, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (1000, 0, 2, '����� ������', 0, 3, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (1100, 1000, 1, '����������', 0, 300, 0, 0);
INSERT INTO MAINTREE (ID, PARENT, LEAF, NAME, OPTIONS, VIEWER, TAG, NUM)
              VALUES (352, 350, 1, '����', 0, 350, 0, 0);

COMMIT WORK;
-------------------------------------------------------------------

DELETE FROM APPVWR;

INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (3, 'TvwrTop', '������ �����');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (11, 'TvwrOne', '���� 1');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (12, 'TvwrTwo', 'Test 2');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (300, 'TvwrEmployee', '�������� ����������');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (301, 'TvwrEmpEducation', '�� ����������� ����������');
INSERT INTO APPVWR (ID, NAME, DESCR)
            VALUES (302, 'TvwrEmpFamily', '�� ������ �����');

COMMIT WORK;
-------------------------------------------------------------------

DELETE FROM EMPLOYEES;

INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (1, NULL, '������', '����', '��������', NULL);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (2, NULL, '������', '����', '��������', NULL);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (3, NULL, '�������', '�����', '���������', NULL);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (4, 1, '�������', '������', '��������', 2);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (5, 1, '������', '�������', '��������', 3);
INSERT INTO EMPLOYEES (ID, ID_OWN, F_NAME, M_NAME, L_NAME, STATUS)
               VALUES (6, 1, '�������', '�����', '���������', 1);

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