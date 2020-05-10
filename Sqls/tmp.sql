
create table SYS_PRIVTYPES(
   ID     DGUID_NN
  ,VIEWER DINT_NN
  ,MASK   DINT_NN
  ,NAME   DVCHAR32
  ,NOTE   DVCHAR64
  ,STATE  DINT_NN
);
alter table SYS_PRIVTYPES add constraint PK_SYS_PRIVTYPES primary key(ID);
alter table SYS_PRIVTYPES add constraint FK_SYS_PRIVTYPES foreign key(VIEWER) references SYSVIEWERS(ID);
alter table SYS_PRIVTYPES add constraint UNQ1_SYS_PRIVTYPES unique(NAME);
comment on table  SYS_PRIVTYPES is '—правочник операций Viewers';
comment on column SYS_PRIVTYPES.VIEWER is 'SYSVIEWERS.ID';
comment on column SYS_PRIVTYPES.MASK is
'должен быть установлен один бит - маска операции в поле SYS_PRIV.PRIVS
 биты 0..3 зарезервированы дл€ общих операций редактировани€';
comment on column SYS_PRIVTYPES.STATE is '
 0 - удалено
 1 - reserved
 2 - reserved
';

create or alter trigger TBI_SYS_PRIVTYPES for SYS_PRIVTYPES
  active before insert or update position 0
as
begin
  new.NAME = upper(new.NAME);
end;

----------------------------------------------

