SET SQL DIALECT 3;

CREATE ROLE RWORKER;
CREATE ROLE IT;
create role OBMEN;

create or alter user EXCHANGER password 'Moving';
grant OBMEN to EXCHANGER;

create or alter user SL password '1';
grant IT to SL;
grant RWORKER to SL;

create or alter user "USER" password '1';
grant RWORKER to "USER";

/******************************************************************************/
/***                                Domains                                 ***/
/******************************************************************************/

CREATE DOMAIN VOID AS INTEGER default null; -- ��������� ��� Void-�������

CREATE DOMAIN DBIGINT AS
BIGINT;

CREATE DOMAIN DBIGINT_NN AS
BIGINT NOT NULL;

CREATE DOMAIN DBINARY AS
BLOB SUB_TYPE 1 SEGMENT SIZE 80;

CREATE DOMAIN DBOOL AS
BOOLEAN;

CREATE DOMAIN DBOOL_NN AS
BOOLEAN NOT NULL;

CREATE DOMAIN DDATE AS
DATE;

CREATE DOMAIN DDATE_NN AS
DATE NOT NULL;

CREATE DOMAIN DDP AS
DOUBLE PRECISION;

CREATE DOMAIN DDP_NN AS
DOUBLE PRECISION NOT NULL;

CREATE DOMAIN DDT AS
TIMESTAMP;

CREATE DOMAIN DDT_NN AS
TIMESTAMP NOT NULL;

CREATE DOMAIN DGUID AS
CHAR(16) CHARACTER SET OCTETS;

CREATE DOMAIN DGUID_NN AS
CHAR(16) CHARACTER SET OCTETS NOT NULL;

CREATE DOMAIN DGUID_STR AS
VARCHAR(36);

CREATE DOMAIN DGUID_STR_NN AS
VARCHAR(36) NOT NULL;

CREATE DOMAIN DINT AS
INTEGER;

CREATE DOMAIN DINT_NN AS
INTEGER NOT NULL;

CREATE DOMAIN DTEXT AS
BLOB SUB_TYPE 1 SEGMENT SIZE 80;

CREATE DOMAIN DVCHAR1024 AS
VARCHAR(1024);

CREATE DOMAIN DVCHAR1024_NN AS
VARCHAR(1024) NOT NULL;

CREATE DOMAIN DVCHAR128 AS
VARCHAR(128);

CREATE DOMAIN DVCHAR128_NN AS
VARCHAR(128) NOT NULL;

CREATE DOMAIN DVCHAR16 AS
VARCHAR(16);

CREATE DOMAIN DVCHAR16_NN AS
VARCHAR(16) NOT NULL;

CREATE DOMAIN DVCHAR200 AS
VARCHAR(200);

CREATE DOMAIN DVCHAR256 AS
VARCHAR(256);

CREATE DOMAIN DVCHAR256_NN AS
VARCHAR(256) NOT NULL;

CREATE DOMAIN DVCHAR32 AS
VARCHAR(32);

CREATE DOMAIN DVCHAR32_NN AS
VARCHAR(32) NOT NULL;

CREATE DOMAIN DVCHAR48 AS
VARCHAR(48);

CREATE DOMAIN DVCHAR48_NN AS
VARCHAR(48) NOT NULL;

CREATE DOMAIN DVCHAR512 AS
VARCHAR(512);

CREATE DOMAIN DVCHAR512_NN AS
VARCHAR(512)
NOT NULL;

CREATE DOMAIN DVCHAR64 AS
VARCHAR(64);

CREATE DOMAIN DVCHAR64_NN AS
VARCHAR(64) NOT NULL;

CREATE DOMAIN DVCHAR80 AS
VARCHAR(80);

/******************************************************************************/
/***                               Exceptions                               ***/
/******************************************************************************/

create exception EX_COMMON '����� ������';
grant usage on exception EX_COMMON to PUBLIC;

/******************************************************************************/
/***                                 Tables                                 ***/
/******************************************************************************/
--create global temporary table GTT_PRIV(
--   MAIN    DBOOL
--  ,OBJ     DGUID_NN
--  ,ROOT    DGUID
--  ,OPERS   DBIGINT_NN
--) on commit delete rows;
--grant all on GTT_PRIV to public;
--create index GTT_PRIV_IDX0 on GTT_PRIV (MAIN);
--create index GTT_PRIV_IDX2 on GTT_PRIV (OBJ);
--create index GTT_PRIV_IDX3 on GTT_PRIV (ROOT);
----------------------------------------------------------

