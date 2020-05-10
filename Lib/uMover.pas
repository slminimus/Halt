unit uMover;

interface

uses SysUtils, Variants, UITypes, Classes, uIfProvider, usIntfs,
 usTools, usClasses, Generics.Collections;

type
  TDirection = (dirToShop, dirToOffice, dirBoth);

  TFBMover = class
  private type
    TOps = record
     kop: integer;
     src: IDBQuery; // select из источника
     dst: IDBQuery; // procedure EX_ приемника
     del: IDBQuery; // delete from BUFF источника
     fldIndex: integer;
     // индекс столбца BUFF.ID_GUID или столбца BUFF.ID_DATA в результате R.r.us
     procedure Clear;
   end;

  TOpsDict = TDictionary<integer, TOps>;
  private
    CodeFil: integer;
    nQuery: integer;
    id: integer;
    fContext: string;
    fOpsDict: TOpsDict;
    Ops: TOps;
    cops: IUsDataCache;
    shop: IConnection; // shop
    offs: IConnection; // office
    SrcCon: IConnection;
    DstCon: IConnection;
    TrsSrc: ITransaction;
    TrsDst: ITransaction;

    R: record // читатель BUFF
     R: TusRecordReader;
     ID_BUFF, kop, ID_DATA, INT_DATA, ID_GUID, SDT: Variant;
    end;

    procedure Clean;
    procedure GetOps(kop: integer);
    procedure _Process(Direction: TDirection);
    procedure DbLog(const ID_BUFF, SourCode, DestCode, OK, Msg: Variant);
    procedure _Log(const Context: string); overload;
    procedure _Log(const Context: string; const Params: array of const); overload;
  public
    class procedure Exec(LogDir, OfficeDB: string; KodFil: integer = -1;
      Direction: TDirection = dirBoth);
    constructor Create(LogDir, OfficeDB: string);
    destructor Destroy; override;
    procedure Process(KodFil: integer = -1; Direction: TDirection = dirBoth);
  end;

function QueryFromStr(const s: string = ''): IAsCommaText;

implementation

uses Math, StrUtils, uDbProvider, asLib, asLog;

function QueryFromStr(const s: string = ''): IAsCommaText;
begin
 result := NewCommaText(s, ';');
end;

{ TFBMover.TOps }

procedure TFBMover.TOps.Clear;
begin
 kop := -1;
 src := nil;
 dst := nil;
 del := nil;
 fldIndex := -1;
end;

{ TFBMover }

class procedure TFBMover.Exec(LogDir, OfficeDB: string; KodFil: integer;
  Direction: TDirection);
begin
 with Create(LogDir, OfficeDB) do
  try
   Process(KodFil, Direction);
  finally
   Free;
  end;
end;

constructor TFBMover.Create(LogDir, OfficeDB: string);
const
 TML = '\Obmen.log';
 SQL_KOPS = 'select t.STATE,t.KOP,t.QUERY from KOPS$VWE t';
var
 s: string;
begin
 LogDir := ExcludeTrailingPathDelimiter
   (ExpandPath(LogDir, ExtractFilePath(ParamStr(0))));
 ForceDirectories(LogDir);
 if not DirectoryExists(LogDir) then
  Abort;

 LogOptions.FileNameTemplate := LogDir + TML;
 LogOptions.MaxAge := 2;
 LogOptions.TimeFormat := 'hh:nn:ss';
 SetLogLevel(0);
 LogStart('>>>>>> СТАРТ >>>>>>', []);
 try
  Log('>>');
  _Log('>>  Connect to Office [%s]...', [OfficeDB]);
  offs := DbProvider.Connect(OfficeDB, 'EXCHANGER', 'Moving', 'OBMEN');
  Log('>>  OK');
  // Справочник операций
  _Log('>>  Select KOPS...');
  cops := NewUsDataCache(offs.QPrepare(SQL_KOPS).Open).Sort('KOP');
  Log('>>  OK');
  nQuery := cops.ColIndex('QUERY');
  fOpsDict := TOpsDict.Create;
 except
  s := ExceptToStr();
  LogE(s);
  DbLog(null, 0, 0, 0, s);
  raise;
 end;
end;

destructor TFBMover.Destroy;
begin
 if LogOptions.Active then
  LogStop('<<<<<< СТОП <<<<<<');
 fOpsDict.Free;
 inherited;
end;

