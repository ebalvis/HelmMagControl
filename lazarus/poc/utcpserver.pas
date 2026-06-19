unit utcpserver;
{ Servidor TCP del protocolo de texto usando ssockets (fcl-net).
  ssockets es multiplataforma y viene con FPC: el mismo codigo corre
  en Windows, Linux y macOS sin cambios. }
{$mode objfpc}{$H+}

interface

uses
  ssockets, upsbackend;

type
  TPocTcpServer = class
  private
    FServer: TInetServer;
    FPS: TPowerSupply;
    procedure DoConnect(Sender: TObject; Data: TSocketStream);
  public
    constructor Create(APort: Word);
    destructor Destroy; override;
    procedure Run;
  end;

implementation

uses
  SysUtils;

function ReadLine(S: TSocketStream; out line: string): Boolean;
var
  c: Char;
  n: Integer;
begin
  line := '';
  repeat
    n := S.Read(c, 1);
    if n <= 0 then
      Exit(False); // conexion cerrada
    if c = #10 then
      Exit(True);
    if c <> #13 then
      line := line + c;
  until False;
end;

constructor TPocTcpServer.Create(APort: Word);
begin
  inherited Create;
  FPS := TPowerSupply.Create;
  FServer := TInetServer.Create(APort);
  FServer.OnConnect := @DoConnect;
end;

destructor TPocTcpServer.Destroy;
begin
  FServer.Free;
  FPS.Free;
  inherited Destroy;
end;

procedure TPocTcpServer.DoConnect(Sender: TObject; Data: TSocketStream);
var
  line, resp: string;
begin
  while ReadLine(Data, line) do
  begin
    resp := FPS.Execute(Trim(line)) + #13#10;
    Data.Write(resp[1], Length(resp));
  end;
end;

procedure TPocTcpServer.Run;
begin
  FServer.StartAccepting;
end;

end.