create global temporary table GTT_IDS(
   ID    DGUID
  ,UID   DGUID
  ,TAG   DINT
  ,KIND  DINT
) on commit delete rows;
grant all on GTT_IDS to public;
create index GTT_IDS_IDX0 on GTT_IDS(ID);
create index GTT_IDS_IDX1 on GTT_IDS(UID);
create index GTT_IDS_IDX2 on GTT_IDS(TAG);
create index GTT_IDS_IDX3 on GTT_IDS(KIND);
comment on table GTT_IDS is '���� � ������� ��� ��. ������� �� ��������';
----------------------------------------------------------

create table TCDBINFO (
    ID       DGUID_NN,
    KODFIL   DINT_NN,
    NAME     DVCHAR32_NN,
    VER_INT  DBIGINT_NN,
    VERS     DVCHAR32_NN
);
comment on table  TCDBINFO is '���������� � (���������) ��';
comment on column TCDBINFO.KODFIL is '����� �������� (FILLIST.KODFIL)';
comment on column TCDBINFO.NAME is '��� ��';
comment on column TCDBINFO.VER_INT is '������ �� (����� ��� ���������)';
comment on column TCDBINFO.VERS is '������ ��';
----------------------------------------------------------

create table LOGINS (
    ID        DGUID_NN,
    LOGIN     DVCHAR32,
    TIME_ON   DDT,
    TIME_OFF  DDT,
    IP        DVCHAR256,
    PROCESS   DVCHAR256,
    STAGE     DINT
);
alter table LOGINS add constraint PK_LOGINS primary key(ID);
create descending index LOGINS_IDX1 on LOGINS(TIME_ON);
create index LOGINS_IDX2 on LOGINS(STAGE);
create index LOGINS_IDX3 on LOGINS(LOGIN);
comment on table  LOGINS is '�������� ����������� �������������';
comment on column LOGINS.LOGIN is '��� ������������ ��';
comment on column LOGINS.TIME_ON is '������ (�������) �����������';
comment on column LOGINS.TIME_ON is '������ ����������';
comment on column LOGINS.IP is 'rdb$get_context("SYSTEM","CLIENT_ADDRESS")';
comment on column LOGINS.PROCESS is 'rdb$get_context("SYSTEM","CLIENT_PROCESS")';
comment on column LOGINS.STAGE is
'0 - ������� ����������
 1 - ����� ����� �� ������ � SYS_SUBJS
 2 - ������ ��������
 3 - �������� �����������
 4 - disconnect ����� �������� �����������
';
----------------------------------------------

