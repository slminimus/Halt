create or alter procedure SYSTREE$(
     AOPERATION DINT
    ,ID         type of column SYSTREE.ID
    ,ID_OWN     type of column SYSTREE.ID_OWN
    ,LEAF       type of column SYSTREE.LEAF
    ,NAME       type of column SYSTREE.NAME
    ,OPTIONS    type of column SYSTREE.OPTIONS
    ,VIEWER     type of column SYSTREE.VIEWER
    ,TAG        type of column SYSTREE.TAG
    ,STATE      type of column SYSTREE.STATE
    ,MODDT      type of column SYSTREE.MODDT   = null
    ,MODUSER    type of column SYSTREE.MODUSER = null
)returns(
  OUT_ID type of column SYSTREE.ID,
)as
begin
  OUT_ID = :ID;
  -- автор версии
  if (:AOPERATION <> 3) then 
    :MODUSER = SYS_USERID();

  if (:AOPERATION = 0) then -- вставка
  begin
    OUT_ID = gen_uuid();
    insert into SYSTREE (ID,ID_OWN,LEAF,NAME,OPTIONS,VIEWER,TAG,STATE,MODDT,MODUSER)
    values (:OUT_ID,:ID_OWN,:LEAF,:NAME,:OPTIONS,:VIEWER,:TAG,
            coalesce(:STATE,0),current_timestamp,:MODUSER);
  end
  else
  if (:AOPERATION = 1) then -- изменение
  begin
    update SYSTREE A
    set A.ID_OWN = coalesce(:ID_OWN, A.ID_OWN),
        A.LEAF = coalesce(:LEAF, A.LEAF),
        A.NAME = coalesce(:NAME, A.NAME),
        A.OPTIONS = coalesce(:OPTIONS, A.OPTIONS),
        A.VIEWER = coalesce(:VIEWER, A.VIEWER),
        A.TAG = coalesce(:TAG, A.TAG),
        A.STATE = coalesce(:STATE, A.STATE),
        A.MODDT = current_timestamp,
        A.MODUSER = :MODUSER
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 2) then -- удаление
  begin
    update SYSTREE A
    set A.STATE = BITSET(A.STATE, 0, 1),
        A.MODDT = current_timestamp, 
        A.MODUSER = :MODUSER 
    where (A.ID = :OUT_ID);
  end
  else
  if (:AOPERATION = 3) then -- обмен
  begin
    update or insert into SYSTREE (ID,ID_OWN,LEAF,NAME,OPTIONS,VIEWER,TAG,STATE,MODDT,MODUSER)
    values (:OUT_ID,:ID_OWN,:LEAF,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE,:MODDT,:MODUSER)
    matching (ID);
  end
  else
    exception EX_COMMON 'Некорректный код операции: '|| :AOPERATION;
  suspend;
end;
comment on procedure SYSTREE$ is
'Процедура базовой логики для таблицы SYSTREE';
comment on parameter SYSTREE$.AOPERATION is 
'0 - вставка, 1 - изменение, 2 - удаление, 3 - репликация';
grant select,insert,delete,update on SYSTREE to procedure SYSTREE$;
grant execute on procedure SYSTREE$ to IT;
grant execute on function SYS_USERID to procedure SYSTREE$;
----------------------------------------------------------------

create or alter procedure EX_SYSTREE(
   ID       type of column SYSTREE.ID
  ,ID_OWN   type of column SYSTREE.ID_OWN
  ,LEAF     type of column SYSTREE.LEAF
  ,NAME     type of column SYSTREE.NAME
  ,OPTIONS  type of column SYSTREE.OPTIONS
  ,VIEWER   type of column SYSTREE.VIEWER
  ,TAG      type of column SYSTREE.TAG
  ,STATE    type of column SYSTREE.STATE
  ,MODDT    type of column SYSTREE.MODDT
  ,MODUSER  type of column SYSTREE.MODUSER
)as
  declare variable OUT_ID type of column SYSTREE.ID;
begin
  execute procedure SYSTREE$(3,:ID,:ID_OWN,:LEAF,:NAME,:OPTIONS,:VIEWER,:TAG,
       :STATE,:MODDT,:MODUSER
  )returning_values :OUT_ID;
end;
grant execute on procedure SYSTREE$ to procedure EX_SYSTREE;
grant execute on procedure EX_SYSTREE to OBMEN,IT;

--create or alter procedure EX$SYSTREE (
--   AOPERATION DINT,
--  ,ID_OWN   type of column SYSTREE.ID_OWN
--  ,LEAF     type of column SYSTREE.LEAF
--  ,NAME     type of column SYSTREE.NAME
--  ,OPTIONS  type of column SYSTREE.OPTIONS
--  ,VIEWER   type of column SYSTREE.VIEWER
--  ,TAG      type of column SYSTREE.TAG
--  ,STATE    type of column SYSTREE.STATE
--  ,MODDT    type of column SYSTREE.MODDT
--  ,MODUSER  type of column SYSTREE.MODUSER
--)as
--  declare variable OUT_ID type of column SYSTREE.ID;
--begin
--  execute procedure SYSTREE$(:AOPERATION, :ID, :ID_OWN, :LEAF, :NAME, :OPTIONS, :VIEWER, :TAG, :STATE, :MODDT, :MODUSER)
--  returning_values :OUT_ID;
--end;
--grant execute on procedure SYSTREE$ to procedure EX$SYSTREE;
--grant execute on procedure EX$SYSTREE to EXCHANGE;
--grant execute on procedure EX$SYSTREE to IT;
--comment on procedure EX$SYSTREE is 
--'Приемная процедура для таблицы SYSTREE';

create or alter procedure SYSTREE$EDIT(
   AOPERATION DINT,
  ,ID_OWN   type of column SYSTREE.ID_OWN
  ,LEAF     type of column SYSTREE.LEAF
  ,NAME     type of column SYSTREE.NAME
  ,OPTIONS  type of column SYSTREE.OPTIONS
  ,VIEWER   type of column SYSTREE.VIEWER
  ,TAG      type of column SYSTREE.TAG
  ,STATE    type of column SYSTREE.STATE
  ,MODDT    type of column SYSTREE.MODDT
  ,MODUSER  type of column SYSTREE.MODUSER
)returns(
  OUT_ID type of column SYSTREE.ID
)as
begin
  execute procedure SYSTREE$(:AOPERATION,:ID,:ID_OWN,:LEAF,:NAME,:OPTIONS,:VIEWER,:TAG,:STATE)
  returning_values :OUT_ID;
  suspend;
end;
comment on parameter SYSTREE$EDIT.AOPERATION is
'0 - вставка, 1 - изменение, 2 - удаление';
grant execute on procedure SYSTREE$ to procedure SYSTREE$EDIT;
grant execute on procedure SYSTREE$EDIT to RWORKER,OBMEN,IT;

