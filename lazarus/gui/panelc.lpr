program panelc;
{ POC de la GUI en LCL (multiplataforma). Crea el formulario del canal en
  codigo (CreateNew, sin .lfm) y arranca. }
{$mode objfpc}{$H+}

uses
  Interfaces, // inicializa el widgetset de la LCL (win32/gtk/qt/cocoa)
  Forms,
  uform, useg7;

var
  F: TPanelForm;
begin
  Application.Initialize;
  Application.Title := 'panelc';
  F := TPanelForm.CreateNew(Application);
  F.BuildUI;
  F.Show;
  Application.Run;
end.