create generator GEN_KOPS_ID;
create table KOPS(
    ID_KOPS       DINT_NN,
    KOP           DINT_NN,
    KOP_PRIOR     DINT_NN,
    KOP_COMMENTS  DVCHAR128,
    DIRECTION     char(1) not null, -- U[pload] | D[ownload]
    QUERY         DVCHAR512_NN,
    STATE         DINT_NN DEFAULT 0
);
ALTER TABLE KOPS ADD CONSTRAINT PK_KOPS PRIMARY KEY(ID_KOPS);
ALTER TABLE KOPS ADD CONSTRAINT UNQ1_KOPS UNIQUE(KOP);
CREATE INDEX KOPS_IDX1 ON KOPS(KOP);
CREATE INDEX KOPS_IDX2 ON KOPS(STATE);
CREATE INDEX KOPS_IDX3 ON KOPS(KOP_PRIOR);
comment on table  KOPS is
'�������� ������. KOP ���������� ��������, KOP_PRIOR - � ���������.
QUERY �������� ��� (���������) Sql-�������: select ������ �� �������
�� ��������� � ����� ��. ��������� EX_?? � ����������� ��.
������ ������� select`� ���������� � �������� ��-�� EX_?? � ������������
� �� ��������. ������: TABLE=<select>;SPROC=<StorProc>; ����� <select>
�������� ������� where <PK Field> = :[ID_GUID|ID_DATA] (��� ��������� ������
��������� � ������ ���� BUFF) � �� �������� ����� "select"; ����� <StorProc>
�������� ����� ��. ��������� ������� EX_?? ��� ���� "execute procedure". ������:
TABLE=ID,NAME,STATE from FOO$VW t where t.ID = :ID_GUID;SPROC=EX_FOO(:ID,:NAME,:STATE)';

comment on column KOPS.STATE is
'0 - ������
 1 - ��������
 2 - ?
 3 - ��� �������
 4 - KOP ��� �����
 5 - KOP ��� �������
';
----------------------------------------------

create generator GEN_ID_BUFF;
create table BUFF(
    ID_BUFF   DBIGINT_NN,
    KOP       DINT_NN,
    SOURCODE  DINT_NN,
    DESTCODE  DINT_NN,
    ID_DATA   DINT,
    ID_GUID   DGUID,
    INT_DATA  DINT,
    SDT       DDT
);
ALTER TABLE BUFF ADD CONSTRAINT PK_BUFF PRIMARY KEY(ID_BUFF);
CREATE INDEX BUFF_IDX1 ON BUFF (KOP);
CREATE INDEX BUFF_IDX2 ON BUFF (SOURCODE);
CREATE INDEX BUFF_IDX3 ON BUFF (DESTCODE);
CREATE INDEX BUFF_IDX4 ON BUFF (ID_DATA);
comment on table  BUFF is
'������ �� �����/���������������� ������ ������: ID_DATA ��� ID_GUID,
� ����������� �� ���� primary key �������.';
comment on column BUFF.SOURCODE is '������: ��� ��������';
comment on column BUFF.KOP is '��� �������� KOPS.ID';
comment on column BUFF.DESTCODE is '����: ��� ��������';
comment on column BUFF.ID_DATA is 'integer-ID ������������ ������';
comment on column BUFF.INT_DATA is '';
comment on column BUFF.ID_GUID is 'ID ������������ ������';

grant select,delete on BUFF to OBMEN;
----------------------------------------------

create table LOGOBMEN(
     ID        DGUID_NN
    ,ID_BUFF   DBIGINT
    ,SOURCODE  DINT
    ,DESTCODE  DINT
    ,OK        DINT
    ,CONTEXT   DVCHAR64
    ,MSG       DVCHAR512
    ,SDT       DDT
);
alter table LOGOBMEN add constraint PK_LOGOBMEN primary key(ID);
--alter table LOGOBMEN add constraint FK_LOGOBMEN_1 foreign key(ID_BUFF) references BUFF(ID_BUFF);
create descending index LOGOBMEN_IDX1 on LOGOBMEN(SDT);

comment on table  LOGOBMEN is '���������� ������';
comment on column LOGOBMEN.ID_BUFF is '�������� null ��� BUFF.ID_BUFF, ��������� ������';
comment on column LOGOBMEN.OK is '1|0 �����|������';
comment on column LOGOBMEN.MSG is '����� ��������� �� ������';
-----------------------------------------------------------
/*
CREATE GLOBAL TEMPORARY TABLE SYSENV (
    ID_LOGIN  DGUID,
    LOGIN     DVCHAR32,
    ID_USER   DGUID
) ON COMMIT PRESERVE ROWS;
comment on table SYSENV is
'R/O ���������� ���������; ���� ������ �� ������������.
�� ������� �������� ��� ����������, �������� ������ ������ ���� RWORKER';
comment on column SYSENV.ID_LOGIN is 'LOGINS.ID';
comment on column SYSENV.LOGIN is '��� ������������ ��';
comment on column SYSENV.ID_USER is 'SYS_SUBJS.ID';
*/
----------------------------------------------------------

create table SUBJECTS(
   ID      DGUID_NN
  ,GRP     DINT_NN
  ,LOGIN   DVCHAR32_NN
  ,NAME    DVCHAR32_NN
  ,TABNUM  DINT
  ,EXPDATE DDATE
  ,PHONE   DVCHAR32
  ,EMAIL   DVCHAR48
  ,STATE   DINT_NN   default 0
  ,MODDT   DDT_NN    default current_timestamp
  ,MODUSER DGUID_NN
);
alter table SUBJECTS add constraint PK_SUBJECTS primary key(ID);
alter table SUBJECTS add constraint UNQ1_SUBJECTS unique(LOGIN);
create index SUBJECTS_IDX1 on SUBJECTS(GRP);
comment on table  SUBJECTS is '������������, ����, ���������';
comment on column SUBJECTS.LOGIN is
'Login � ��, uppercase. ��� ����� � ��. - ����� NAME (uppercase)';
comment on column SUBJECTS.GRP is'
 0: ������������
>0: ����
<0: ���������
 2: ����������������� ���� (�������� �������������� ����������)
';
comment on column SUBJECTS.EXPDATE is '������ �������� �� ��� ���� (������������)';
comment on column SUBJECTS.STATE is '������� ����:
 0 - ������
 1 - disabled
 2 - �������
 3 - �����������, �� ������������ � �������
 4 - ����������� ������ ������� ������
';
----------------------------------------------------------

create table SUBJLINK(
   ID      DGUID_NN
  ,UID     DGUID_NN
  ,GID     DGUID_NN
  ,EXPDATE DDATE
  ,STATE   DINT_NN   default 0
  ,MODDT   DDT_NN    default current_timestamp
  ,MODUSER DGUID_NN
);
alter table SUBJLINK add constraint PK_SUBJLINK primary key(ID);
alter table SUBJLINK add constraint FK_SUBJLINK_1 foreign key(UID) references SUBJECTS(ID);
alter table SUBJLINK add constraint FK_SUBJLINK_2 foreign key(GID) references SUBJECTS(ID);
alter table SUBJLINK add constraint UNQ_SUBJLINK unique(UID,GID);
create index SUBJLINK_EXP on SUBJLINK(EXPDATE);
comment on  table SUBJLINK is
'����� ������������-����, ������������-��������� � ����-���������

URP - SUBJECTS$VW.GRP where SUBJECTS.ID = UID;
GRP - SUBJECTS$VW.GRP where SUBJECTS.ID = GID;

             UID GID                        GID  UID
           /         \                     /         \
          /  URP > 0  \                   /  URP = 0  \
         /   GRP < 0   \                 /   GRP = 0   \
        /               \               /               \
 -Roles-      Users      -Appoints-   ����������  ����������
 \             /  \              /
  \  URP = 0  /    \   URP = 0  /
   \ GRP > 0 /      \  GRP < 0 /
    \       /        \        /
     GID UID           UID GID

';
comment on column SUBJLINK.UID is 'SUBJECTS.ID ������������, ����';
comment on column SUBJLINK.GID is 'SUBJECTS.ID ���� ��� �����������, ���������';
comment on column SUBJLINK.EXPDATE is '����� ���� ���� ����� �� �������������';
comment on column SUBJLINK.STATE is '������� ����:
 0 - ������
 1 - disabled
 2 - �������
';

----------------------------------------------------------

create table FILLIST(
     ID           DGUID_NN
    ,KODFIL       DINT_NN
    ,NAME         DVCHAR48_NN
    ,TYPE_OBJECT  DINT_NN default 0
    ,NICKNAME     DVCHAR16
    ,STATE        DINT_NN default 0
    ,URL          DVCHAR32
    ,MODDT        DDT_NN default current_timestamp
    ,MODUSER      DGUID_NN
);
alter table  FILLIST add primary key(ID);
alter table  FILLIST add constraint UNQ_FILLIST_KODFIL unique(KODFIL);
create index FILLIST_NAME on FILLIST(NAME);
create index FILLIST_IDX1 on FILLIST(KODFIL,TYPE_OBJECT);
create index FILLIST_IDX2 on FILLIST(NICKNAME);
create index FILLIST_IDX3 on FILLIST(TYPE_OBJECT);

comment on table  FILLIST is '�������';
comment on column FILLIST.KODFIL is '��� �������. 0 - �����. ����';
comment on column FILLIST.TYPE_OBJECT is'
 0 - ������
 1 - �������
 2 - ���������
 3 - ��������� � ������
';
comment on column FILLIST.NICKNAME is '������� ������������';
comment on column FILLIST.URL is '��� ��������� - ����� ��';
comment on column FILLIST.STATE is'
 0 - ������
 1 - disabled
 2 - �������
';
comment on column FILLIST.MODDT is '����� ��������� �����������';
comment on column FILLIST.MODUSER is '����� ��������� �����������';
----------------------------------------------

create table SYSVIEWERS(
   ID      DINT_NN
  ,KIND    DINT_NN
  ,NAME    DVCHAR48_NN
  ,OPERS   DINT
  ,DESCR   DVCHAR64
  ,STATE   DINT_NN default 0
  ,MODDT   DDT_NN  default current_timestamp
  ,MODUSER DGUID_NN
);
alter table SYSVIEWERS add constraint PK_SYSVIEWERS primary key(ID);
comment on table  SYSVIEWERS is '������ ��������� (Viewers)';
comment on column SYSVIEWERS.KIND is '';
comment on column SYSVIEWERS.NAME is '��� ������';
comment on column SYSVIEWERS.OPERS is '�������� ����� Viewer';
comment on column SYSVIEWERS.DESCR is '��������';
comment on column SYSVIEWERS.STATE is '������� ����:
 0 - ������
 1 - ?
 2 - �������
';
----------------------------------------------

create table SYSTREE (
    ID      DGUID_NN,
    ID_OWN  DGUID,
    NAME    DVCHAR64,
    OPTIONS DINT_NN,
    VIEWER  DINT,
    TAG     DINT,
    STATE   DINT_NN default 0,
    MODDT   DDT_NN  default current_timestamp,
    MODUSER DGUID_NN
);
alter table SYSTREE add constraint PK_SYSTREE primary key(ID);
alter table SYSTREE add constraint FK_SYSTREE_1 foreign key(ID_OWN) references SYSTREE(ID);
alter table SYSTREE add constraint FK_SYSTREE_2 foreign key(VIEWER) references SYSVIEWERS(ID);
comment on table  SYSTREE is '������ �������';
comment on column SYSTREE.NAME is '��� ����';
comment on column SYSTREE.OPTIONS is '������� ����:';
comment on column SYSTREE.VIEWER is 'ID Viewer`� ��� ����� ����';
comment on column SYSTREE.TAG is '';
comment on column SYSTREE.STATE is '������� ����:
 0 - ������
 1 - ?
 2 - �������
