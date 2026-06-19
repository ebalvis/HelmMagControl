program poc;
{ Prueba de concepto del nucleo portable a FPC/Lazarus (multiplataforma).
  Demuestra: codigo Modbus portado + i18n UTF-8 + servidor TCP del protocolo
  con ssockets (mismo fuente para Windows/Linux/macOS). }
{$mode objfpc}{$H+}
{$codepage UTF8}

uses
  {$ifdef unix}cthreads,{$endif}
  SysUtils, umodbus_core, upsbackend, utcpserver;

const
  TITLE_ES = 'BHC2000 - Escuela de Ingeniería Aeronáutica y del Espacio de la Universidad de Vigo';
  TITLE_EN = 'BHC2000 - School of Aeronautical and Space Engineering of the University of Vigo';

var
  srv: TPocTcpServer;
begin
  Writeln('== POC HelmMagControl (FPC ', {$I %FPCVERSION%}, ' / ',
          {$I %FPCTARGETOS%}, '-', {$I %FPCTARGETCPU%}, ') ==');
  Writeln('i18n UTF-8 ES: ', TITLE_ES);
  Writeln('i18n UTF-8 EN: ', TITLE_EN);

  if SelfTestModbus then
    Writeln('SELF-TEST Modbus (CRC + tramas + parseo): OK')
  else
  begin
    Writeln('SELF-TEST Modbus: FALLO');
    Halt(1);
  end;

  srv := TPocTcpServer.Create(4444);
  try
    Writeln('Servidor TCP en 0.0.0.0:4444  (PING, READ ALL, SET V1 12.5, GET V1, OUT 1 ON, ...)');
    Writeln('Ctrl+C para salir.');
    srv.Run;
  finally
    srv.Free;
  end;
end.
