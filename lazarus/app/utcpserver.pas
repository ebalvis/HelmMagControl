unit utcpserver;
{ Servidor TCP del protocolo de texto, ejecutado en un hilo aparte (no bloquea
  la GUI). El procesamiento de cada comando se delega a un callback que el
  formulario principal marshala al hilo principal (Synchronize) para tocar la UI.
  ssockets es multiplataforma (Windows/Linux/macOS). }
{$mode objfpc}{$H+}

interface

uses
  Classes, ssockets;

type
  TCmdHandler = function(const Cmd: string): string of object;

  TTcpServer = class
  private
    FPort: Word;
    FHandler: TCmdHandler;
    FServer: TInetServer;
    FThread: TThread;
    procedure DoConnect(Sender: TObject; Data: TSocketStream);
  public
    constructor Create(APort: Word; AHandler: TCmdHandler);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  end;

implementation

uses
  SysUtils;

type
  TAcceptThread = class(TThread)
  private
    FSrv: TInetServer;
  protected
    procedure Execute; override;
  public
    constructor Create(ASrv: TInetServer);
  end;

constructor TAcceptThread.Create(ASrv: TInetServer);
begin
  FSrv := ASrv;
  inherited Create(False);
end;

procedure TAcceptThread.Execute;
begin
  try
    FSrv.StartAccepting;
  except
    // StopAccepting cierra el socket y aborta el accept: salida normal.
  end;
end;

function ReadLine(S: TSocketStream; out line: string): Boolean;
var
  c: Char;
  n: Integer;
begin
  line := '';
  repeat
    n := S.Read(c, 1);
    if n <= 0 then Exit(False);
    if c = #10 then Exit(True);
    if c <> #13 then line := line + c;
  until False;
end;

constructor TTcpServer.Create(APort: Word; AHandler: TCmdHandler);
begin
  FPort := APort;
  FHandler := AHandler;
end;

destructor TTcpServer.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TTcpServer.Start;
begin
  if Assigned(FServer) then Exit;
  FServer := TInetServer.Create(FPort);
  FServer.OnConnect := @DoConnect;
  FThread := TAcceptThread.Create(FServer);
end;

procedure TTcpServer.Stop;
begin
  if Assigned(FServer) then
    FServer.StopAccepting(True);
  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FreeAndNil(FServer);
end;

procedure TTcpServer.DoConnect(Sender: TObject; Data: TSocketStream);
var
  line, resp: string;
begin
  while ReadLine(Data, line) do
  begin
    if Assigned(FHandler) then
      resp := FHandler(Trim(line)) + #13#10
    else
      resp := 'ERROR NoHandler'#13#10;
    Data.Write(resp[1], Length(resp));
  end;
end;

end.