';
----------------------------------------------

create table VWRTAG(
   ID      DGUID_NN
  ,TAG     DINT_NN
  ,VIEWER  DINT
  ,NAME    DVCHAR48
  ,SVALUE  DVCHAR80
  ,STATE   DINT_NN default 0
  ,MODDT   DDT_NN  default current_timestamp
  ,MODUSER DGUID_NN
);
alter table VWRTAG add constraint PK_VWRTAG primary key(ID);
--alter table VWRTAG add constraint FK_VWRTAG_1 foreign key(VIEWER) references SYSVIEWERS(ID);
alter table VWRTAG add constraint UNQ1_VWRTAG unique(TAG,VIEWER);
create index VWRTAG_IDX1 on VWRTAG(TAG);
comment on table  VWRTAG is '������ ��������� (Viewer`�)';
comment on column VWRTAG.SVALUE is '������������ �������� ��� Viewer`�';
----------------------------------------------

create table SYS_PRIV(
   ID      DGUID_NN
  ,UID     DGUID_NN
  ,OBJ     DGUID_NN
  ,ROOT    DGUID
  ,OPERS   DBIGINT_NN
  ,STATE   DINT_NN   default 0
  ,MODDT   DDT_NN    default current_timestamp
  ,MODUSER DGUID_NN
);
alter table SYS_PRIV add constraint PK_SYS_PRIV primary key(ID);
alter table SYS_PRIV add constraint FK_SYS_PRIV_1 foreign key(UID) references SUBJECTS(ID);
alter table SYS_PRIV add constraint FK_SYS_PRIV_2 foreign key(OBJ) references SYSTREE(ID);
alter table SYS_PRIV add constraint FK_SYS_PRIV_3 foreign key(ROOT) references SYSTREE(ID);
alter table SYS_PRIV add constraint UNQ1_SYS_PRIV unique(UID,OBJ,ROOT);
comment on table  SYS_PRIV is '���������� �� ���� ������';
comment on column SYS_PRIV.UID is 'SUBJECTS.ID, ������� (������������ ��� ����)';
comment on column SYS_PRIV.OBJ is 'SYSTREE.ID';
comment on column SYS_PRIV.ROOT is 'SYSTREE.ID';
comment on column SYS_PRIV.OPERS is '������� ����� ���������� (��. ����. SYS_OPERS)';
comment on column SYS_PRIV.STATE is '������� ����:
 0 - ������
 1 - reserved
 2 - �������
