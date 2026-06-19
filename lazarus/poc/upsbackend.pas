unit upsbackend;
{ Backend de 3 canales en memoria (mock) + parser del protocolo de texto.
  Replica la semantica del TTcpServerController de la version Delphi,
  pero sin regex (parseo manual) para no depender de unidades extra. }
{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TPowerSupply = class
  private
    FV, FI: array [1 .. 3] of Double;
    FOut: array [1 .. 3] of Boolean;
    FFS: TFormatSettings;
    function ChanValid(n: Integer): Boolean;
  public
    constructor Create;
    function Execute(const Cmd: string): string;
  end;

implementation

type
  TStrArr = array of string;

function SplitWords(const s: string): TStrArr;
var
  i: Integer;
  cur: string;
  procedure Push;
  begin
    if cur <> '' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := cur;
      cur := '';
    end;
  end;
begin
  SetLength(Result, 0);
  cur := '';
  for i := 1 to Length(s) do
    if s[i] = ' ' then
      Push
    else
      cur := cur + s[i];
  Push;
end;

function OnOff(b: Boolean): string;
begin
  if b then Result := 'ON' else Result := 'OFF';
end;

function ChanOf(const tok: string): Integer;
begin
  // tok tipo 'V1' / 'I2' -> numero tras la primera letra
  if Length(tok) >= 2 then
    Result := StrToIntDef(Copy(tok, 2, Length(tok) - 1), 0)
  else
    Result := 0;
end;

constructor TPowerSupply.Create;
var
  n: Integer;
begin
  inherited Create;
  FFS := DefaultFormatSettings;
  FFS.DecimalSeparator := '.'; // protocolo: punto invariante
  for n := 1 to 3 do
  begin
    FV[n] := 0; FI[n] := 0; FOut[n] := False;
  end;
end;

function TPowerSupply.ChanValid(n: Integer): Boolean;
begin
  Result := (n >= 1) and (n <= 3);
end;

function TPowerSupply.Execute(const Cmd: string): string;
var
  t: TStrArr;
  n: Integer;
  val: Double;
  letter: Char;
begin
  if Trim(Cmd) = '' then
    Exit('ERROR EmptyCommand');

  if SameText(Cmd, 'PING') then
    Exit('OK PONG');

  if SameText(Cmd, 'ALL OFF') then
  begin
    for n := 1 to 3 do FOut[n] := False;
    Exit('OK ALL OFF');
  end;

  if SameText(Cmd, 'READ ALL') then
  begin
    Result := 'OK';
    for n := 1 to 3 do
      Result := Result + Format(' CH%d V=%.6f I=%.6f OUT=%s',
        [n, FV[n], FI[n], OnOff(FOut[n])], FFS);
    Exit;
  end;

  t := SplitWords(Cmd);

  // SET V<n> <val> | SET I<n> <val>
  if (Length(t) = 3) and SameText(t[0], 'SET') and (Length(t[1]) >= 2) then
  begin
    letter := UpCase(t[1][1]);
    n := ChanOf(t[1]);
    if not ChanValid(n) then Exit(Format('ERROR InvalidChannel %d', [n]));
    if not TryStrToFloat(t[2], val, FFS) then Exit('ERROR BadValue');
    case letter of
      'V': begin FV[n] := val; Exit(Format('OK SET V%d=%.6f', [n, val], FFS)); end;
      'I': begin FI[n] := val; Exit(Format('OK SET I%d=%.6f', [n, val], FFS)); end;
    end;
    Exit('ERROR UnknownCommand');
  end;

  // OUT <n> ON|OFF
  if (Length(t) = 3) and SameText(t[0], 'OUT') then
  begin
    n := StrToIntDef(t[1], 0);
    if not ChanValid(n) then Exit(Format('ERROR InvalidChannel %d', [n]));
    FOut[n] := SameText(t[2], 'ON');
    Exit(Format('OK OUT %d %s', [n, OnOff(FOut[n])]));
  end;

  // GET V<n> | GET I<n> | GET P<n>
  if (Length(t) = 2) and SameText(t[0], 'GET') and (Length(t[1]) >= 2) then
  begin
    letter := UpCase(t[1][1]);
    n := ChanOf(t[1]);
    if not ChanValid(n) then Exit(Format('ERROR InvalidChannel %d', [n]));
    case letter of
      'V': Exit(Format('OK V%d=%.6f', [n, FV[n]], FFS));
      'I': Exit(Format('OK I%d=%.6f', [n, FI[n]], FFS));
      'P': Exit(Format('OK P%d=%.6f', [n, FV[n] * FI[n]], FFS));
    end;
    Exit('ERROR UnknownCommand');
  end;

  // STATUS <n>
  if (Length(t) = 2) and SameText(t[0], 'STATUS') then
  begin
    n := StrToIntDef(t[1], 0);
    if not ChanValid(n) then Exit(Format('ERROR InvalidChannel %d', [n]));
    Exit(Format('OK STATUS %d %s', [n, OnOff(FOut[n])]));
  end;

  Result := 'ERROR UnknownCommand';
end;

end.
