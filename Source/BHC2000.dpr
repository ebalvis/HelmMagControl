program BHC2000;

uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  Vcl.Forms,
  uMain in 'uMain.pas' {fMain},
  ModbusSerialThread in 'ModbusSerialThread.pas',
  uWanptekDisplay in 'uWanptekDisplay.pas' {fWanptekDisplay},
  uTcpServerController in 'uTcpServerController.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfMain, fMain);
  Application.CreateForm(TfWanptekDisplay, fWanptekDisplay);
  Application.Run;
end.