';
--------------------------------------
create global temporary table GTT_PRIVS(
   OBJ     DGUID
  ,ROOT    DGUID
  ,OPERS   DBIGINT
) on commit preserve rows;
grant select on GTT_PRIVS to public;
alter table GTT_PRIVS add constraint UNQ1_GTT_PRIVS unique(OBJ,ROOT);
comment on table  GTT_PRIVS is '����������� ���������� ������������.';
--------------------------------------

create table SYS_OPERS(
   ID      DINT_NN
  ,NAME    DVCHAR16
  ,CAPTION DVCHAR80
  ,STATE   DINT_NN
);
alter table SYS_OPERS add constraint PK_SYS_OPERS primary key(ID);
alter table SYS_OPERS add constraint UNQ1_SYS_OPERS unique(NAME);
comment on table  SYS_OPERS is '���������� ����������';
comment on column SYS_OPERS.ID is '����� ���� � SYSPRIV.OPERS (�� ����)';
comment on column SYS_OPERS.NAME is '������������� ID';

create or alter trigger SYS_OPERS_BIU for SYS_OPERS
active before insert or update position 100
as
begin
  new.NAME = upper(new.NAME);
end;
----------------------------------------
insert into SYS_OPERS(ID,NAME,CAPTION) values(0,'select','��������');
insert into SYS_OPERS(ID,NAME,CAPTION) values(1,'insert','����������');
insert into SYS_OPERS(ID,NAME,CAPTION) values(2,'update','���������');
insert into SYS_OPERS(ID,NAME,CAPTION) values(3,'delete','��������');
insert into SYS_OPERS(ID,NAME,CAPTION) values(4,'spetial','������������');
commit work;