create table SYS_PRIV(
   ID       DGUID_NN
  ,ID_OWN   DGUID      -- self.ID
  ,ID_NODE  DGUID
  ,ID_USER  DGUID
  ,PRIVS    DINT_NN
  ,STATE    DINT_NN
);
alter table SYS_PRIV add constraint PK_SYS_PRIV primary key(ID);
alter table SYS_PRIV add constraint FK_SYS_PRIV_1 foreign key(ID_OWN) references SYS_PRIV(ID);
alter table SYS_PRIV add constraint FK_SYS_PRIV_2 foreign key(ID_NODE) references SYSTREE(ID);
alter table SYS_PRIV add constraint FK_SYS_PRIV_3 foreign key(ID_USER) references SYS_USERS(ID);
comment on table  SYS_PRIV is 'ћатрица доступа';
comment on column SYS_PRIV.ID_OWN is
'ƒл€ узлов структуры объектов - ссылка на SYS_PRIV Owner`а объекта; null дл€ обычных узлов';
comment on column SYS_PRIV.ID_NODE is 'SYSTREE.ID';
comment on column SYS_PRIV.ID_NODE is 'SYS_USERS.ID';
comment on column SYS_PRIV.PRIVS is 'Ѕиты привилегий:
 0 - select
 1 - insert
 2 - delete
 3 - update
 прочие биты/операции у каждого Viewer`а свои (SYS_PRIV_TYPES)';
comment on column SYS_PRIV.STATE is '
 0 - удалено
 1 - enabled
 2 - призрак
';
----------------------------------------------

--*******************************************************
--*******************************************************

create or alter view SYS_PRIVTYPES$VW
as select * from SYS_PRIVTYPES T;
----------
grant select on SYS_PRIVTYPES to view SYS_PRIVTYPES$VW;
grant select on SYS_PRIVTYPES$VW to IT,RWORKER;
----------------------------------------------

create or alter view SYS_PRIVTYPES$VWE
as
  select * from SYS_PRIVTYPES T
  where BITGET(t.STATE, 0) = 0
;
----------
grant select on SYS_PRIVTYPES to view SYS_PRIVTYPES$VWE;
grant select on SYS_PRIVTYPES$VWE to IT,RWORKER;
----------------------------------------------

create or alter view SYS_PRIV$VW
as
  select * from SYS_PRIV T
;
----------
grant select on SYS_PRIV to view SYS_PRIV$VW;
grant select on SYS_PRIV$VW to IT,RWORKER;
----------------------------------------------

create or alter view SYS_PRIV$VWE
as
  select * from SYS_PRIV T
  where BITGET(t.STATE, 0) = 0
;
----------
grant select on SYS_PRIV to view SYS_PRIV$VWE;
grant select on SYS_PRIV$VWE to IT,RWORKER;

--*******************************************************
--*******************************************************

create or alter procedure SYS_PRIVTYPES$(
    AOPERATION DINT,
    ID     type of column SYS_PRIVTYPES.ID,
    VIEWER type of column SYS_PRIVTYPES.VIEWER,
    MASK   type of column SYS_PRIVTYPES.MASK,
    NAME   type of column SYS_PRIVTYPES.NAME,
    NOTE   type of column SYS_PRIVTYPES.NOTE,
    STATE  type of column SYS_PRIVTYPES.STATE
)returns(
  OUT_ID type of column SYS_PRIVTYPES.ID
)as
  declare variable STAT type of column SYS_PRIVTYPES.STATE;
begin
  :OUT_ID = :ID;
  :NAME = upper(:NAME);
  if (:AOPERATION = 0) then -- вставка или восстановление?
  begin
    select t.ID,t.STATE
    from SYS_PRIVTYPES t
    where t.NAME = :NAME
    into :OUT_ID,:STAT;
    if (row_count > 0) then
    begin
      :AOPERATION = 1;
      :STATE = coalesce(:STATE,BitSet(:STAT,0,0));
    end
  end
  ---
  if (:AOPERATION = 0) then -- вставка
  begin
    :OUT_ID = coalesce(:ID, gen_uuid());
    insert into SYS_PRIVTYPES(ID,VIEWER,MASK,NAME,NOTE,STATE)
    values (:OUT_ID,:VIEWER,:MASK,:NAME,:NOTE,BITSET(coalesce(:STATE,0),2,0));
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SYS_PRIVTYPES A
    set A.NAME = coalesce(:NAME,A.NAME),
        A.NOTE = coalesce(:NOTE,A.NOTE),
        A.STATE = BITSET(coalesce(:STATE,A.STATE),2,0)
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SYS_PRIVTYPES A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0)
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into SYS_PRIVTYPES(ID,VIEWER,MASK,NAME,NOTE,STATE)
    values(:OUT_ID,:VIEWER,:MASK,:NAME,:NOTE,:STATE)
    matching(ID);
  end
  else
    exception EX_COMMON 'Ќекорректный код операции: '|| :AOPERATION;
  if ( AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(4000,:OUT_ID);
  suspend;
end;
----------
comment on parameter SYS_PRIVTYPES$.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление, 3 - обмен';
grant all on SYS_PRIVTYPES to procedure SYS_PRIVTYPES$;
grant execute on procedure BUFF$SEND to procedure SYS_PRIVTYPES$;
grant execute on procedure SYS_PRIVTYPES$ to IT;
---------------------------------

create or alter procedure EX_SYS_PRIVTYPES(
    ID     type of column SYS_PRIVTYPES.ID,
    VIEWER type of column SYS_PRIVTYPES.VIEWER,
    MASK   type of column SYS_PRIVTYPES.MASK,
    NAME   type of column SYS_PRIVTYPES.NAME,
    NOTE   type of column SYS_PRIVTYPES.NOTE,
    STATE  type of column SYS_PRIVTYPES.STATE
)as
  declare variable OUT_ID type of column SYS_PRIVTYPES.ID;
begin
  execute procedure SYS_PRIVTYPES$(3,
    :ID,:VIEWER,:MASK,:NAME,:NOTE,:STATE
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure SYS_PRIVTYPES$ to procedure EX_SYS_PRIVTYPES;
grant execute on procedure EX_SYS_PRIVTYPES to IT,OBMEN;
---------------------------------

create or alter procedure SYS_PRIVTYPES$EDITS(
    AOPERATION DINT,
    iID type of column SYS_PRIVTYPES.ID,
    iVIEWER type of column SYS_PRIVTYPES.VIEWER,
    iMASK   type of column SYS_PRIVTYPES.MASK,
    iNAME type of column SYS_PRIVTYPES.NAME,
    iNOTE type of column SYS_PRIVTYPES.NOTE,
    iSTATE type of column SYS_PRIVTYPES.STATE
)returns (
    ID type of column SYS_PRIVTYPES.ID,
    VIEWER type of column SYS_PRIVTYPES.VIEWER,
    MASK   type of column SYS_PRIVTYPES.MASK,
    NAME type of column SYS_PRIVTYPES.NAME,
    NOTE type of column SYS_PRIVTYPES.NOTE,
    STATE type of column SYS_PRIVTYPES.STATE
)as
  declare variable OUT_ID type of column SYS_PRIVTYPES.ID;
begin
  execute procedure SYS_PRIVTYPES$(:AOPERATION,
    :iID,:iVIEWER,:iMASK,:iNAME,:iNOTE,:iSTATE
  )returning_values :OUT_ID;
  select t.ID,t.VIEWER,t.MASK,t.NAME,t.NOTE,t.STATE
  from SYS_PRIVTYPES$VW t
  into :ID,:VIEWER,:MASK,:NAME,:NOTE,:STATE;
  if (row_count > 0) then
    suspend;
end;
----------
comment on parameter SYS_PRIVTYPES$EDITS.AOPERATION is
'0 - вставка, 1 - изменение, 2 - удаление';
grant execute on procedure SYS_PRIVTYPES$ to procedure SYS_PRIVTYPES$EDITS;
grant execute on procedure SYS_PRIVTYPES$EDITS to IT;
---------------------------------
---------------------------------

create or alter procedure SYS_PRIV$(
    AOPERATION DINT,
    ID      type of column SYS_PRIV.ID,
    ID_OWN  type of column SYS_PRIV.ID_OWN,
    ID_NODE type of column SYS_PRIV.ID_NODE,
    ID_USER type of column SYS_PRIV.ID_USER,
    PRIVS   type of column SYS_PRIV.PRIVS,
    STATE   type of column SYS_PRIV.STATE
)returns(
  OUT_ID type of column SYS_PRIV.ID
)as
begin
  :OUT_ID = :ID;
  if (:AOPERATION = 0) then -- вставка
  begin
    :OUT_ID = coalesce(:ID, gen_uuid());
    insert into SYS_PRIV(ID,ID_OWN,ID_NODE,ID_USER,PRIVS,STATE)
    values (:OUT_ID,:ID_OWN,:ID_NODE,:ID_USER,:PRIVS,BITSET(coalesce(:STATE,0),2,0));
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SYS_PRIV A
    set A.ID_OWN = coalesce(:ID_OWN,A.ID_OWN),
        A.ID_NODE = coalesce(:ID_NODE,A.ID_NODE),
        A.ID_USER = coalesce(:ID_USER,A.ID_USER),
        A.PRIVS   = coalesce(:PRIVS,A.PRIVS),
        A.STATE = BITSET(coalesce(:STATE,A.STATE),2,0)
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SYS_PRIV A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0)
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    if (:ID_OWN is not null) then -- добавить, если надо, призрак
      if (not exists(select * from SYS_PRIV t where t.ID = :ID_OWN)) then
        insert into SYS_PRIV(ID,ID_OWN,ID_NODE,ID_USER,PRIVS,STATE)
        values (:ID_OWN,null,:ID_NODE,:ID_USER,:PRIVS,5)
    ;
    update or insert into SYS_PRIV(ID,ID_OWN,ID_NODE,ID_USER,PRIVS,STATE)
    values(:OUT_ID,:ID_OWN,:ID_NODE,:ID_USER,:PRIVS,:STATE)
    matching(ID);
  end
  else
    exception EX_COMMON 'Ќекорректный код операции: '|| :AOPERATION;
  if ( AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(4500,:OUT_ID);
  suspend;
end;
----------
comment on parameter SYS_PRIV$.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликаци€';
grant all on SYS_PRIV to procedure SYS_PRIV$;
grant execute on procedure BUFF$SEND to procedure SYS_PRIV$;
grant execute on procedure SYS_PRIV$ to IT;
---------------------------------

create or alter procedure EX_SYS_PRIV(
  ID      type of column SYS_PRIV.ID,
  ID_OWN  type of column SYS_PRIV.ID_OWN,
  ID_NODE type of column SYS_PRIV.ID_NODE,
  ID_USER type of column SYS_PRIV.ID_USER,
  PRIVS   type of column SYS_PRIV.PRIVS,
  STATE   type of column SYS_PRIV.STATE
)as
  declare variable OUT_ID type of column SYS_PRIV.ID;
begin
  execute procedure SYS_PRIV$(3,
    :ID,:ID_OWN,:ID_NODE,:ID_USER,:PRIVS,:STATE
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure SYS_PRIV$ to procedure EX_SYS_PRIV;
grant execute on procedure EX_SYS_PRIV to IT,OBMEN;
comment on procedure EX_SYS_PRIV is 
'ѕроцедура обмена c магазином дл€ таблицы SYS_PRIV';
---------------------------------

create or alter procedure SYS_PRIV$EDIT(
    AOPERATION DINT,
    ID      type of column SYS_PRIV.ID,
    ID_OWN  type of column SYS_PRIV.ID_OWN,
    ID_NODE type of column SYS_PRIV.ID_NODE,
    ID_USER type of column SYS_PRIV.ID_USER,
    PRIVS   type of column SYS_PRIV.PRIVS,
    STATE   type of column SYS_PRIV.STATE
)returns(
  OUT_ID type of column SYS_PRIV.ID
)as
begin
  execute procedure SYS_PRIV$(:AOPERATION,
    :ID,:ID_OWN,:ID_NODE,:ID_USER,:PRIVS,:STATE
  )returning_values :OUT_ID;
  suspend;
end;
----------
comment on parameter SYS_PRIV$EDIT.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление';
grant execute on procedure SYS_PRIV$ to procedure SYS_PRIV$EDIT;
grant execute on procedure SYS_PRIV$EDIT to IT,RWORKER;
---------------------------------
---------------------------------