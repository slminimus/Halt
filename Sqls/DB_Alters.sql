
SET SQL DIALECT 3;

create or alter function BITGET(
    AVALUE DINT,
    BIT DINT
)returns DINT deterministic
as
begin
  return sign(bin_and(:AVALUE,bin_shl(1,:BIT)));
end;
grant execute on function BITGET to PUBLIC;
----------------------------------------------

create or alter view SEC$USERS$VW(
   USER_NAME
  ,IS_DBA
  ,DESCRIPTION
  ,PLUGIN_NAME
)as
  select distinct t.SEC$USER_NAME,
         iif(t.SEC$ADMIN,1,0) IS_DBA,
         t.SEC$DESCRIPTION,t.SEC$PLUGIN
  from sec$users t
  where t.sec$plugin <> 'Srp'
;
grant select on sec$users to SEC$USERS$VW;
grant select on SEC$USERS$VW to public;
comment on view SEC$USERS$VW is 'Пользователи из sec$users';
----------------------------------------------

create or alter view SUBJLINK$VW(
  ID,UID,GID,URP,GRP,EXPDATE,STATE,MODDT,MODUSER
)as
  select t.ID,t.UID,t.GID,su.GRP URP,sg.GRP GRP,t.EXPDATE,t.STATE,t.MODDT,t.MODUSER
  from SUBJLINK t
  join SUBJECTS su on su.ID = t.UID
  join SUBJECTS sg on sg.ID = t.GID
;
----------
grant select on SUBJLINK to view SUBJLINK$VW;
grant select on SUBJECTS to view SUBJLINK$VW;
grant select on SUBJLINK$VW to IT,RWORKER;
---------------------------------

create or alter view SUBJLINK$VWE
as
  select * from SUBJLINK$VW t
  where BITGET(t.STATE,0) = 0
;
----------
grant select on SUBJLINK$VW to view SUBJLINK$VWE;
grant select on SUBJLINK$VWE to IT,RWORKER;
---------------------------------

create or alter view SUBJLINK$VWA
as
  select * from SUBJLINK$VWE t
  where t.EXPDATE is null or t.EXPDATE < current_date
;
----------
grant select on SUBJLINK$VWE to view SUBJLINK$VWA;
grant select on SUBJLINK$VWA to IT,RWORKER;
---------------------------------

create or alter view SYS_USERS$VW(
  ID,IS_ADMIN,LOGIN,NAME,TABNUM,EXPDATE,PHONE,EMAIL,STATE,MODDT,MODUSER
)as
  with j as(
    select distinct ss.UID
    from SUBJLINK$VWA ss where ss.GRP = 2 and ss.URP = 0
  )
  select t.ID,iif(j.UID is null,0,1) Is_Admin,t.LOGIN,t.NAME,t.TABNUM,
         t.EXPDATE,t.PHONE,t.EMAIL,t.STATE,t.MODDT,t.MODUSER
  from SUBJECTS t
  left join j on j.UID = t.ID
  where t.GRP = 0 -- user
;
grant select on SUBJECTS to SYS_USERS$VW;
grant select on SUBJLINK$VWA to SYS_USERS$VW;
grant select on SEC$USERS$VW to SYS_USERS$VW;
grant select on SYS_USERS$VW to public;
comment on view SYS_USERS$VW is 'Пользователи';
comment on column SYS_USERS$VW.IS_ADMIN is '1, если этот Login имеет админ. роль';
comment on column SYS_USERS$VW.TABNUM is 'Табельный №';
comment on column SYS_USERS$VW.EXPDATE is 'Login разрешен по эту дату (вкл).';
----------------------------------------------

create or alter view SYS_USERS$VWE
as
  select *
  from SYS_USERS$VW t
  where BITGET(t.STATE,0) = 0 -- no deleted
;
grant select on SYS_USERS$VW to SYS_USERS$VWE;
grant select on SYS_USERS$VWE to public;
comment on view SYS_USERS$VWE is 'Не удаленные пользователи';
----------------------------------------------

create or alter view SYS_USERS$VWA
as
  select * from SYS_USERS$VWE t
  where BITGET(t.STATE,1) = 0 -- enabled
;
grant select on SYS_USERS$VWE to SYS_USERS$VWA;
grant select on SYS_USERS$VWA to public;
comment on view SYS_USERS$VWA is 'Активные пользователи';
----------------------------------------------

/******************************************************************************/
/***                            Stored functions                            ***/
/******************************************************************************/

create or alter function ASSERT(
    COND DBOOL,
    MSG DTEXT
)returns DBOOL
as
begin
  if (:Cond) then return true;
  exception EX_COMMON :MSG;
end;
grant execute on function ASSERT to public;
----------------------------------------------

create or alter function ASUUID(
  STR DGUID_STR
)returns DGUID
as
begin
  if(:Str = '' or :Str is null) then
    return null;
  if (char_length(:Str) = 36) then
    return char_to_uuid(:Str);
  if (char_length(:Str) = 16) then
    return :Str;
  exception EX_COMMON 'ASUUID: недопустимое значение параметра: "'|| :STR ||'"';
end;
grant execute on function ASUUID to public;
----------------------------------------------

create or alter function BITSET(
    AVALUE DINT,
    BIT DINT,
    STATE DINT
)returns DINT deterministic
as
begin
  if (:STATE = 0) then
    return bin_and(:AVALUE,bin_not(bin_shl(1,:BIT)));
  else
    return bin_or(:AVALUE,bin_shl(1,:BIT));
end;
grant execute on function BITSET to public;
----------------------------------------------

create or alter function SYS_USERID
returns DGUID
as
begin
  return rdb$get_context('USER_SESSION','ID_USER');
--  return (select first 1 t.ID_USER from SYSENV t);
end;
--grant all on SYSENV to function SYS_USERID;
grant execute on function SYS_USERID to public;
----------------------------------------------

create or alter function IS_DBA
returns DINT
as
begin
  return(
    select first 1 t.IS_DBA
    from SEC$USERS$VW t where t.USER_NAME = current_user
  );
end;
grant execute on function IS_DBA to public;
----------------------------------------------

create or alter function IS_ADMIN(UID DGUID_STR = null)
returns DINT
as
  declare variable IsAdmin DINT;
begin
  :UID = ASUUID(:UID);
  :UID = coalesce(:UID,SYS_USERID());
  select first 1 sign(t.IS_ADMIN+coalesce(s.IS_DBA,0))
  from SYS_USERS$VWE t
  left join SEC$USERS$VW s on s.USER_NAME = t.LOGIN
  where t.ID = SYS_USERID()
  into :IsAdmin;
  if (:IsAdmin = 0 or :UID = SYS_USERID()) then
    return :IsAdmin;
  select first 1 t.IS_ADMIN
  from SYS_USERS$VWE t
  where t.ID = :UID
  into :IsAdmin;
  return :IsAdmin;
end;
grant execute on function ASUUID to function IS_ADMIN;
grant execute on function SYS_USERID to function IS_ADMIN;
grant select on SYS_USERS$VWE to function IS_ADMIN;
grant select on SEC$USERS$VW to function IS_ADMIN;
grant execute on function IS_ADMIN to public;
----------------------------------------------

create or alter function SYS_KODFIL
returns DINT
as
begin
  return rdb$get_context('USER_SESSION','KODFIL');
end;
grant execute on function SYS_KODFIL to PUBLIC;
----------------------------------------------

create or alter function SYS_LOGINID
returns DGUID
as
begin
  return rdb$get_context('USER_SESSION','ID_LOGIN');
end;
grant execute on function SYS_LOGINID to PUBLIC;
----------------------------------------------

/******************************************************************************/
/***                                 Views                                  ***/
/******************************************************************************/

create or alter view TCDBINFO$VW
as
  select * from TCDBINFO
;
grant select on TCDBINFO to TCDBINFO$VW;
grant select on TCDBINFO$VW to public;
----------------------------------------------

create or alter view SUBJECTS$VW
as
  select * from SUBJECTS t
;
grant select on SUBJECTS to SUBJECTS$VW;
grant select on SUBJECTS$VW to public;
----------------------------------------------

create or alter view SUBJECTS$VWE
as
  select * from SUBJECTS t
  where BITGET(t.STATE,0) = 0
;
grant select on SUBJECTS to SUBJECTS$VWE;
grant select on SUBJECTS$VWE to public;
comment on view SUBJECTS$VWE is 'Не удаленные субъекты';
----------------------------------------------

create or alter view SUBJECTS$VWA
as
  select * from SUBJECTS t
  where BITGET(t.STATE,0) = 0 -- no deleted
    and BITGET(t.STATE,1) = 0 -- enabled
;
grant select on SUBJECTS to SUBJECTS$VWA;
grant select on SUBJECTS$VWA to public;
comment on view SUBJECTS$VWA is 'Активные субъекты';
----------------------------------------------

create or alter view SYS_ROLES$VW(
  ID,GRP,NAME,STATE,MODDT,MODUSER
)as
  select t.ID,t.GRP,t.NAME,t.STATE,t.MODDT,t.MODUSER
  from SUBJECTS t
  where t.GRP > 0 -- role
    and BITGET(t.STATE,3) = 0 -- not hidden
;
grant select on SUBJECTS to SYS_ROLES$VW;
grant select on SYS_ROLES$VW to public;
comment on view SYS_ROLES$VW is 'Роли';
----------------------------------------------

create or alter view SYS_ROLES$VWE
as
  select * from SYS_ROLES$VW t
  where BITGET(t.STATE,0) = 0 -- no deleted
;
grant select on SYS_ROLES$VW to SYS_ROLES$VWE;
grant select on SYS_ROLES$VWE to public;
comment on view SYS_ROLES$VWE is 'Не удаленные роли';
----------------------------------------------

create or alter view SYS_ROLES$VWA
as
  select * from SYS_ROLES$VWE t
  where BITGET(t.STATE,1) = 0 -- enabled
;
grant select on SYS_ROLES$VWE to SYS_ROLES$VWA;
grant select on SYS_ROLES$VWA to public;
comment on view SYS_ROLES$VWA is 'Активные роли';
----------------------------------------------

create or alter view SYS_APPOINTS$VW(
  ID,GRP,NAME,STATE,MODDT,MODUSER
)as
  select t.ID,t.GRP,t.NAME,t.STATE,t.MODDT,t.MODUSER
  from SUBJECTS t
  where t.GRP < 0 -- appoint
    and BITGET(t.STATE,3) = 0 -- not hidden
;
grant select on SUBJECTS to SYS_APPOINTS$VW;
grant select on SYS_APPOINTS$VW to public;
comment on view SYS_APPOINTS$VW is 'Должности';
----------------------------------------------

create or alter view SYS_APPOINTS$VWE
as
  select * from SYS_APPOINTS$VW t
  where BITGET(t.STATE,0) = 0 -- no deleted
;
grant select on SYS_APPOINTS$VW to SYS_APPOINTS$VWE;
grant select on SYS_APPOINTS$VWE to public;
comment on view SYS_APPOINTS$VWE is 'Не удаленные должности';
----------------------------------------------

create or alter view SYS_APPOINTS$VWA
as
  select * from SYS_APPOINTS$VWE t
  where BITGET(t.STATE,1) = 0 -- enabled
;
grant select on SYS_APPOINTS$VWE to SYS_APPOINTS$VWA;
grant select on SYS_APPOINTS$VWA to public;
comment on view SYS_APPOINTS$VWA is 'Активные должности';
----------------------------------------------
----------------------------------------------

create or alter view BUFF$VW
as
  select * from BUFF t
;
grant select on BUFF to BUFF$VW;
grant select on BUFF$VW to public;
----------------------------------------------

create or alter view KOPS$VW
as
  select * from KOPS
;
grant select on KOPS to KOPS$VW;
grant select on KOPS$VW to public;
----------------------------------------------

create or alter view KOPS$VWE
as
  select * from KOPS t
  where BITGET(t.STATE, 0) = 0
    and BITGET(t.STATE, 1) = 0
