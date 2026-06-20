program bhc;
{ App LCL ensamblada: config serie + 3 paneles + i18n + hilo Modbus.
  Reutiliza el nucleo de ../poc (umodbus_core, userial) y el widget de ../gui
  (useg7). Multiplataforma (LCL). }
{$mode objfpc}{$H+}

uses
  Interfaces,
  Forms,
  umainform;

var
  F: TMainForm;
begin
  Application.Initialize;
  Application.Title := 'BHC2000';
  F := TMainForm.CreateNew(Application);
  F.BuildUI;
  F.Show;
  Application.Run;
end.
