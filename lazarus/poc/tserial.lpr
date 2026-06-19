program tserial;
{ Prueba de la capa serie multiplataforma + transaccion Modbus.
  Sin argumentos: intenta un puerto inexistente (debe fallar limpio) -> valida
  que la capa serie compila, enlaza y se comporta bien sin hardware.
  Con argumento (p.ej. tserial COM5): intenta una lectura real. }
{$mode objfpc}{$H+}

uses
  {$ifdef unix}cthreads,{$endif}
  SysUtils, umodbus_core, userial, umodbusclient;

var
  cfg: TSerialConfig;
  s: ISerialTransport;
  vals: TMbWords;
  err, port: string;
  i: Integer;
begin
  if ParamCount >= 1 then
    port := ParamStr(1)
  else
    {$ifdef mswindows} port := 'COM99'; {$else} port := '/dev/ttyUSB99'; {$endif}

  cfg.Port := port;
  cfg.BaudRate := 19200;
  cfg.DataBits := 8;
  cfg.StopBits := 1;
  cfg.Parity := 'N';
  cfg.TimeoutMs := 1000;

  s := CreateSerialTransport;
  Writeln('Abriendo ', port, ' @', cfg.BaudRate, ' 8N1 ...');
  if not s.Open(cfg) then
  begin
    Writeln('No se pudo abrir: ', s.LastError);
    Writeln('(esperado sin hardware: el objetivo es que la capa serie compile y enlace)');
    Halt(0);
  end;

  Writeln('Puerto abierto. Leyendo holding registers (slave 8, addr 0, count 8)...');
  if ModbusReadHolding(s, 8, 0, 8, vals, err) then
  begin
    Write('OK registros:');
    for i := 0 to High(vals) do
      Write(' ', IntToHex(vals[i], 4));
    Writeln;
  end
  else
    Writeln('Lectura fallo: ', err);

  s.Close;
end.