procedure TFBMover.Clean;
begin
 id := 0;
 Ops.Clear;
 SrcCon := nil;
 DstCon := nil;
end;

procedure TFBMover._Log(const Context: string);
begin
 fContext := Context;
 Log(Context);
end;

procedure TFBMover._Log(const Context: string; const Params: array of const);
begin
 fContext := format(Context, Params);
 Log(fContext);
end;

procedure TFBMover.DbLog(const ID_BUFF, SourCode, DestCode, OK, Msg: Variant);
const
 SQL_LOG = 'execute procedure LOGOBMEN$ADD(:ID_BUFF,:SOURCODE,:DESTCODE,:OK,:CONTEXT,:MSG)';
begin
 offs.QPrepareWR(SQL_LOG).SetParams([ID_BUFF, SourCode, DestCode, OK, fContext,
   Msg]).Invoke;
end;

procedure TFBMover.Process(KodFil: integer; Direction: TDirection);
const
 SQL_SHOPS = 'select t.KODFIL,t.URL,t.NAME from SHOPS$VWE t where ';
 SQL_INFO = 'select t.KODFIL,t.NAME,SYS_USERID() UID from TCDBINFO$VW t';
 // +#13#10'where t.DIRECTION = ''??'' '
var
  uid: string;
  url: string;
  shops: IUsDataCache;
  row: integer;
  s: string;
begin
 try
  _Log('>>  Read Shop(s)...');
  shops := NewUsDataCache(offs.QPrepare(SQL_SHOPS + ifthen(KodFil > 0,
    format('t.KODFIL = %d', [KodFil]), 'bitget(t.STATE,3) = 1')).Open);
  if shops.RecordCount = 0 then
  begin
   _Log('>>  Нет т.точек для обмена');
   exit;
  end;
  Log('>>  OK');
  for row := 0 to shops.RecordCount - 1 do
  begin
   try
    Log('************************************');
    CodeFil := Coalesce(shops[row, 'KODFIL'], 0);
    url := VarToStrDef(shops[row, 'URL'], '');
    _Log('*  Connect to Shop[%d] "%s"...', [CodeFil, url]);
    Assert(url <> '',
      format('БД магазина не настроена (SYS_USERID() = "%s")', [url]));
    shop := DbProvider.Connect(url, 'EXCHANGER', 'Moving', 'OBMEN');
    Log('*  OK');
    _Log('*  Read Shop TCDBINFO...');
    with shop.QPrepare(SQL_INFO).Open do
    begin
     Assert(not EOF, format('%s: TCDBINFO is empty', [url]));
     uid := VarToStrDef(FieldValue('UID'), '');
     Assert(GuidIsValid(uid),
       format('БД магазина не настроена (SYS_USERID() = "%s")', [uid]));
     CodeFil := Coalesce(FieldValue('KODFIL'), -1);
     Log('*  Shop [%d] %s', [CodeFil, FieldValue('NAME')]);
    end;
    Log('*-----------------');
    if Direction = dirBoth then
    begin
     _Process(dirToShop);
     _Process(dirToOffice);
    end
    else
     _Process(Direction);
   except
    s := ExceptToStr();
    LogE(s);
    DbLog(null, 0, 0, 0, s);
   end;
  end;
 except
  s := ExceptToStr();
  LogE(s);
  DbLog(null, 0, 0, 0, s);
  raise;
 end;
end;

procedure TFBMover._Process(Direction: TDirection);
const
 SQL_BUFF = 'select t.ID_BUFF,t.KOP,t.ID_DATA,t.INT_DATA,t.ID_GUID,t.SDT' + CRLF
   + 'from BUFF$VW t' + CRLF + 'join KOPS$VW k on k.KOP = t.KOP' + CRLF +
   'where t.SOURCODE = :SRC and t.DESTCODE = :DST' + CRLF +
   'order by k.KOP_PRIOR, t.ID_BUFF';
var
 i: integer;
 v: Variant;
 s: string;
 ss: string;
 sCode, dCode: integer;
