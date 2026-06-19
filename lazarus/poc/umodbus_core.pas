unit umodbus_core;
{ Nucleo Modbus RTU portado desde la version Delphi.
  100% Pascal estandar, compila en FPC 3.2.2 (Win/Linux/Mac) sin cambios. }
{$mode objfpc}{$H+}

interface

type
  TByteArray = array of Byte;
  TWordArray = array of Word;

function ModbusCRC(const Data: TByteArray): Word;
function BuildReadHolding(SlaveID: Byte; Addr, Count: Word): TByteArray;
function BuildWriteMultiple(SlaveID: Byte; Addr: Word; const Values: array of Word): TByteArray;
function ParseRegisters(const Resp: TByteArray; out Values: TWordArray): Boolean;
function SelfTestModbus: Boolean;

implementation

function ModbusCRC(const Data: TByteArray): Word;
var
  crc: Word;
  i, j: Integer;
begin
  crc := $FFFF;
  for i := 0 to High(Data) do
  begin
    crc := crc xor Data[i];
    for j := 0 to 7 do
      if (crc and 1) = 1 then
        crc := (crc shr 1) xor $A001
      else
        crc := crc shr 1;
  end;
  Result := crc;
end;

function BuildReadHolding(SlaveID: Byte; Addr, Count: Word): TByteArray;
var
  crc: Word;
begin
  SetLength(Result, 8);
  Result[0] := SlaveID;
  Result[1] := $03;
  Result[2] := Hi(Addr);
  Result[3] := Lo(Addr);
  Result[4] := Hi(Count);
  Result[5] := Lo(Count);
  crc := ModbusCRC(Copy(Result, 0, 6));
  Result[6] := Lo(crc);
  Result[7] := Hi(crc);
end;

function BuildWriteMultiple(SlaveID: Byte; Addr: Word; const Values: array of Word): TByteArray;
var
  crc: Word;
  bc, i: Integer;
begin
  bc := Length(Values) * 2;
  SetLength(Result, 9 + bc);
  Result[0] := SlaveID;
  Result[1] := $10;
  Result[2] := Hi(Addr);
  Result[3] := Lo(Addr);
  Result[4] := Hi(Word(Length(Values)));
  Result[5] := Lo(Word(Length(Values)));
  Result[6] := bc;
  for i := 0 to High(Values) do
  begin
    Result[7 + i * 2] := Hi(Values[i]);
    Result[8 + i * 2] := Lo(Values[i]);
  end;
  crc := ModbusCRC(Copy(Result, 0, 7 + bc));
  Result[7 + bc] := Lo(crc);
  Result[8 + bc] := Hi(crc);
end;

function ParseRegisters(const Resp: TByteArray; out Values: TWordArray): Boolean;
var
  bc, i: Integer;
begin
  Result := False;
  SetLength(Values, 0);
  if Length(Resp) < 5 then
    Exit;
  if (Resp[1] and $80) <> 0 then
    Exit; // excepcion Modbus
  bc := Resp[2];
  if Length(Resp) < 3 + bc + 2 then
    Exit;
  SetLength(Values, bc div 2);
  for i := 0 to High(Values) do
    Values[i] := (Resp[3 + i * 2] shl 8) or Resp[4 + i * 2];
  Result := True;
end;

function SelfTestModbus: Boolean;
var
  f: TByteArray;
  v: TWordArray;
  crc: Word;
begin
  // 1) Trama de lectura: CRC coherente con el cuerpo
  f := BuildReadHolding(8, 0, 8);
  crc := ModbusCRC(Copy(f, 0, Length(f) - 2));
  Result := (Length(f) = 8) and (f[1] = $03) and
            (f[6] = Lo(crc)) and (f[7] = Hi(crc));
  if not Result then Exit;

  // 2) Parseo de una respuesta sintetica (2 registros 0x1234, 0x5678)
  SetLength(f, 9);
  f[0] := 8; f[1] := 3; f[2] := 4;
  f[3] := $12; f[4] := $34; f[5] := $56; f[6] := $78;
  crc := ModbusCRC(Copy(f, 0, 7));
  f[7] := Lo(crc); f[8] := Hi(crc);
  Result := ParseRegisters(f, v) and (Length(v) = 2) and
            (v[0] = $1234) and (v[1] = $5678);
end;

end.