/******************************************************************************/
/***                               Triggers                                 ***/
/******************************************************************************/

create or alter function CHECKLOGIN
returns DINT
as begin
  return null;
end;

create or alter function SYS_LOGINID
returns DGUID
as
begin
  return null;
end;

create or alter trigger BUFF_CORRECT_KOP for BUFF
active before insert or update position 100
as
begin
  new.KOP = abs(new.KOP);
end;
----------------------------------------------

create or alter trigger KOPS_BI for KOPS
active before insert position 100
as
declare variable i DINT;
begin
  if (new.ID_KOPS is null) then
    new.ID_KOPS = gen_id(GEN_KOPS_ID,1);
  if (NEW.KOP is null) then
  begin
    select max(KOPS.KOP) from KOPS into :i;
    if (:i is null) then i=0;
    new.KOP=:i+1;
  end
  if (new.KOP_PRIOR is null) then
  begin
    select max(KOPS.KOP_PRIOR) from KOPS into :i;
    if (:i is null) then i=0;
    new.KOP_PRIOR=:i+1;
  end
end;
grant select on KOPS to trigger KOPS_BI;
grant usage on sequence GEN_KOPS_ID to trigger KOPS_BI;
----------------------------------------------

create or alter trigger TR_CONNECT
active on connect position 0
as
  declare variable STAGE DINT;
begin
  in autonomous transaction do
    STAGE = CheckLogin();
  -- ������ � disconnect, ���� ������
  if (current_user = 'SYSDBA') then exit;
  if (:STAGE = 1) then
    exception EX_COMMON '������������ ������ ��� ��� ������������';
  if (:STAGE = 2) then
    exception EX_COMMON '������ ��������';
end;
grant usage on exception EX_COMMON to trigger TR_CONNECT;
grant execute on function CHECKLOGIN to trigger TR_CONNECT;
----------------------------------------------

create or alter trigger TR_DISCONNECT
active on disconnect position 0
as
begin
  update LOGINS t set
     t.TIME_OFF = current_timestamp
    ,t.STAGE = 4
    where t.ID = sys_LoginID()
  ;
end;
grant select, update on LOGINS to trigger TR_DISCONNECT;
----------------------------------------------

create or alter trigger T_BI_BUFF for BUFF
active before insert position 100
as
begin
  if (new.ID_BUFF is null) then
    new.ID_BUFF = GEN_ID(GEN_ID_BUFF,1);
  if (new.SDT is null) then
    new.SDT = 'NOW';
end;
grant usage on sequence GEN_ID_BUFF to trigger T_BI_BUFF;
----------------------------------------------

create or alter trigger SUBJECTS_BIU for SUBJECTS
active before insert or update position 100
as
begin
  new.LOGIN = upper(new.LOGIN);
  if (new.GRP <> 0 or coalesce(new.LOGIN,'') = '') then
    new.LOGIN = upper(new.NAME);
end
----------------------------------------------