;
grant select on KOPS to KOPS$VWE;
grant select on KOPS$VWE to public;
----------------------------------------------

create or alter view LOGOBMEN$VW
as
  select * from LOGOBMEN
;
grant select on LOGOBMEN to LOGOBMEN$VW;
grant select on LOGOBMEN$VW to public;
----------------------------------------------

create or alter view FILLIST$VW
as
  select * from FILLIST t
;
grant select on FILLIST to VW_FILLIST$VW;
grant select on FILLIST$VW to public;
----------------------------------------------

create or alter view FILLIST$VWE
as
  select * from FILLIST t
  where BITGET(t.STATE, 0) = 0
;
grant select on FILLIST to VW_FILLIST$VWE;
grant select on FILLIST$VWE to public;
----------------------------------------------

create or alter view FILLIST$VWA
as
  select * from FILLIST t
  where BITGET(t.STATE,0) = 0 -- no deleted
    and BITGET(t.STATE,1) = 0 -- enabled
;
grant select on FILLIST to VW_FILLIST$VWA;
grant select on FILLIST$VWA to public;
----------------------------------------------

create or alter view SHOPS$VW
as
  select * from FILLIST$VW t
  where t.TYPE_OBJECT = 1
;
grant select on FILLIST$VW to SHOPS$VW;
grant select on SHOPS$VW to public;
----------------------------------------------

create or alter view SHOPS$VWE
as
  select * from FILLIST$VWE t
  where t.TYPE_OBJECT = 1
;
grant select on FILLIST$VWE to SHOPS$VWE;
grant select on SHOPS$VWE to public;
----------------------------------------------

create or alter view SYSTREE$VW
as
  select *
  from SYSTREE t
;
grant select on SYSTREE to SYSTREE$VW;
grant select on SYSTREE$VW to public;
----------------------------------------------

create or alter view SYSTREE$VWE
as
  select * from SYSTREE$VW t
  where BITGET(t.STATE, 0) = 0
;
grant select on SYSTREE$VW to SYSTREE$VWE;
grant select on SYSTREE$VWE to public;
comment on view SYSTREE$VWE is 'Не удаленные узлы';
----------------------------------------------

create or alter view SYSVIEWERS$VW
as
  select * from SYSVIEWERS t
;
grant select on SYSVIEWERS to SYSVIEWERS$VW;
grant select on SYSVIEWERS$VW to public;
----------------------------------------------

create or alter view SYSVIEWERS$VWE
as
  select * from SYSVIEWERS t
  where BITGET(t.STATE, 0) = 0
;
grant select on SYSVIEWERS to SYSVIEWERS$VWE;
grant select on SYSVIEWERS$VWE to public;
comment on view SYSVIEWERS$VWE is 'Действующие viewers';
----------------------------------------------

create or alter view VWRTAG$VW
as select * from VWRTAG T;
----------
grant select on VWRTAG to view VWRTAG$VW;
grant select on VWRTAG$VW to IT,RWORKER;
----------------------------------------------
----------------------------------------------

create or alter view SYS_PRIV$VW
as select * from SYS_PRIV;
grant select on SYS_PRIV to SYS_PRIV$VW;
grant select on SYS_PRIV$VW to public;
----------------------------------------

create or alter view SYS_PRIV$VWE
as
  select * from SYS_PRIV t
  where BITGET(t.STATE, 0) = 0
;
grant select on SYS_PRIV to SYS_PRIV$VWE;
grant select on SYS_PRIV$VWE to public;
----------------------------------------

create or alter view SYS_OPERS$VW
as
  select * from SYS_OPERS
;
grant select on SYS_OPERS to SYS_OPERS$VW;
grant select on SYS_OPERS$VW to public;
----------------------------------------

create or alter view SYS_OPERS$VWE
as
  select * from SYS_OPERS$VW t
  where BITGET(t.STATE, 0) = 0
;
grant select on SYS_OPERS$VW to SYS_OPERS$VWE;
grant select on SYS_OPERS$VWE to public;
----------------------------------------

/******************************************************************************/
/***                            Stored functions                            ***/
/******************************************************************************/

create or alter function CHECKLOGIN
returns DINT
as
  declare variable ID_LOGIN type of column LOGINS.ID;
  declare variable LOGIN    type of column LOGINS.LOGIN;
  declare variable STAGE    type of column LOGINS.STAGE;
  declare variable ID_USER  type of column SUBJECTS.ID;
  declare variable STATE    DINT;
  declare variable KODFIL   type of column TCDBINFO.KODFIL;
begin
  STAGE = 0; -- фиксируем попытку подключения
  ID_LOGIN = gen_uuid();
  insert into LOGINS(ID,LOGIN,TIME_ON,TIME_OFF,IP,PROCESS,STAGE)
    values(:ID_LOGIN,current_user,current_timestamp,null,
         rdb$get_context('SYSTEM','CLIENT_ADDRESS'),
         rdb$get_context('SYSTEM','CLIENT_PROCESS'),
         :STAGE
  );
  -- проверяем
  select t.ID,BITGET(t.STATE,1)
  from SYS_USERS$VWE t
  where t.LOGIN = current_user
  into :ID_USER,:STATE;
  STAGE = iif(row_count = 0,1,iif(:STATE = 0,3,2)); -- 1|2|3: bad|disabled|ok
  -- результат проверки записать в LOGINS
  update LOGINS t set
    t.STAGE = :STAGE
  where t.ID = :ID_LOGIN;
  -- переменные окружения
  if (:STAGE = 3) then begin
    select first 1 t.KODFIL
    from TCDBINFO$VW t
    into :KODFIL;
    rdb$set_context('USER_SESSION','ID_LOGIN',:ID_LOGIN);
    rdb$set_context('USER_SESSION','ID_USER',:ID_USER);
    rdb$set_context('USER_SESSION','KODFIL',:KODFIL);
    --    insert into SYSENV(ID_LOGIN,LOGIN,ID_USER) values(:ID_LOGIN,current_user,:ID_USER)
  end
  return STAGE;
end;
grant execute on function BITGET to function CHECKLOGIN;
grant all    on LOGINS           to function CHECKLOGIN;
grant select on SYS_USERS$VWE    to function CHECKLOGIN;
grant select on TCDBINFO$VW      to function CHECKLOGIN;
--GRANT ALL ON SYSENV TO function CHECKLOGIN;
comment on function CHECKLOGIN is 'Проверка доступности авторизации';
----------------------------------------------

/******************************************************************************/
/***                           Stored procedures                            ***/
/******************************************************************************/

create or alter procedure SPLITSTR(
     S          DTEXT
    ,SPLITTER   char(1) = ','
    ,LASTIGNORE DINT = 0
)returns(
    ITEM DTEXT
)as
  declare variable i DINT;
  declare variable n DINT;
begin
  if (:S is null) then
    exit;
  :i = 1;
  :n = 1;
  while (:i > 0) do
  begin
    :i = position(:Splitter, :S, :n);
    if (:i < 1) then
      :Item = substring(:S from :n);
    else
      :Item = substring(:S from :n for :i - :n);
    if (:SPLITTER <> ' ') then
      :Item = trim(:Item);
    if (:i > 0 or :Item <> '' or :LASTIGNORE = 0) then
      suspend;
    :n = :i + 1;
  end
end;
grant execute on procedure SPLITSTR to public;
comment on procedure SPLITSTR is
'разделить строку по символам SPLITTER и вернуть в виде resultset';
comment on parameter SPLITSTR.LASTIGNORE is 'Игнорировать пустые конечные элементы';
---------------------------------------------------

create or alter procedure LISTINT(
     S          DTEXT
    ,SPLITTER char(1) = ','
    ,LASTIGNORE DINT = 0
)returns(
    ITEM DINT
)as
begin
  for
    select cast(nullif(s.ITEM, '') as DINT)
    from SplitStr(:S, :Splitter, :LASTIGNORE) s
    into :ITEM
  do suspend;
end;
grant execute on procedure LISTINT to public;
comment on procedure LISTINT is
'Обертка над SplitStr; кастит элементы к целому, пустые строки преобразует в null';
---------------------------------------------------

create or alter procedure BUFF$SEND(
     KOP        type of column BUFF.KOP
    ,ID_GUID    type of column BUFF.ID_GUID
    ,ID_DATA    type of column BUFF.ID_DATA = null
    ,KODFIL     DINT = null
)as
  declare variable SourCODE type of column BUFF.SOURCODE;
begin
  SourCODE = SYS_KODFIL();
  if ( :SourCODE = 0 ) then -- БД офиса, передать во все магазины
    exception EX_COMMON 'Системная ошибка: код подразделения - нуль';

  if ( :SourCODE = 1 ) then  -- БД офиса
  begin
    if (KODFIL is null) then --  передать во все магазины
    begin
      insert into BUFF(KOP,SourCODE,DestCODE,ID_Data,ID_GUID)
      select :KOP,:SourCODE,t.KODFIL,:ID_Data,:ID_GUID
      from SHOPS$VWE t;
    end
    else                      -- передать в конкретный магазин
      insert into BUFF(KOP,SourCODE,DestCODE,ID_Data,ID_GUID)
      values(:KOP,:SourCODE,:KODFIL,:ID_Data,:ID_GUID);
  end
  else
  begin                       -- передать в офис
      insert into BUFF(KOP,SourCODE,DestCODE,ID_Data,ID_GUID)
      values(:KOP,:SourCODE,1,:ID_Data,:ID_GUID);
  end
end;
grant execute on function SYS_KODFIL to procedure BUFF$SEND;
grant usage on exception EX_COMMON to procedure BUFF$SEND;
grant insert on BUFF to procedure BUFF$SEND;
grant select on SHOPS$VWE to procedure BUFF$SEND;
grant execute on procedure BUFF$SEND to IT,OBMEN;
----------------------------------------------
----------------------------------------------