begin
 Clean;
 case Direction of
  dirToShop:
   begin
    Log('*  офис -> т.точка');
    sCode := 1;
    dCode := CodeFil;
    SrcCon := offs;
    DstCon := shop;
   end;
  dirToOffice:
   begin
    Log('*  т.точка -> офис');
    sCode := CodeFil;
    dCode := 1;
    SrcCon := shop;
    DstCon := offs;
   end;
 else
  raise Exception.Create('TFBMover._Process: invalid Direction value');
 end;

 TrsSrc := SrcCon.NewTRS;
 TrsDst := DstCon.NewTRS;
 TrsSrc.Start;
 try
  // BUFF источника
  _Log('Select BUFF...');
  R.R.InitByOrder(SrcCon.QPrepare(SQL_BUFF, TrsSrc).SetParam('SRC', sCode)
    .SetParam('DST', dCode).Open, SizeOf(R));
  if R.R.us.EOF then
  begin
   _Log('BUFF is empty, finish');
   DbLog(null, sCode, dCode, 1, null);
   exit;
  end;
  TrsDst.Start;
  try
   while R.R.Next do
   begin
    id := R.ID_BUFF;
    Assert(not VarIsNothing(R.kop), format('[ID_BUFF %d] KOP is null', [id]));
    GetOps(R.kop);
    v := R.R.us[Ops.fldIndex];
    Log('ID_BUFF: %d', [id], +1);
    _Log('SRC select[%s]', [VarToStrDef(v, '<null>')]);
    Ops.src.SetParams(v).Exec;
    Assert(not Ops.src.EOF,
      format('[ID_BUFF %d] Original record not found', [id]));
    for i := 0 to Ops.dst.ParamCount - 1 do
     if Ops.src.IsBlob(i) then
      Ops.dst.LoadParam(i, Ops.src, i)
     else
      Ops.dst.ParamValues[i] := Ops.src[i];
    _Log('call EX_(%s,...)', [VarToStrDef(v, '<null>')]);
    try
     Ops.dst.Exec;
    except
     Log('EX_ error! ----', +1);
     ss := '';
     for i := 0 to Ops.dst.ParamCount - 1 do
      with Ops.dst do
      begin
       s := ParamName(i) + ': ' + VarToStrDef(ParamValues[i], '<null>');
       Log(s);
       ss := ss + s + #13#10;
      end;
     Log(')--------------', -1);
     DbLog(id, sCode, dCode, 0, ss);
     Abort;
    end;

    _Log('del src[%d]', [id]);
    Ops.del.SetParams(id).Exec;
    SetLogLevel(GetLogLevel - 1);
   end;
   _Log('Commit DST');
   TrsDst.Commit;
  except
   TrsDst.Rollback;
   if not(ExceptObject is EAbort) then
   begin
    s := ExceptToStr();
    LogE(s);
    DbLog(id, sCode, dCode, 0, s);
    Abort;
   end;
   raise;
  end;
  _Log('Commit SRC');
  TrsSrc.Commit;
 except
  TrsSrc.Rollback;
  if not(ExceptObject is EAbort) then
  begin
   s := ExceptToStr();
   LogE(s);
   DbLog(id, sCode, dCode, 0, s);
  end;
 end;
end;

procedure TFBMover.GetOps(kop: integer);
var
 row: integer;
 qPost: string;
 qSelect: string;
begin
 if Ops.kop = kop then
  exit;
 if fOpsDict.TryGetValue(kop, Ops) then
  exit;
 Ops.kop := kop;
 Log('Cache operation KOP: %d', [kop], +1);

 row := cops.IndexOf('KOP', [kop]);
 Assert(row >= 0, format('[ID_BUFF %d] KOP not found: %d', [id, kop]));
 with QueryFromStr(cops[row, nQuery]) do
 begin
  qSelect := Values['TABLE'];
  qPost := Values['SPROC'];
 end;
 Assert(qSelect <> '', format('[KOP %d] "TABLE" is empty', [kop]));
 Assert(qPost <> '', format('[KOP %d] "SPROC" is empty', [kop]));
 qSelect := 'select ' + qSelect;
 qPost := 'execute procedure ' + qPost;

 _Log('Prepare Select...');
 Ops.src := SrcCon.QPrepare(qSelect, TrsSrc);
 _Log('Prepare Post...');
 Ops.dst := DstCon.QPrepare(qPost, TrsDst);
 _Log('Prepare Delete...');
 Ops.del := SrcCon.QPrepare
   ('delete from BUFF t where t.ID_BUFF = :ID_BUFF', TrsSrc);
 Log('OK', -1);
 Ops.fldIndex := (R.R.us as IDBQuery).FieldIndex(Ops.src.ParamName(0));
 fOpsDict.Add(kop, Ops);
end;

end.
