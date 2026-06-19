unit umodbusclient;
{ Transaccion Modbus sobre la capa serie abstracta. Equivalente portable
  de SendModbusCommand de la version Delphi (build + write + read + CRC + parse). }
{$mode objfpc}{$H+}

interface

uses
  umodbus_core, userial;

function ModbusReadHolding(const Serial: ISerialTransport; SlaveID: Byte;
  Addr, Count: Word; out Values: TMbWords; out Err: string): Boolean;

implementation

uses
  SysUtils;

function ModbusReadHolding(const Serial: ISerialTransport; SlaveID: Byte;
  Addr, Count: Word; out Values: TMbWords; out Err: string): Boolean;
var
  req, resp: TMbBytes;
  expected: Integer;
  crcRecv, crcCalc: Word;
begin
  Result := False;
  SetLength(Values, 0);
  Err := '';

  req := BuildReadHolding(SlaveID, Addr, Count);
  Serial.Flush;
  if not Serial.Write(req) then
  begin
    Err := 'Error enviando comando: ' + Serial.LastError;
    Exit;
  end;

  expected := 5 + Count * 2; // slave+func+bytecount + datos + CRC(2)
  Serial.Read(expected, resp);
  if Length(resp) < 5 then
  begin
    Err := 'Timeout / respuesta muy corta';
    Exit;
  end;

  crcRecv := resp[High(resp) - 1] or (resp[High(resp)] shl 8);
  crcCalc := ModbusCRC(Copy(resp, 0, Length(resp) - 2));
  if crcRecv <> crcCalc then
  begin
    Err := Format('Error de CRC (calc %4.4x, recv %4.4x)', [crcCalc, crcRecv]);
    Exit;
  end;

  Result := ParseRegisters(resp, Values);
  if not Result then
    Err := 'Parseo de registros fallo';
end;

end.