create or alter procedure KOPS$(
    AOPERATION   DINT,
    ID_KOPS      type of column KOPS.ID_KOPS,
    KOP          type of column KOPS.KOP,
    KOP_PRIOR    type of column KOPS.KOP_PRIOR,
    KOP_COMMENTS type of column KOPS.KOP_COMMENTS,
    DIRECTION    type of column KOPS.DIRECTION,
    QUERY        type of column KOPS.QUERY,
    STATE        type of column KOPS.STATE
)returns(
    OUT_ID type of column KOPS.ID_KOPS
)as
begin
  :OUT_ID = :ID_KOPS;
  :QUERY = coalesce(:QUERY, '');
  :STATE = coalesce(:STATE, 0);
  if (:AOPERATION = 0) then -- вставка
  begin
    :OUT_ID = coalesce(:OUT_ID, gen_id(GEN_KOPS_ID,1));
    insert into KOPS(ID_KOPS,STATE,KOP,KOP_PRIOR,KOP_COMMENTS,DIRECTION,QUERY)
    values(:OUT_ID,BITSET(coalesce(:STATE,0),2,0),:KOP,:KOP_PRIOR,:KOP_COMMENTS,:DIRECTION,:QUERY);
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update KOPS A
    set A.STATE        = BITSET(coalesce(:STATE, A.STATE),2,0),
        A.KOP          = coalesce(:KOP, A.KOP),
        A.KOP_PRIOR    = coalesce(:KOP_PRIOR, A.KOP_PRIOR),
        A.KOP_COMMENTS = coalesce(:KOP_COMMENTS, A.KOP_COMMENTS),
        A.DIRECTION    = coalesce(:DIRECTION, A.DIRECTION),
        A.QUERY        = coalesce(:QUERY, A.QUERY)
    where (A.ID_KOPS = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update KOPS a
    set a.STATE = BITSET(BITSET(A.STATE,0,1),2,0)
    where (a.ID_KOPS = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into KOPS(ID_KOPS,STATE,KOP,KOP_PRIOR,KOP_COMMENTS,DIRECTION,QUERY)
    values (:OUT_ID,:STATE,:KOP,:KOP_PRIOR,:KOP_COMMENTS,:DIRECTION,:QUERY)
    matching (ID_KOPS);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| coalesce(:AOPERATION, 'null');
  if ( AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(5,null,:OUT_ID);
  suspend;
end;
grant all on KOPS to procedure KOPS$;
grant insert on BUFF to procedure KOPS$;
grant usage on sequence GEN_KOPS_ID to procedure KOPS$;
grant execute on procedure BUFF$SEND to procedure KOPS$;
grant execute on procedure KOPS$ to IT,OBMEN;
comment on parameter KOPS$.AOPERATION is
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация';
----------------------------------------------

create or alter procedure KOPS$Edits(
  AOPERATION    DINT,
  iID_KOPS      type of column KOPS.ID_KOPS,
  iKOP          type of column KOPS.KOP,
  iKOP_PRIOR    type of column KOPS.KOP_PRIOR,
  iKOP_COMMENTS type of column KOPS.KOP_COMMENTS,
  iDIRECTION    type of column KOPS.DIRECTION,
  iQUERY        type of column KOPS.QUERY,
  iSTATE        type of column KOPS.STATE
)returns(
  ID_KOPS      type of column KOPS.ID_KOPS,
  KOP          type of column KOPS.KOP,
  KOP_PRIOR    type of column KOPS.KOP_PRIOR,
  KOP_COMMENTS type of column KOPS.KOP_COMMENTS,
  DIRECTION    type of column KOPS.DIRECTION,
  QUERY        type of column KOPS.QUERY,
  STATE        type of column KOPS.STATE
)as
begin
  execute procedure KOPS$(:AOPERATION,
    :iID_KOPS,:iKOP,:iKOP_PRIOR,:iKOP_COMMENTS,:iDIRECTION,:iQUERY,:iSTATE
  )returning_values :ID_KOPS;
  ---
  select t.ID_KOPS,t.KOP,t.KOP_PRIOR,t.KOP_COMMENTS,t.DIRECTION,t.QUERY,t.STATE
  from KOPS$VWE t where t.ID_KOPS = :ID_KOPS
  into    :ID_KOPS, :KOP, :KOP_PRIOR, :KOP_COMMENTS, :DIRECTION, :QUERY, :STATE;
  if (row_count > 0) then
    suspend;
end;
grant execute on procedure KOPS$ to procedure KOPS$EDITS;
grant select on KOPS$VWE to procedure KOPS$EDITS;
grant execute on procedure KOPS$EDITS to IT,OBMEN;
-----------------------------------------------

create or alter procedure EX_KOPS(
    ID_KOPS      type of column KOPS.ID_KOPS,
    KOP          type of column KOPS.KOP,
    KOP_PRIOR    type of column KOPS.KOP_PRIOR,
    KOP_COMMENTS type of column KOPS.KOP_COMMENTS,
    DIRECTION    type of column KOPS.DIRECTION,
    QUERY        type of column KOPS.QUERY,
    STATE        type of column KOPS.STATE)
as
declare variable OUT_ID type of column KOPS.ID_KOPS;
begin
  execute procedure KOPS$(3,
    :ID_KOPS,:KOP,:KOP_PRIOR,:KOP_COMMENTS,:DIRECTION,:QUERY,:STATE
  ) returning_values :OUT_ID;
end;
grant execute on procedure KOPS$ to procedure EX_KOPS;
grant execute on procedure EX_KOPS to OBMEN,IT;
-----------------------------------------------

create or alter procedure LOGOBMEN$ADD(
     ID_BUFF  DBIGINT
    ,SOURCODE DINT
    ,DESTCODE DINT
    ,OK       DINT
    ,CONTEXT  DVCHAR64
    ,MSG      DVCHAR512
)as
begin
  insert into LOGOBMEN(ID,ID_BUFF,SOURCODE,DESTCODE,OK,CONTEXT,MSG,SDT)
  values(gen_uuid(),:ID_BUFF,:SOURCODE,:DESTCODE,:OK,:CONTEXT,:MSG,current_timestamp);
end;
grant insert on LOGOBMEN to procedure LOGOBMEN$ADD;
grant execute on procedure LOGOBMEN$ADD to OBMEN,IT;
-----------------------------------------------
-----------------------------------------------

create or alter procedure MakeUser(
   LOGIN  DVCHAR32
  ,PASS   DVCHAR32
)returns(
  IS_USER DINT
)as
begin
  :LOGIN = upper(:LOGIN);
  execute statement (
    'create or alter user "'|| :LOGIN ||'" password '''|| :PASS ||''''
  ) with autonomous transaction;
  execute statement (
    'grant RWORKER to "'|| :LOGIN ||'"'
  );
  :IS_USER = iif(exists(
    select * from SEC$USERS$VW t where t.USER_NAME = :LOGIN
  ),1,0);
  suspend;
end;
-----------------------------------------------
-----------------------------------------------

create or alter procedure SYSTREE$(
    AOPERATION DINT,
    ID         type of column SYSTREE.ID,
    ID_OWN     type of column SYSTREE.ID_OWN,
    NAME       type of column SYSTREE.NAME,
    OPTIONS    type of column SYSTREE.OPTIONS,
    VIEWER     type of column SYSTREE.VIEWER,
    TAG        type of column SYSTREE.TAG,
    STATE      type of column SYSTREE.STATE,
    MODDT      type of column SYSTREE.MODDT = null,
    MODUSER    type of column SYSTREE.MODUSER = null
)returns(
    OUT_ID type of column SYSTREE.ID
)as
begin
  :OUT_ID = :ID;
  -- автор версии
  if (:AOPERATION <> 3) then 
    MODUSER = SYS_USERID(); 
  if (:AOPERATION = 0) then -- вставка
  begin
    :OUT_ID = coalesce(:OUT_ID, gen_uuid());
    insert into SYSTREE (ID,ID_OWN,NAME,OPTIONS,VIEWER,TAG,STATE,MODDT,MODUSER)
    values(:OUT_ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,
           BitSet(coalesce(:STATE,0),2,0),current_timestamp,:MODUSER
    );
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SYSTREE A
    set A.ID_OWN  = coalesce(:ID_OWN, A.ID_OWN),
        A.NAME    = coalesce(:NAME, A.NAME),
        A.OPTIONS = coalesce(:OPTIONS, A.OPTIONS),
        A.VIEWER  = coalesce(:VIEWER, A.VIEWER),
        A.TAG     = coalesce(:TAG, A.TAG),
        A.STATE   = BitSet(coalesce(:STATE,a.STATE),2,0),
        A.MODDT   = current_timestamp,
        A.MODUSER = :MODUSER
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SYSTREE A
    set A.STATE = BitSet(BITSET(A.STATE,0,1),2,0),
        A.MODDT = current_timestamp, 
        A.MODUSER = :MODUSER 
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    if (:ID_OWN is not null) then -- добавить, если надо, призрак
      if (not exists(select * from SYSTREE t where t.ID = :ID_OWN)) then
        insert into SYSTREE(ID,ID_OWN,NAME,OPTIONS,VIEWER,TAG,STATE,MODDT,MODUSER)
        values(:ID_OWN,null,:NAME,:OPTIONS,:VIEWER,:TAG,5,:MODDT,:MODUSER)
    ;
    update or insert into SYSTREE(ID,ID_OWN,NAME,OPTIONS,VIEWER,TAG,STATE,MODDT,MODUSER)
    values(:OUT_ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE,:MODDT,:MODUSER)
    matching(ID);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| :AOPERATION;
  if ( :AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(3000,:OUT_ID);
  suspend;
end;
grant all on SYSTREE to procedure SYSTREE$;
grant execute on procedure SYSTREE$ to IT;
grant execute on procedure BUFF$SEND to procedure SYSTREE$;
grant execute on function SYS_USERID to procedure SYSTREE$;
comment on parameter SYSTREE$.AOPERATION is
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация';
-----------------------------------------------

create or alter procedure SYSTREE$EDIT (
     AOPERATION DINT
    ,ID         DGUID_STR
    ,ID_OWN     DGUID_STR                      = null
    ,NAME       type of column SYSTREE.NAME    = null
    ,OPTIONS    type of column SYSTREE.OPTIONS = null
    ,VIEWER     type of column SYSTREE.VIEWER  = null
    ,TAG        type of column SYSTREE.TAG     = null
    ,STATE      type of column SYSTREE.STATE   = null
)returns(
    OUT_ID type of column SYSTREE.ID
)as
begin
  :ID = ASUUID(:ID);
  :ID_OWN = ASUUID(:ID_OWN);
  execute procedure SYSTREE$(:AOPERATION,
    :ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE
  ) returning_values :OUT_ID;
  suspend;
end;
grant execute on procedure SYSTREE$ to procedure SYSTREE$EDIT;
grant execute on procedure SYSTREE$EDIT to RWORKER,IT;
comment on procedure SYSTREE$EDIT is
'Процедура бизнес логики для таблицы SYSTREE';
comment on parameter SYSTREE$EDIT.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление';
-----------------------------------------------

create or alter procedure SYSTREE$EDITS(
     AOPERATION DINT
    ,iID        DGUID_STR
    ,iID_OWN    DGUID_STR                      = null
    ,iNAME      type of column SYSTREE.NAME    = null
    ,iOPTIONS   type of column SYSTREE.OPTIONS = null
    ,iVIEWER    type of column SYSTREE.VIEWER  = null
    ,iTAG       type of column SYSTREE.TAG     = null
    ,iSTATE     type of column SYSTREE.STATE   = null
)returns(
     ID        type of column SYSTREE.ID
    ,ID_OWN    type of column SYSTREE.ID_OWN
    ,NAME      type of column SYSTREE.NAME
    ,OPTIONS   type of column SYSTREE.OPTIONS
    ,VIEWER    type of column SYSTREE.VIEWER
    ,TAG       type of column SYSTREE.TAG
    ,STATE     type of column SYSTREE.STATE
)as
begin
  :iID = ASUUID(:iID);
  :iID_OWN = ASUUID(:iID_OWN);
  execute procedure SYSTREE$(:AOPERATION,
    :iID,:iID_OWN,:iNAME,coalesce(:iOPTIONS,0),:iVIEWER,:iTAG,coalesce(:iSTATE,0)
  ) returning_values :ID;
  select t.ID,t.ID_OWN,t.NAME,t.OPTIONS,t.VIEWER,t.TAG,t.STATE
  from SYSTREE$VWE t
  where t.ID = :ID
  into :ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE;
  if (row_count > 0) then
    suspend;
end;
grant execute on procedure SYSTREE$ to procedure SYSTREE$EDITS;
grant execute on procedure SYSTREE$EDITS to RWORKER,IT;
comment on parameter SYSTREE$EDITS.AOPERATION is
'0 - вставка, 1 - изменение, 2 - удаление';
-----------------------------------------------

create or alter procedure EX_SYSTREE (
    ID      type of column SYSTREE.ID,
    ID_OWN  type of column SYSTREE.ID_OWN,
    NAME    type of column SYSTREE.NAME,
    OPTIONS type of column SYSTREE.OPTIONS,
    VIEWER  type of column SYSTREE.VIEWER,
    TAG     type of column SYSTREE.TAG,
    STATE   type of column SYSTREE.STATE,
    MODDT   type of column SYSTREE.MODDT,
    MODUSER type of column SYSTREE.MODUSER
)as
declare variable OUT_ID type of column SYSTREE.ID;
begin
  execute procedure SYSTREE$(3,
    :ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE,:MODDT,:MODUSER
  ) returning_values :OUT_ID;
end;
grant execute on procedure SYSTREE$ to procedure EX_SYSTREE;
grant execute on procedure EX_SYSTREE to OBMEN;
grant execute on procedure EX_SYSTREE to IT;
comment on procedure EX_SYSTREE is
'Процедура обмена c магазином для таблицы SYSTREE';
-----------------------------------------------
-----------------------------------------------

create or alter procedure SUBJECTS$(
     AOPERATION DINT
    ,ID         type of column SUBJECTS.ID
    ,GRP        type of column SUBJECTS.GRP
    ,LOGIN      type of column SUBJECTS.LOGIN
    ,NAME       type of column SUBJECTS.NAME
    ,TABNUM     type of column SUBJECTS.TABNUM
    ,EXPDATE    type of column SUBJECTS.EXPDATE
    ,PHONE      type of column SUBJECTS.PHONE
    ,EMAIL      type of column SUBJECTS.EMAIL
    ,STATE      type of column SUBJECTS.STATE
    ,MODDT      type of column SUBJECTS.MODDT = null
    ,MODUSER    type of column SUBJECTS.MODUSER = null
)returns(
    OUT_ID type of column SUBJECTS.ID
)as
  declare variable HKEY DGUID;
  declare variable STAT type of column SUBJECTS.STATE;
begin
  -- автор версии 
  if (:AOPERATION <> 3) then
    :MODUSER = SYS_USERID();
  if (:AOPERATION = 0) then  -- insert or update?
  begin
    select t.ID,t.STATE
    from SUBJECTS t
    where t.LOGIN = :LOGIN
    into :OUT_ID,:STAT;
    if (row_count > 0) then
    begin
      :AOPERATION = 1;
      :STATE = coalesce(:STATE,BitSet(:STAT,0,0));
    end
  end

  if (AOPERATION = 0) then  -- insert
  begin
    :OUT_ID = coalesce(:ID, gen_uuid());
    insert into SUBJECTS(ID,GRP,LOGIN,NAME,TABNUM,EXPDATE,PHONE,EMAIL,STATE,MODDT,MODUSER)
    values (:OUT_ID,:GRP,:LOGIN,:NAME,:TABNUM,:EXPDATE,:PHONE,:EMAIL,
            BITSET(coalesce(:STATE,0),2,0),current_timestamp,:MODUSER
    );
  end
  else
  if (AOPERATION = 1) then  -- update
  begin
    :OUT_ID = :ID;
    update SUBJECTS A
    set A.GRP = coalesce(:GRP,A.GRP)
       ,A.LOGIN = coalesce(:LOGIN,A.LOGIN)
       ,A.NAME = coalesce(:NAME,A.NAME)
       ,A.TABNUM = coalesce(:TABNUM,A.TABNUM)
       ,A.EXPDATE = coalesce(:EXPDATE,A.EXPDATE)
       ,A.PHONE = coalesce(:PHONE,A.PHONE)
       ,A.EMAIL = coalesce(:EMAIL,A.EMAIL)
       ,A.STATE = BITSET(coalesce(:STATE,A.STATE),2,0)
       ,A.MODDT = current_timestamp
       ,A.MODUSER = :MODUSER
    where A.ID = :ID;
  end
  else
  if (:AOPERATION = 2) then  -- delete
  begin
    :OUT_ID = :ID;
    update SUBJECTS A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0),
        A.MODDT = current_timestamp, 
        A.MODUSER = :MODUSER 
    where A.ID = :ID;
  end
  else
  if (AOPERATION = 3) then  -- exchange
  begin
    :OUT_ID = :ID;
    update or insert into SUBJECTS(ID,GRP,LOGIN,NAME,TABNUM,EXPDATE,PHONE,EMAIL,
                                   STATE,MODDT,MODUSER)
    values(:OUT_ID,:GRP,:LOGIN,:NAME,:TABNUM,:EXPDATE,:PHONE,:EMAIL,:STATE,:MODDT,:MODUSER)
    matching(ID);
  end
  if ( :AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(1000,:OUT_ID);
  suspend;
end;
grant execute on function BITSET to procedure SUBJECTS$;
grant execute on procedure BUFF$SEND to procedure SUBJECTS$;
grant all on SUBJECTS to procedure SUBJECTS$;
grant execute on procedure SUBJECTS$ to IT;
-----------------------------------------------

create or alter procedure EX_SUBJECTS(
   ID      type of column SUBJECTS.ID
  ,GRP     type of column SUBJECTS.GRP
  ,LOGIN   type of column SUBJECTS.LOGIN
  ,NAME    type of column SUBJECTS.NAME
  ,TABNUM  type of column SUBJECTS.TABNUM
  ,EXPDATE type of column SUBJECTS.EXPDATE
  ,PHONE   type of column SUBJECTS.PHONE
  ,EMAIL   type of column SUBJECTS.EMAIL
  ,STATE   type of column SUBJECTS.STATE
  ,MODDT   type of column SUBJECTS.MODDT
  ,MODUSER type of column SUBJECTS.MODUSER
)as
  declare variable OUT_ID type of column SUBJECTS.ID;
begin
  execute procedure SUBJECTS$(3,
    :ID,:GRP,:LOGIN,:NAME,:TABNUM,:EXPDATE,:PHONE,:EMAIL,:STATE,:MODDT,:MODUSER
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure SUBJECTS$ to procedure EX_SUBJECTS;
grant execute on procedure EX_SUBJECTS to IT,OBMEN;
-----------------------------------------------

create or alter procedure SUBJECTS$EDIT(
     AOPERATION DINT
    ,ID         DGUID_STR
    ,GRP        type of column SUBJECTS.GRP     = null
    ,LOGIN      type of column SUBJECTS.LOGIN   = null
    ,NAME       type of column SUBJECTS.NAME    = null
    ,TABNUM     type of column SUBJECTS.TABNUM  = null
    ,EXPDATE    type of column SUBJECTS.EXPDATE = null
    ,PHONE      type of column SUBJECTS.PHONE   = null
    ,EMAIL      type of column SUBJECTS.EMAIL   = null
    ,STATE      type of column SUBJECTS.STATE   = null
)returns(
  OUT_ID type of column SUBJECTS.ID
)as
begin
  :ID = ASUUID(:ID);
  execute procedure SUBJECTS$(:AOPERATION,
    :ID,:GRP,:LOGIN,:NAME,:TABNUM,:EXPDATE,:PHONE,:EMAIL,:STATE
  )returning_values :OUT_ID;
  suspend;
end;
----------
comment on parameter SUBJECTS$EDIT.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление';
grant execute on procedure SUBJECTS$ to procedure SUBJECTS$EDIT;
grant execute on procedure SUBJECTS$EDIT to IT,RWORKER;
-----------------------------------------------
-----------------------------------------------

create or alter procedure SYSVIEWERS$(
    AOPERATION DINT,
    ID      type of column SYSVIEWERS.ID,
    KIND    type of column SYSVIEWERS.KIND,
    NAME    type of column SYSVIEWERS.NAME,
    OPERS   type of column SYSVIEWERS.OPERS,
    DESCR   type of column SYSVIEWERS.DESCR,
    STATE   type of column SYSVIEWERS.STATE,
    MODDT   type of column SYSVIEWERS.MODDT = null,
    MODUSER type of column SYSVIEWERS.MODUSER = null
)returns(
  OUT_ID type of column SYSVIEWERS.ID
)as
begin
  OUT_ID = :ID;
  -- автор версии 
  if (:AOPERATION <> 3) then 
    MODUSER = SYS_USERID(); 
  if (:AOPERATION = 0) then -- вставка
  begin
    insert into SYSVIEWERS(ID,KIND,NAME,OPERS,DESCR,STATE,MODDT,MODUSER)
    values (:OUT_ID,:KIND,:NAME,:OPERS,:DESCR,BITSET(coalesce(:STATE,0),2,0),current_timestamp,:MODUSER);
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SYSVIEWERS A
    set A.KIND = coalesce(:KIND,A.KIND),
        A.NAME = coalesce(:NAME,A.NAME),
        A.OPERS = coalesce(:OPERS,A.OPERS),
        A.DESCR = coalesce(:DESCR,A.DESCR),
        A.STATE = BITSET(coalesce(:STATE,A.STATE),2,0),
        A.MODDT = current_timestamp,
        A.MODUSER = :MODUSER
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SYSVIEWERS A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0),
        A.MODDT = current_timestamp, 
        A.MODUSER = :MODUSER 
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into SYSVIEWERS(ID,KIND,NAME,OPERS,DESCR,STATE,MODDT,MODUSER)
    values(:OUT_ID,:KIND,:NAME,:OPERS,:DESCR,:STATE,:MODDT,:MODUSER)
    matching(ID);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| :AOPERATION;
  if ( AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(2000,null,:OUT_ID);
  suspend;
end;
----------
comment on parameter SYSVIEWERS$.AOPERATION is
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация';
grant all on SYSVIEWERS to procedure SYSVIEWERS$;
grant execute on procedure BUFF$SEND to procedure SYSVIEWERS$;
grant execute on procedure SYSVIEWERS$ to IT;
grant execute on function SYS_USERID to procedure SYSVIEWERS$;
---------------------------------

create or alter procedure EX_SYSVIEWERS(
  ID type of column SYSVIEWERS.ID,
  KIND type of column SYSVIEWERS.KIND,
  NAME type of column SYSVIEWERS.NAME,
  OPERS type of column SYSVIEWERS.OPERS,
  DESCR type of column SYSVIEWERS.DESCR,
  STATE type of column SYSVIEWERS.STATE,
  MODDT type of column SYSVIEWERS.MODDT,
  MODUSER type of column SYSVIEWERS.MODUSER
)as
  declare variable OUT_ID type of column SYSVIEWERS.ID;
begin
  execute procedure SYSVIEWERS$(3,
    :ID,:KIND,:NAME,:OPERS,:DESCR,:STATE,:MODDT,:MODUSER
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure SYSVIEWERS$ to procedure EX_SYSVIEWERS;
grant execute on procedure EX_SYSVIEWERS to IT,OBMEN;
comment on procedure EX_SYSVIEWERS is 
'Процедура обмена c магазином для таблицы SYSVIEWERS';
---------------------------------

create or alter procedure SYSVIEWERS$EDIT(
     AOPERATION DINT
    ,ID    type of column SYSVIEWERS.ID
    ,KIND  type of column SYSVIEWERS.KIND  = null
    ,NAME  type of column SYSVIEWERS.NAME  = null
    ,OPERS type of column SYSVIEWERS.OPERS = null
    ,DESCR type of column SYSVIEWERS.DESCR = null
    ,STATE type of column SYSVIEWERS.STATE = null
)returns(
  OUT_ID type of column SYSVIEWERS.ID
)as
begin
  execute procedure SYSVIEWERS$(:AOPERATION,
    :ID,:KIND,:NAME,:OPERS,:DESCR,:STATE
  )returning_values :OUT_ID;
  suspend;
end;
----------
comment on parameter SYSVIEWERS$EDIT.AOPERATION is
'0 - вставка, 1 - изменение, 2 - удаление';
grant execute on procedure SYSVIEWERS$ to procedure SYSVIEWERS$EDIT;
grant execute on procedure SYSVIEWERS$EDIT to IT,RWORKER;
---------------------------------
---------------------------------

create or alter procedure SYS_PRIV$(
     AOPERATION DINT
    ,ID      type of column SYS_PRIV.ID
    ,UID     type of column SYS_PRIV.UID
    ,OBJ     type of column SYS_PRIV.OBJ
    ,ROOT    type of column SYS_PRIV.ROOT
--    ,DOCVWR  type of column SYS_PRIV.DOCVWR
    ,OPERS   type of column SYS_PRIV.OPERS
    ,STATE   type of column SYS_PRIV.STATE
    ,MODDT   type of column SYS_PRIV.MODDT   = null
    ,MODUSER type of column SYS_PRIV.MODUSER = null
)returns(
  OUT_ID type of column SYS_PRIV.ID
)as
  declare variable STAT type of column SYS_PRIV.STATE;
begin
  OUT_ID = :ID;
  -- автор версии 
  if (:AOPERATION <> 3) then 
    MODUSER = SYS_USERID(); 

  if (:AOPERATION = 0) then  -- insert or update?
  begin
    select t.ID,t.STATE
    from SYS_PRIV t
    where t.UID = :UID and t.OBJ = :OBJ and t.ROOT = :ROOT
    into :OUT_ID,:STAT;
    if (row_count > 0) then
    begin
      :AOPERATION = 1;
      :STATE = coalesce(:STATE,BitSet(:STAT,0,0));
    end
  end

  if (:AOPERATION = 33) then
  begin
    if (coalesce(:OPERS, 0) = 0) then  -- delete
    begin
      update SYS_PRIV A
      set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0),
          A.MODDT = current_timestamp,
          A.MODUSER = :MODUSER
      where A.UID = :UID and A.OBJ = :OBJ and A.ROOT = :ROOT
      returning ID into :OUT_ID;
      if (row_count = 0) then
        :AOPERATION = -1;  -- no insert to BUFF
    end
    else begin
      select t.ID,t.STATE
      from SYS_PRIV t
      where t.UID = :UID and t.OBJ = :OBJ and t.ROOT = :ROOT
      into :OUT_ID,:STAT;
      :OUT_ID = coalesce(:OUT_ID, gen_uuid());
      :STAT = coalesce(:STAT,:STATE,0);
      update or insert into SYS_PRIV(ID,UID,OBJ,ROOT,OPERS,STATE,MODDT,MODUSER)
      values(:OUT_ID,:UID,:OBJ,:ROOT,:OPERS,:STAT,current_timestamp,:MODUSER)
      matching(UID,OBJ,ROOT);
    end
  end
  else
  if (:AOPERATION = 0) then -- вставка
  begin
    :OUT_ID = coalesce(:ID, gen_uuid());
    insert into SYS_PRIV(ID,UID,OBJ,ROOT,OPERS,STATE,MODDT,MODUSER)
    values (:OUT_ID,:UID,:OBJ,:ROOT,:OPERS,
            BITSET(coalesce(:STATE,0),2,0),current_timestamp,:MODUSER
    );
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SYS_PRIV A
    set A.UID = coalesce(:UID,A.UID),
        A.OBJ = coalesce(:OBJ,A.OBJ),
        A.ROOT = coalesce(:ROOT,A.ROOT),
        A.OPERS = coalesce(:OPERS,A.OPERS),
        A.STATE = BITSET(coalesce(:STATE,A.STATE),2,0),
        A.MODDT = current_timestamp,
        A.MODUSER = :MODUSER
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SYS_PRIV A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0),
        A.MODDT = current_timestamp, 
        A.MODUSER = :MODUSER 
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into SYS_PRIV(ID,UID,OBJ,ROOT,OPERS,STATE,MODDT,MODUSER)
    values(:OUT_ID,:UID,:OBJ,:ROOT,:OPERS,:STATE,:MODDT,:MODUSER)
    matching(ID);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| :AOPERATION;
  if ( AOPERATION in (0,1,2,33) ) then
    execute procedure BUFF$SEND(4500,:OUT_ID);
  suspend;
end;
----------
comment on parameter SYS_PRIV$.AOPERATION is 
' 0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация;
 33 - работа по [UID,OBJ,ROOT]: удалить, если OPERS = 0, иначе update or insert';
grant all on SYS_PRIV to procedure SYS_PRIV$;
grant execute on procedure BUFF$SEND to procedure SYS_PRIV$;
grant execute on function SYS_USERID to procedure SYS_PRIV$;
grant execute on procedure SYS_PRIV$ to IT;
---------------------------------

create or alter procedure SYS_PRIV$EDIT(
     AOPERATION DINT
    ,ID      DGUID_STR
    ,UID     DGUID_STR     = null
    ,OBJ     DGUID_STR     = null
    ,ROOT    DGUID_STR     = null
    ,OPERS   type of column SYS_PRIV.OPERS   = null
    ,STATE   type of column SYS_PRIV.STATE   = null
    ,MODDT   type of column SYS_PRIV.MODDT   = null
    ,MODUSER type of column SYS_PRIV.MODUSER = null
)returns(
  OUT_ID type of column SYS_PRIV.ID
)as
begin
  :ID   = AsUUID(:ID);
  :UID  = AsUUID(:UID);
  :OBJ  = AsUUID(:OBJ);
  :ROOT = AsUUID(:ROOT);
  execute procedure SYS_PRIV$(:AOPERATION,:ID,:UID,:OBJ,:ROOT,:OPERS,:STATE,:MODDT,:MODUSER)
  returning_values :OUT_ID;
  suspend;
end;
grant execute on procedure SYS_PRIV$ to procedure SYS_PRIV$EDIT;
grant execute on procedure SYS_PRIV$EDIT to IT,RWORKER;
---------------------------------

create or alter procedure EX_SYS_PRIV(
   ID      type of column SYS_PRIV.ID
  ,UID     type of column SYS_PRIV.UID
  ,OBJ     type of column SYS_PRIV.OBJ
  ,ROOT    type of column SYS_PRIV.ROOT
  ,OPERS   type of column SYS_PRIV.OPERS
  ,STATE   type of column SYS_PRIV.STATE
  ,MODDT   type of column SYS_PRIV.MODDT
  ,MODUSER type of column SYS_PRIV.MODUSER
)as
  declare variable OUT_ID type of column SYS_PRIV.ID;
begin
  execute procedure SYS_PRIV$(3,
    :ID,:UID,:OBJ,:ROOT,:OPERS,:STATE,:MODDT,:MODUSER
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure SYS_PRIV$ to procedure EX_SYS_PRIV;
grant execute on procedure EX_SYS_PRIV to IT,OBMEN;
comment on procedure EX_SYS_PRIV is 
'Процедура обмена c магазином для таблицы SYS_PRIV';
---------------------------------
---------------------------------

create or alter procedure VWRTAG$(
    AOPERATION DINT,
    ID         type of column VWRTAG.ID,
    TAG        type of column VWRTAG.TAG,
    VIEWER     type of column VWRTAG.VIEWER,
    NAME       type of column VWRTAG.NAME,
    SVALUE     type of column VWRTAG.SVALUE,
    STATE      type of column VWRTAG.STATE,
    MODDT      type of column VWRTAG.MODDT = null,
    MODUSER    type of column VWRTAG.MODUSER = null
)returns(
  OUT_ID type of column VWRTAG.ID
)as
  declare variable STAT type of column VWRTAG.STATE;
begin
  OUT_ID = :ID;
  -- автор версии 
  if (:AOPERATION <> 3) then 
    MODUSER = SYS_USERID(); 
  if (:AOPERATION = 0) then  -- insert or update?
  begin
    select t.ID,t.STATE
    from VWRTAG t
    where t.TAG = :TAG and t.VIEWER = :VIEWER
    into :OUT_ID,:STAT;
    if (row_count > 0) then
    begin
      :AOPERATION = 1;
      :STATE = coalesce(:STATE,BitSet(:STAT,0,0));
    end
  end

  if (:AOPERATION = 0) then -- вставка
  begin
    :OUT_ID = coalesce(:ID, gen_uuid());
    insert into VWRTAG(ID,TAG,VIEWER,NAME,SVALUE,STATE,MODDT,MODUSER)
    values (:OUT_ID,:VIEWER,:TAG,:NAME,:SVALUE,BITSET(coalesce(:STATE,0),2,0),current_timestamp,:MODUSER);
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update VWRTAG A
    set A.VIEWER  = coalesce(:VIEWER,A.VIEWER),
        A.TAG     = coalesce(:TAG,A.TAG),
        A.NAME    = coalesce(:NAME,A.NAME),
        A.SVALUE  = coalesce(:SVALUE,A.SVALUE),
        A.STATE   = BITSET(coalesce(:STATE,A.STATE),2,0),
        A.MODDT   = current_timestamp,
        A.MODUSER = :MODUSER
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update VWRTAG A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0),
        A.MODDT = current_timestamp, 
        A.MODUSER = :MODUSER 
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into VWRTAG(ID,TAG,VIEWER,NAME,SVALUE,STATE,MODDT,MODUSER)
    values(:OUT_ID,:TAG,:VIEWER,:NAME,:SVALUE,:STATE,:MODDT,:MODUSER)
    matching(ID);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| :AOPERATION;
  if ( AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(2100,null,:OUT_ID);
  suspend;
end;
----------
comment on parameter VWRTAG$.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация';
grant all on VWRTAG to procedure VWRTAG$;
grant execute on procedure BUFF$SEND to procedure VWRTAG$;
grant execute on procedure VWRTAG$ to IT;
grant execute on function SYS_USERID to procedure VWRTAG$;
---------------------------------

create or alter procedure EX_VWRTAG(
  ID type of column VWRTAG.ID,
  TAG type of column VWRTAG.TAG,
  VIEWER type of column VWRTAG.VIEWER,
  NAME type of column VWRTAG.NAME,
  SVALUE type of column VWRTAG.SVALUE,
  STATE type of column VWRTAG.STATE,
  MODDT type of column VWRTAG.MODDT,
  MODUSER type of column VWRTAG.MODUSER
)as
  declare variable OUT_ID type of column VWRTAG.ID;
begin
  execute procedure VWRTAG$(3,
    :ID,:TAG,:VIEWER,:NAME,:SVALUE,:STATE,:MODDT,:MODUSER
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure VWRTAG$ to procedure EX_VWRTAG;
grant execute on procedure EX_VWRTAG to IT,OBMEN;
comment on procedure EX_VWRTAG is 
'Процедура обмена c магазином для таблицы VWRTAG';
---------------------------------
---------------------------------

create or alter procedure SUBJLINK$(
     AOPERATION DINT
    ,ID         type of column SUBJLINK.ID
    ,UID        type of column SUBJLINK.UID
    ,GID        type of column SUBJLINK.GID
    ,EXPDATE    type of column SUBJLINK.EXPDATE
    ,STATE      type of column SUBJLINK.STATE
    ,MODDT      type of column SUBJLINK.MODDT = null
    ,MODUSER    type of column SUBJLINK.MODUSER = null
)returns(
  OUT_ID type of column SUBJLINK.ID
)as
  declare variable STAT type of column SUBJLINK.STATE;
begin
  OUT_ID = :ID;
  -- автор версии 
  if (:AOPERATION <> 3) then 
    MODUSER = SYS_USERID(); 
  if (:AOPERATION = 0) then  -- insert or update?
  begin
    select t.ID,t.STATE
    from SUBJLINK t
    where t.UID = :UID and t.GID = :GID
    into :OUT_ID,:STAT;
    if (row_count > 0) then
    begin
      :AOPERATION = 1;
      :STATE = coalesce(:STATE,BitSet(:STAT,0,0));
    end
  end
  if (:AOPERATION = 0) then -- вставка
  begin
    :OUT_ID = coalesce(:ID, gen_uuid());
    insert into SUBJLINK(ID,UID,GID,EXPDATE,STATE,MODDT,MODUSER)
    values (:OUT_ID,:UID,:GID,:EXPDATE,BITSET(coalesce(:STATE,0),2,0),current_timestamp,:MODUSER);
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SUBJLINK A
    set A.UID = coalesce(:UID,A.UID),
        A.GID = coalesce(:GID,A.GID),
        A.EXPDATE = coalesce(:EXPDATE,A.EXPDATE),
        A.STATE = BITSET(coalesce(:STATE,A.STATE),2,0),
        A.MODDT = current_timestamp,
        A.MODUSER = :MODUSER
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SUBJLINK A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0),
        A.MODDT = current_timestamp, 
        A.MODUSER = :MODUSER 
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into SUBJLINK(ID,UID,GID,EXPDATE,STATE,MODDT,MODUSER)
    values(:OUT_ID,:UID,:GID,:EXPDATE,:STATE,:MODDT,:MODUSER)
    matching(ID);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| :AOPERATION;
  if ( AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(1500,:OUT_ID);
  suspend;
end;
----------
comment on parameter SUBJLINK$.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация';
grant all on SUBJLINK to procedure SUBJLINK$;
grant execute on procedure BUFF$SEND to procedure SUBJLINK$;
grant execute on procedure SUBJLINK$ to IT;
grant execute on function SYS_USERID to procedure SUBJLINK$;
---------------------------------

create or alter procedure EX_SUBJLINK(
     ID         type of column SUBJLINK.ID
    ,UID        type of column SUBJLINK.UID
    ,GID        type of column SUBJLINK.GID
    ,EXPDATE    type of column SUBJLINK.EXPDATE
    ,STATE      type of column SUBJLINK.STATE
    ,MODDT      type of column SUBJLINK.MODDT
    ,MODUSER    type of column SUBJLINK.MODUSER
)as
  declare variable OUT_ID type of column SUBJLINK.ID;
begin
  execute procedure SUBJLINK$(3,
    :ID,:UID,:GID,:EXPDATE,:STATE,:MODDT,:MODUSER
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure SUBJLINK$ to procedure EX_SUBJLINK;
grant execute on procedure EX_SUBJLINK to IT,OBMEN;
comment on procedure EX_SUBJLINK is 
'Процедура обмена c магазином для таблицы SUBJLINK';
---------------------------------

create or alter procedure SUBJLINK$EDIT(
    AOPERATION DINT
    ,ID        DGUID_STR
    ,UID       DGUID_STR                       = null
    ,GID       DGUID_STR                       = null
    ,EXPDATE   type of column SUBJLINK.EXPDATE = null
    ,STATE     type of column SUBJLINK.STATE   = null
    ,MODDT     type of column SUBJLINK.MODDT   = null
    ,MODUSER   type of column SUBJLINK.MODUSER = null
)returns(
  OUT_ID type of column SUBJLINK.ID
)as
begin
  :ID  = ASUUID(:ID);
  :UID = ASUUID(:UID);
  :GID = ASUUID(:GID);
  execute procedure SUBJLINK$(:AOPERATION,
    :ID,:UID,:GID,:EXPDATE,:STATE
  )returning_values :OUT_ID;
  suspend;
end;
----------
comment on parameter SUBJLINK$EDIT.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление';
grant execute on procedure SUBJLINK$ to procedure SUBJLINK$EDIT;
grant execute on procedure SUBJLINK$EDIT to IT,RWORKER;
---------------------------------

create or alter procedure SUBJLINK$EDITS(
     iLINKED   DBOOL
    ,iUID      DGUID_STR
    ,iGID      DGUID_STR
    ,iEXPDATE  type of column SUBJLINK.EXPDATE = null
)returns(
     ID       type of column SUBJLINK.ID
    ,GRP      type of column SUBJECTS.GRP
    ,LINKED   DBOOL
    ,EXPDATE  type of column SUBJLINK.EXPDATE
)as
  declare variable AOPERATION DINT;
  declare variable STATE type of column SUBJLINK.STATE;
begin
  :iLINKED = coalesce(:iLINKED, false);
  :iUID = ASUUID(:iUID);
  :iGID = ASUUID(:iGID);

  select t.ID,t.STATE,t.EXPDATE
  from SUBJLINK t
  where t.UID = :iUID and t.GID = :iGID
  into :ID,:STATE,:EXPDATE;
  :AOPERATION = 0;
  if (row_count = 0) then
  begin
    if (:iLINKED) then
      :ID = gen_uuid();
    else
      :AOPERATION = -1;
  end
  else
  begin
    :AOPERATION = 1;
    if (not :iLINKED) then
      :AOPERATION = 2;
    :STATE = coalesce(BitSet(:STATE,0,0),0);
    :iEXPDATE = coalesce(:EXPDATE, :iEXPDATE);
  end

  if (:AOPERATION >= 0) then
    execute procedure SUBJLINK$(:AOPERATION,
      :ID,:iUID,:iGID,:iEXPDATE,:STATE
    )returning_values :ID
  ;

  select t.UID,t.GID,t.EXPDATE,t.STATE
  from SUBJLINK$VWE t
  where t.UID = :iUID and t.GID = :iGID
  into :UID,:GID,:EXPDATE,:STATE;
  :LINKED = row_count > 0;
  if (not :LINKED) then
  begin
    :UID = :iUID;
    :GID = :iGID;
    :EXPDATE = :iEXPDATE;
    :STATE = :iSTATE;
  end
  suspend;
end;
----------
grant execute on function  ASUUID    to procedure SUBJLINK$EDITS;
grant execute on function  BITSET    to procedure SUBJLINK$EDITS;
grant execute on procedure SUBJLINK$ to procedure SUBJLINK$EDITS;
grant select  on SUBJLINK     to procedure SUBJLINK$EDITS;
grant select  on SUBJLINK$VWE to procedure SUBJLINK$EDITS;
grant execute on procedure SUBJLINK$EDITS to IT,RWORKER;
comment on procedure SUBJLINK$EDITS is
'Редактирование связей из приложения';
---------------------------------
---------------------------------

create or alter procedure SYS_OPERS$(
     AOPERATION DINT
    ,ID         type of column SYS_OPERS.ID
    ,NAME       type of column SYS_OPERS.NAME
    ,CAPTION    type of column SYS_OPERS.CAPTION
    ,STATE      type of column SYS_OPERS.STATE
)returns(
  OUT_ID type of column SYS_OPERS.ID
)as
  declare variable STAT type of column SUBJECTS.STATE;
begin
  OUT_ID = :ID;
  if (:AOPERATION = 0) then  -- insert or update?
  begin
    select t.ID,t.STATE
    from SYS_OPERS t
    where t.NAME = :NAME
    into :OUT_ID,:STAT;
    if (row_count > 0) then
    begin
      :AOPERATION = 1;
      :STATE = coalesce(:STATE,BitSet(:STAT,0,0));
    end
  end
  if (:AOPERATION = 0) then -- вставка
  begin
    insert into SYS_OPERS(ID,NAME,CAPTION,STATE)
    values (:OUT_ID,:NAME,:CAPTION,BITSET(coalesce(:STATE,0),2,0));
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SYS_OPERS A
    set A.NAME = coalesce(:NAME,A.NAME),
        A.CAPTION = coalesce(:CAPTION,A.CAPTION),
        A.STATE = BITSET(coalesce(:STATE,A.STATE),2,0)
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SYS_OPERS A
    set A.STATE = BITSET(BITSET(A.STATE,0,1),2,0)
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into SYS_OPERS(ID,NAME,CAPTION,STATE)
    values(:OUT_ID,:NAME,:CAPTION,:STATE)
    matching(ID);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| :AOPERATION;
  if ( AOPERATION in (0,1,2) ) then
    execute procedure BUFF$SEND(00,:OUT_ID);
  suspend;
end;
----------
comment on parameter SYS_OPERS$.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация';
grant all on SYS_OPERS to procedure SYS_OPERS$;
grant execute on procedure BUFF$SEND to procedure SYS_OPERS$;
grant execute on procedure SYS_OPERS$ to IT;
---------------------------------

create or alter procedure EX_SYS_OPERS(
   ID      type of column SYS_OPERS.ID
  ,NAME    type of column SYS_OPERS.NAME
  ,CAPTION type of column SYS_OPERS.CAPTION
  ,STATE   type of column SYS_OPERS.STATE
)as
  declare variable OUT_ID type of column SYS_OPERS.ID;
begin
  execute procedure SYS_OPERS$(3,
    :ID,:NAME,:CAPTION,:STATE
  )returning_values :OUT_ID;
end;
----------
grant execute on procedure SYS_OPERS$ to procedure EX_SYS_OPERS;
grant execute on procedure EX_SYS_OPERS to IT,OBMEN;
comment on procedure EX_SYS_OPERS is 
'Процедура обмена c магазином для таблицы SYS_OPERS';
---------------------------------

create or alter procedure SYS_OPERS$EDIT(
   AOPERATION DINT
  ,ID         type of column SYS_OPERS.ID
  ,NAME       type of column SYS_OPERS.NAME
  ,CAPTION    type of column SYS_OPERS.CAPTION
  ,STATE      type of column SYS_OPERS.STATE
)returns(
  OUT_ID type of column SYS_OPERS.ID
)as
begin
  execute procedure SYS_OPERS$(:AOPERATION,
    :ID,:NAME,:CAPTION,:STATE
  )returning_values :OUT_ID;
  suspend;
end;
----------
comment on parameter SYS_OPERS$EDIT.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление';
grant execute on procedure SYS_OPERS$ to procedure SYS_OPERS$EDIT;
grant execute on procedure SYS_OPERS$EDIT to IT,RWORKER;
---------------------------------
---------------------------------

create or alter procedure GetRights(
   OBJ  DGUID
  ,ROOT DGUID = null
)returns(
   OPERS  type of column SYS_PRIV.OPERS
  ,TAG    type of column SYSTREE.TAG
  ,VIEWER type of column SYSTREE.VIEWER
)as
begin
  if (1 = IS_ADMIN()) then
  begin
    :OPERS = -1;
    select t.TAG,t.VIEWER
    from SYSTREE$VWE t
    where t.ID = :OBJ
    into :TAG,:VIEWER;
  end
  else
  begin
    select p.OPERS,t.TAG,t.VIEWER
    from GTT_PRIVS p
    join SYSTREE$VWE t on t.ID = p.OBJ
    where p.OBJ = :OBJ and p.ROOT = :ROOT
    into :OPERS,:TAG,:VIEWER;
  end
  if (row_count = 0) then
    :OPERS = 0;
  suspend;
end;
grant select on SYSTREE$VWE to procedure GETRIGHTS;
grant execute on procedure GETRIGHTS to public;
comment on procedure GetRights is
'Получить привилегии session_user на узел obj-root
 и значения TAG и VIEWER этого узла.
Если узел obj не существует, return @zero, VIEWER и TAG не изменяются.
';
-----------------------------------------------

create or alter procedure SYS_USER_PRIVS(
  UID DGUID_STR = null
)returns(
   OBJ    type of column SYSTREE.ID
  ,ROOT   type of column SYS_PRIV.ROOT
  ,OPERS  type of column SYS_PRIV.OPERS
)as
  --kind(0|1|2|3) :: opers юзера|opers ролей|opers доверителей|opers ролей доверителей
  declare variable kind DINT;
  declare variable tmp DGUID;
  declare variable MSOPERS type of column SYS_PRIV.OPERS; -- собственные opers юзера
  declare variable MROPERS type of column SYS_PRIV.OPERS; -- opers ролей юзера
  declare variable DSOPERS type of column SYS_PRIV.OPERS; -- собственные opers доверителей
  declare variable DROPERS type of column SYS_PRIV.OPERS; -- opers ролей доверителей
  declare variable COBJ    type of column SYSTREE.ID;
  declare variable CROOT   type of column SYSTREE.ID;
  declare variable COPERS  type of column SYS_PRIV.OPERS;
begin
  :tmp = SYS_USERID();
  :UID = coalesce(AsUUID(:UID), :tmp);
  if (0 = IS_ADMIN()) then
    :UID = :tmp;       -- только админам можно брать чужое
  ---- схлопываем привилегии
  for
    select tt.kind,tt.OBJ,tt.ROOT,tt.OPERS
    from(
      with a as(           --- все роли всех доверителей
          select t.GID ID                --- роли доверителей
          from SUBJLINK$VWA t
          join SUBJLINK$VWA c on t.UID = c.GID
          where t.GRP > 0 and c.GRP = 0 and c.URP = 0
            and c.UID = :UID
          union
          select r.UID ID
          from SUBJLINK$VWA t
          join SUBJLINK$VWA c on t.UID = c.GID  -- должности доверителей
          join SUBJLINK$VWA r on r.GID = t.GID  -- роли должностей доверителей
          where t.GRP < 0 and c.GRP = 0 and c.URP = 0 and r.URP > 0
            and c.UID = :UID
      )
      select 3 kind,z.OBJ,z.ROOT,z.OPERS -- привилегии всех ролей всех доверителей
      from SYS_PRIV$VWE z
      join a on z.UID = a.ID
      union all
      select 2 kind,p.OBJ,p.ROOT,p.OPERS -- привилегии всех доверителей
      from SYS_PRIV$VWE p
      where exists(
        select t.GID                --- доверители
        from SUBJLINK$VWA t
        where t.GRP = 0 and t.URP = 0
          and t.UID = :UID
          and p.UID = t.GID
      )
      union all
      select 1 kind,u.OBJ,u.ROOT,u.OPERS -- привилегии ролей пользователя
      from SYS_PRIV$VWE u
      where exists(
        select t.GID --- все роли пользователя
        from SUBJLINK$VWA t
        where t.GID = u.UID and
         ( (t.UID = :UID
            and t.GRP > 0)
           or (
             t.URP > 0 and t.GRP < 0 --- связь роль-должность
             and exists(
               select *                  --- должности пользователя
               from SUBJLINK$VWA j
               where j.UID = :UID
                 and j.GRP < 0 and j.GID = t.UID
             )
         ))
      )
      union all
      select 0 kind,m.OBJ,m.ROOT,m.OPERS -- собственные привилегии :UID
      from SYS_PRIV$VWE m
      where m.UID = :UID
    ) tt
    order by tt.OBJ,tt.ROOT
    into :kind,:COBJ,:CROOT,:COPERS
  do begin
    if (:COBJ is distinct from :OBJ or :CROOT is distinct from :ROOT) then
    begin
      -- сумма привилегий
      if (:OBJ is not null) then
      begin
        :OPERS = bin_or(coalesce(:MSOPERS,:MROPERS,0),coalesce(:DSOPERS,:DROPERS,0));
        suspend;
      end
     :MSOPERS = iif(:kind = 0,:COPERS,0);
     :MROPERS = iif(:kind = 1,:COPERS,0);
     :DSOPERS = iif(:kind = 2,:COPERS,0);
     :DROPERS = iif(:kind = 3,:COPERS,0);
    end
    :OBJ  = :COBJ;
    :ROOT = :CROOT;
    :MSOPERS = bin_or(:MSOPERS,iif(:kind = 0,:COPERS,0));
    :MROPERS = bin_or(:MROPERS,iif(:kind = 1,:COPERS,0));
    :DSOPERS = bin_or(:DSOPERS,iif(:kind = 2,:COPERS,0));
    :DROPERS = bin_or(:DSOPERS,iif(:kind = 3,:COPERS,0));
  end
  if (:OBJ is not null) then
  begin
    :OPERS = bin_or(coalesce(:MSOPERS,:MROPERS,0),coalesce(:DSOPERS,:DROPERS,0));
    suspend;
  end
end;
comment on procedure SYS_USER_PRIVS is 'Сумма привилегий пользователя на объекты доступа';
grant execute on function SYS_USERID to procedure SYS_USER_PRIVS;
grant execute on function ASUUID to procedure SYS_USER_PRIVS;
grant execute on function IS_ADMIN to procedure SYS_USER_PRIVS;
grant execute on function BITGET to procedure SYS_USER_PRIVS;
grant select on SUBJLINK$VWA to procedure SYS_USER_PRIVS;
grant select on SYS_PRIV$VWE to procedure SYS_USER_PRIVS;
grant execute on procedure SYS_USER_PRIVS to IT,RWORKER;
-------------------------------------------------------------

create or alter procedure SYS_CACHE_PRIVS
as
begin
  delete from GTT_PRIVS;
  insert into GTT_PRIVS(OBJ,ROOT,OPERS)
  select * from SYS_USER_PRIVS;
end;
grant all on GTT_PRIVS to procedure SYS_CACHE_PRIVS;
grant execute on procedure SYS_USER_PRIVS to procedure SYS_CACHE_PRIVS;
comment on procedure SYS_CACHE_PRIVS is
'Заполнить вр. таблицу GTT_PRIVS суммой привилегий пользователя';
---------------------------------------------------------

create or alter procedure SYS_INIT_CONNECT
as
begin
  execute procedure SYS_CACHE_PRIVS;
end;
grant execute on procedure SYS_CACHE_PRIVS to procedure SYS_INIT_CONNECT;
grant execute on procedure SYS_INIT_CONNECT to IT,RWORKER;
comment on procedure SYS_INIT_CONNECT is
'Всё, что нужно ввыполнить сразу при авторизации п-ля, надо собирать сюда.';
---------------------------------------------------------

create or alter procedure SYS_USER_TREE(
  UID  DGUID_STR = null
)returns(
   ID      type of column SYSTREE.ID
  ,ID_OWN  type of column SYSTREE.ID_OWN
  ,NAME    type of column SYSTREE.NAME
  ,OPTIONS type of column SYSTREE.OPTIONS
  ,VIEWER  type of column SYSTREE.VIEWER
  ,TAG     type of column SYSTREE.TAG
  ,STATE   type of column SYSTREE.STATE
  ,OPERS   type of column SYS_PRIV.OPERS
)as
begin
  :UID = coalesce(:UID, SYS_USERID());
  :OPERS = -1;
  if (IS_ADMIN(:UID) = 1) then
    for
      select t.ID,t.ID_OWN,t.NAME,t.OPTIONS,t.VIEWER,t.TAG,t.STATE
      from SYSTREE$VWE t
      into :ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE
    do
      suspend
  ;
  else
  begin
    -- out root node
    :OPERS = 1; -- can select
    select t.ID,t.ID_OWN,t.NAME,t.OPTIONS,t.VIEWER,t.TAG,t.STATE
    from SYSTREE$VWE t
    where t.ID = x'00000000000000000000000000000000'
    into :ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE;
    suspend;
    -- out tree nodes
    for
      select t.ID,t.ID_OWN,t.NAME,t.OPTIONS,t.VIEWER,t.TAG,t.STATE,p.OPERS
      from SYSTREE$VWE t
      join SYS_USER_PRIVS(:UID) p on p.ROOT is null and p.OBJ = t.ID
      into :ID,:ID_OWN,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE,:OPERS
    do
      suspend;
  end
end;
comment on procedure SYS_USER_TREE is
'Объекты доступа, на которые у пользователя есть привилегии (минимум select) и сумма этих привилегий';
grant select on SYSTREE$VWE to procedure SYS_USER_TREE;
grant execute on procedure SYS_USER_PRIVS to procedure SYS_USER_TREE;
grant execute on procedure SYS_USER_TREE to IT,RWORKER;
-----------------------------------------------------------

create or alter procedure AdmUser$Edits(
   AOPERATION DINT
  ,iID        DGUID_STR
  ,iLOGIN     DVCHAR32
  ,iNAME      DVCHAR32
  ,iTABNUM    DINT
  ,iEXPDATE   DDATE
  ,iPHONE     DVCHAR32
  ,iEMAIL     DVCHAR48
)returns(
   ID        type of column SUBJECTS.ID
  ,IS_USER   DINT
  ,IS_ADMIN  DINT
  ,LOGIN     type of column SUBJECTS.LOGIN
  ,NAME      type of column SUBJECTS.NAME
  ,TABNUM    type of column SUBJECTS.TABNUM
  ,EXPDATE   type of column SUBJECTS.EXPDATE
  ,PHONE     type of column SUBJECTS.PHONE
  ,EMAIL     type of column SUBJECTS.EMAIL
  ,STATE     type of column SUBJECTS.STATE
  ,MODDT     type of column SUBJECTS.MODDT
  ,MODUSER   type of column SUBJECTS.MODUSER
)as
  declare variable STAT type of column SUBJECTS.STATE;
  declare variable DBA DINT;
begin
  :iID = AsUUID(:iID);
  :STAT = null;
  if (:AOPERATION = 0) then
    :STAT = 0;
  execute procedure SUBJECTS$(:AOPERATION,:iID,0,:iLOGIN,:iNAME,:iTABNUM,
     :iEXPDATE,:iPHONE,:iEMAIL,:STAT
  )returning_values :ID;

  select t.IS_DBA from SEC$USERS$VW t where t.USER_NAME = current_user
  into :DBA;
  if (row_count = 0) then :DBA = 0;
  :DBA = iif(:DBA = 0,1,0);
  select t.ID,iif(s.USER_NAME is null,:DBA,1) Is_User,
         sign(t.IS_ADMIN + coalesce(s.IS_DBA,0)) IS_ADMIN,
         t.LOGIN,t.NAME,t.TABNUM,t.EXPDATE,t.PHONE,t.EMAIL,t.STATE
  from SYS_USERS$VWE t
  left join SEC$USERS$VW s on s.USER_NAME = t.LOGIN
  where t.ID = :ID
  into :ID,:IS_USER,:IS_ADMIN,:LOGIN,:NAME,:TABNUM,:EXPDATE,:PHONE,:EMAIL,:STATE;
  if (row_count > 0) then
    suspend;
end;
GRANT EXECUTE ON PROCEDURE SUBJECTS$ TO PROCEDURE ADMUSER$EDITS;
GRANT SELECT ON SEC$USERS$VW TO PROCEDURE ADMUSER$EDITS;
GRANT SELECT ON SYS_USERS$VWE TO PROCEDURE ADMUSER$EDITS;
GRANT EXECUTE ON PROCEDURE ADMUSER$EDITS to IT,RWORKER;
-----------------------------------------------------------

create or alter procedure AdmGetUsersList(
   OBJ  DGUID_STR
  ,ROOT DGUID_STR = null
)returns(
   ID        type of column SUBJECTS.ID
  ,IS_ADMIN  DINT
  ,LOGIN     type of column SUBJECTS.LOGIN
  ,NAME      type of column SUBJECTS.NAME
  ,TABNUM    type of column SUBJECTS.TABNUM
  ,EXPDATE   type of column SUBJECTS.EXPDATE
  ,PHONE     type of column SUBJECTS.PHONE
  ,EMAIL     type of column SUBJECTS.EMAIL
  ,STATE     type of column SUBJECTS.STATE
  ,MODDT     type of column SUBJECTS.MODDT
  ,MODUSER   type of column SUBJECTS.MODUSER
)as
  declare variable OPERS  type of column SYS_PRIV.OPERS;
  declare variable TAG    type of column SYSTREE.TAG;
  declare variable VIEWER type of column SYSTREE.VIEWER;
begin
  :OBJ = ASUUID(:OBJ);
  :ROOT = ASUUID(:ROOT);
  execute procedure GetRights(:OBJ,:ROOT) returning_values :OPERS,:TAG,:VIEWER;
  if (BITGET(:OPERS,0) = 0) then -- can select rights?
    exit;
  if (:VIEWER = 5 and :TAG = 0) then  -- Пользователи
    for
      select t.ID,t.IS_ADMIN,t.LOGIN,t.NAME,t.TABNUM,
             t.EXPDATE,t.PHONE,t.EMAIL,t.STATE,t.MODDT,t.MODUSER
      from SYS_USERS$VWE t
      into :ID,:IS_ADMIN,:LOGIN,:NAME,:TABNUM,
           :EXPDATE,:PHONE,:EMAIL,:STATE,:MODDT,:MODUSER
    do
      suspend;
  else
  if (:VIEWER = 8 and :TAG = 1) then  -- Доверители @root'a
    for
      select t.ID,t.IS_ADMIN,t.LOGIN,t.NAME,t.TABNUM,
             t.EXPDATE,t.PHONE,t.EMAIL,t.STATE,t.MODDT,t.MODUSER
      from SYS_USERS$VWE t
      where exists(
        select * from SUBJLINK$VWA s
        where s.GRP = 0 and s.URP = 0 and s.UID = :ROOT
          and s.GID = t.ID
      )
      into :ID,:IS_ADMIN,:LOGIN,:NAME,:TABNUM,
           :EXPDATE,:PHONE,:EMAIL,:STATE,:MODDT,:MODUSER
    do
      suspend;
  else
  if (:VIEWER = 8 and :TAG = 2) then  -- Доверенные @root'a
    for
      select t.ID,t.IS_ADMIN,t.LOGIN,t.NAME,t.TABNUM,
             t.EXPDATE,t.PHONE,t.EMAIL,t.STATE,t.MODDT,t.MODUSER
      from SYS_USERS$VWE t
      where exists(
        select * from SUBJLINK$VWA s
        where s.GRP = 0 and s.URP = 0 and s.GID = :ROOT
          and s.UID = t.ID
      )
      into :ID,:IS_ADMIN,:LOGIN,:NAME,:TABNUM,
           :EXPDATE,:PHONE,:EMAIL,:STATE,:MODDT,:MODUSER
    do
      suspend;
  else
  if (:VIEWER = 8 and :TAG = 3) then  -- С ролью @root
    for
      select t.ID,t.IS_ADMIN,t.LOGIN,t.NAME,t.TABNUM,
             t.EXPDATE,t.PHONE,t.EMAIL,t.STATE,t.MODDT,t.MODUSER
      from SYS_USERS$VWE t
      where exists(
        select * from SUBJLINK$VWA s
        where s.GRP > 0 and s.URP = 0 and s.GID = :ROOT
          and s.UID = t.ID
      )
      into :ID,:IS_ADMIN,:LOGIN,:NAME,:TABNUM,
           :EXPDATE,:PHONE,:EMAIL,:STATE,:MODDT,:MODUSER
    do
      suspend;
  else
  if (:VIEWER = 8 and :TAG = 4) then  -- На должности @root
    for
      select t.ID,t.IS_ADMIN,t.LOGIN,t.NAME,t.TABNUM,
             t.EXPDATE,t.PHONE,t.EMAIL,t.STATE,t.MODDT,t.MODUSER
      from SYS_USERS$VWE t
      where exists(
        select * from SUBJLINK$VWA s
        where s.GRP < 0 and s.URP = 0 and s.GID = :ROOT
          and s.UID = t.ID
      )
      into :ID,:IS_ADMIN,:LOGIN,:NAME,:TABNUM,
           :EXPDATE,:PHONE,:EMAIL,:STATE,:MODDT,:MODUSER
    do
      suspend;
end;
grant execute on function  ASUUID to procedure ADMGETUSERSLIST;
grant execute on function  BITGET to procedure ADMGETUSERSLIST;
grant execute on procedure GETRIGHTS to procedure ADMGETUSERSLIST;
grant select on SYS_USERS$VW to procedure ADMGETUSERSLIST;
grant select on SYS_USERS$VWE to procedure ADMGETUSERSLIST;
grant select on SUBJLINK$VWA to procedure ADMGETUSERSLIST;
grant execute on procedure ADMGETUSERSLIST to IT,RWORKER;
comment on procedure AdmGetUsersList is 'реестр пользователей
 ROOT - ID субъекта доступа. null для работы с пользователями,
        иначе ID узла структуры роли (должности) для пользователей.
';

-----------------------------------------------------------

create or alter procedure AdmGetRolesList(
   OBJ  DGUID_STR
  ,ROOT DGUID_STR = null
)returns(
   ID        type of column SUBJECTS.ID
  ,GRP       type of column SUBJECTS.GRP
  ,LINKED    DBOOL
  ,EXPDATE   type of column SUBJLINK.EXPDATE
  ,NAME      type of column SUBJECTS.NAME
  ,STATE     type of column SUBJECTS.STATE
  ,MODDT     type of column SUBJECTS.MODDT
  ,MODUSER   type of column SUBJECTS.MODUSER
)as
  declare variable OPERS  type of column SYS_PRIV.OPERS;
  declare variable TAG    type of column SYSTREE.TAG;
  declare variable VIEWER type of column SYSTREE.VIEWER;
begin
  :OBJ = ASUUID(:OBJ);
  :ROOT = ASUUID(:ROOT);
  execute procedure GetRights(:OBJ,:ROOT) returning_values :OPERS,:TAG,:VIEWER;
  if (BITGET(:OPERS,0) = 0) then -- can select rights?
    exit;
  if (:VIEWER = 6 and :TAG = 0) then  -- роли
    for
      select t.ID,t.GRP,t.NAME,t.STATE,t.MODDT,t.MODUSER
      from SYS_ROLES$VWE t
      into :ID,:GRP,:NAME,:STATE,:MODDT,:MODUSER
    do
      suspend;
  else
  if (:VIEWER = 9 and :TAG = 1) then  -- Роли пользователя @root
    for
      with s as(
        select * from SUBJLINK$VWA ss
        where ss.GRP > 0 and ss.URP = 0 and ss.UID = :ROOT
      )
      select t.ID,t.GRP,s.ID is not null LINKED,t.NAME,t.STATE,t.MODDT,t.MODUSER
      from SYS_ROLES$VWE t
      left join s on s.GID = t.ID
      into :ID,:GRP,:LINKED,:NAME,:STATE,:MODDT,:MODUSER
    do
      suspend;
  else
  if (:VIEWER = 9 and :TAG = 2) then  -- Роли должности @root
    for
      with s as(
        select * from SUBJLINK$VWA ss
        where ss.GRP < 0 and ss.URP > 0 and ss.UID = :ROOT
      )
      select t.ID,t.GRP,s.ID is not null LINKED,t.NAME,t.STATE,t.MODDT,t.MODUSER
      from SYS_ROLES$VWE t
      left join s on s.UID = t.ID
      into :ID,:GRP,:LINKED,:NAME,:STATE,:MODDT,:MODUSER
    do
      suspend;
end;
grant execute on function  ASUUID to procedure AdmGetRolesList;
grant execute on function  BITGET to procedure AdmGetRolesList;
grant execute on procedure GETRIGHTS to procedure AdmGetRolesList;
grant select on SYS_ROLES$VWE to procedure AdmGetRolesList;
grant select on SUBJLINK$VWA to procedure AdmGetRolesList;
grant execute on procedure AdmGetRolesList to IT,RWORKER;
comment on procedure AdmGetRolesList is 'роли.
 ROOT - ID субъекта доступа. null для работы с ролями,
        иначе ID узла структуры пользователя (должности) для ролей.
';
-----------------------------------------------------------

create or alter procedure AdmRole$Edits(
   AOPERATION DINT
  ,iID        DGUID_STR
  ,iNAME      DVCHAR32
)returns(
   ID        type of column SUBJECTS.ID
  ,GRP       type of column SUBJECTS.GRP
  ,NAME      type of column SUBJECTS.NAME
  ,STATE     type of column SUBJECTS.STATE
  ,MODDT     type of column SUBJECTS.MODDT
  ,MODUSER   type of column SUBJECTS.MODUSER
)as
  declare variable STAT type of column SUBJECTS.STATE;
begin
  :iID = AsUUID(:iID);
  :STAT = null;
  if (:AOPERATION = 0) then
    :STAT = 0;
  execute procedure SUBJECTS$(:AOPERATION,:iID,100,:iNAME,:iNAME,null,
     null,null,null,:STAT
  )returning_values :ID;

  select t.ID,t.GRP,t.NAME,t.STATE,t.MODDT,t.MODUSER
  from SYS_ROLES$VWE t
  where t.ID = :ID
  into :ID,:GRP,:NAME,:STATE,:MODDT,:MODUSER;
  if (row_count > 0) then
    suspend;
end;
GRANT EXECUTE ON FUNCTION ASUUID TO PROCEDURE ADMROLE$EDITS;
GRANT EXECUTE ON PROCEDURE SUBJECTS$ TO PROCEDURE ADMROLE$EDITS;
GRANT SELECT ON SYS_ROLES$VWE TO PROCEDURE ADMROLE$EDITS;
GRANT EXECUTE ON PROCEDURE AdmRole$Edits to IT,RWORKER;
----------------------------------------------------------------

create or alter procedure UserSubTree(
   OBJ   DGUID_STR
  ,ROOT  DGUID_STR = null
  ,UID   DGUID_STR = null
)returns(
   ID      type of column SYSTREE.ID
  ,NAME    type of column SYSTREE.NAME
  ,OPTIONS type of column SYSTREE.OPTIONS
  ,VIEWER  type of column SYSTREE.VIEWER
  ,TAG     type of column SYSTREE.TAG
  ,STATE   type of column SYSTREE.STATE
  ,OPERS   type of column SYS_PRIV.OPERS
  ,ID_OWN  type of column SYSTREE.ID_OWN
  ,MODDT   type of column SYSTREE.MODDT
  ,MODUSER type of column SYSTREE.MODUSER
)as
  declare variable tmp DGUID;
begin
  :OBJ = AsUUID(:OBJ);
  :ROOT = AsUUID(:ROOT);
  :UID = AsUUID(:UID);
  :tmp = SYS_USERID();
  :UID = coalesce(:UID, :tmp);
  if (0 = IS_ADMIN()) then
    :UID = :tmp;

  if (:OBJ = :ROOT) then -- никаких not distinct! у комплексного узла не может быть ID is null
  begin -- требуется найти корневой узел структуры документа для обычного узла :OBJ
    select t.ID
    from SYSTREE$VWE t
    where t.VIEWER = (select tt.VIEWER from SYSTREE$VWE tt where tt.ID = :OBJ)
      and t.TAG = -2
    into :OBJ;
    if (row_count = 0) then exit;
  end
  if (1 = IS_ADMIN() and :UID = :tmp) then
  begin -- админы видят всё
    :OPERS = -1;
    for
      with a as(
        select * from SYSTREE$VWE t
        where t.ID_OWN is not distinct from :OBJ
      )
      select a.ID,a.NAME,bin_or(a.OPTIONS,iif(b.ID is null,0,0x80000000)) OPTIONS,
             a.VIEWER,a.TAG,a.STATE,a.ID_OWN,a.MODDT,a.MODUSER
      from a
      left join SYSTREE$VWE b on b.TAG = -2 and b.VIEWER = a.VIEWER
                        and b.ID is distinct from a.ID
      into :ID,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE,:ID_OWN,:MODDT,:MODUSER
    do
      suspend;
    exit;
  end
  ---- для простых смертных схлопываем привилегии
  for
    with a as(
        select t.ID,t.ID_OWN,t.NAME,
               bin_or(t.OPTIONS,iif(c.ID is null,0,0x80000000)) OPTIONS,
               t.VIEWER,t.TAG,t.STATE,t.MODDT,t.MODUSER
        from      SYSTREE$VWE t
        left join SYSTREE$VWE c on c.TAG = -2 and c.VIEWER = t.VIEWER
                               and c.ID is distinct from t.ID
        where t.ID_OWN is not distinct from :OBJ
    )
    select a.ID,a.NAME,a.OPTIONS,a.VIEWER,a.TAG,a.STATE,p.OPERS,
           a.ID_OWN,a.MODDT,a.MODUSER
    from a
    join GTT_PRIVS p on p.OBJ = a.ID
    into :ID,:NAME,:OPTIONS,:VIEWER,:TAG,:OPERS,:STATE,:ID_OWN,:MODDT,:MODUSER
  do
    suspend;
end
;
grant execute on function ASUUID to procedure USERSUBTREE;
grant execute on function SYS_USERID to procedure USERSUBTREE;
grant execute on function IS_ADMIN to procedure USERSUBTREE;
grant select on SYSTREE$VWE to procedure USERSUBTREE;
grant all on GTT_PRIVS to procedure USERSUBTREE;
grant execute on procedure USERSUBTREE to IT,RWORKER;
comment on procedure USERSUBTREE is
'Читать подузлы узла OBJ с учетом привилегий п-ля UID и значения ROOT.
Если текущий п-ль не IS_ADMIN, UID игорируется, если UID не указан - текущий п-ль.';
---------------------------------------------------------

-----------------------------------------------