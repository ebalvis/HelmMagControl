unit utcpserver;
{ Servidor TCP del protocolo de texto, ejecutado en un hilo aparte (no bloquea
  la GUI). El procesamiento de cada comando se delega a un callback que el
  formulario principal marshala al hilo principal (Synchronize).

  Robustez: las lecturas usan un timeout de recepcion (SO_RCVTIMEO) para que,
  si un cliente queda conectado e inactivo, ReadLine despierte cada pocos cientos
  de ms y pueda salir cuando el servidor se detiene (Desconectar/cerrar) sin
  colgarse. Multiplataforma (Windows verificado; POSIX pendiente de probar). }
{$mode objfpc}{$H+}

interface

uses
  Classes, ssockets;

type
  TCmdHandler = function(const Cmd: string): string of object;
  TMsgEvent = procedure(const Msg: string) of object;

  TTcpServer = class
  private
    FPort: Word;
    FHandler: TCmdHandler;
    FServer: TInetServer;
    FThread: TThread;
    FStopping: Boolean;
    FOnError: TMsgEvent;
    procedure DoConnect(Sender: TObject; Data: TSocketStream);
    function ReadLine(S: TSocketStream; out line: string): Boolean;
  public
    constructor Create(APort: Word; AHandler: TCmdHandler);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property OnError: TMsgEvent read FOnError write FOnError;
  end;

implementation

uses
  SysUtils
  {$IFDEF MSWINDOWS}, WinSock2{$ELSE}, BaseUnix, Sockets{$ENDIF};

const
  RECV_TIMEOUT_MS = 300;

type
  TAcceptThread = class(TThread)
  private
    FOwner: TTcpServer;
    FErr: string;
    procedure SyncErr;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TTcpServer);
  end;

constructor TAcceptThread.Create(AOwner: TTcpServer);
begin
  FOwner := AOwner;
  inherited Create(False);
end;

procedure TAcceptThread.SyncErr;
begin
  if Assigned(FOwner.FOnError) then
    FOwner.FOnError(FErr);
end;

procedure TAcceptThread.Execute;
begin
  try
    FOwner.FServer.StartAccepting;
  except
    on E: Exception do
      // Si estamos parando, la excepcion es por StopAccepting (normal). Si no,
      // es un fallo real (p.ej. bind: puerto ocupado) y se notifica.
      if not FOwner.FStopping then
      begin
        FErr := E.Message;
        Synchronize(@SyncErr);
      end;
  end;
end;

procedure SetRecvTimeout(AHandle: THandle);
{$IFDEF MSWINDOWS}
var
  tv: DWORD;
begin
  tv := RECV_TIMEOUT_MS;
  setsockopt(TSocket(AHandle), SOL_SOCKET, SO_RCVTIMEO, PAnsiChar(@tv), SizeOf(tv));
end;
{$ELSE}
var
  tv: TTimeVal;
begin
  tv.tv_sec := RECV_TIMEOUT_MS div 1000;
  tv.tv_usec := (RECV_TIMEOUT_MS mod 1000) * 1000;
  fpsetsockopt(AHandle, SOL_SOCKET, SO_RCVTIMEO, @tv, SizeOf(tv));
end;
{$ENDIF}

function IsTimeoutErr(err: Integer): Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := (err = WSAETIMEDOUT) or (err = WSAEWOULDBLOCK);
  {$ELSE}
  Result := (err = ESysEAGAIN) or (err = ESysEWOULDBLOCK) or (err = ESysEINTR);
  {$ENDIF}
end;

constructor TTcpServer.Create(APort: Word; AHandler: TCmdHandler);
begin
  FPort := APort;
  FHandler := AHandler;
  FStopping := False;
end;

destructor TTcpServer.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TTcpServer.Start;
begin
  if Assigned(FServer) then Exit;
  FStopping := False;
  FServer := TInetServer.Create(FPort);
  FServer.OnConnect := @DoConnect;
  FThread := TAcceptThread.Create(Self);
end;

procedure TTcpServer.Stop;
begin
  FStopping := True;
  if Assigned(FServer) then
    FServer.StopAccepting(True);
  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FreeAndNil(FServer);
end;

function TTcpServer.ReadLine(S: TSocketStream; out line: string): Boolean;
var
  c: Char;
  n: Integer;
begin
  line := '';
  repeat
    n := S.Read(c, 1);
    if n > 0 then
    begin
      if c = #10 then Exit(True);
      if c <> #13 then line := line + c;
    end
    else if n = 0 then
      Exit(False)                 // conexion cerrada por el cliente
    else
    begin
      // n < 0: timeout de recepcion o error real
      if FStopping or (not IsTimeoutErr(S.LastError)) then
        Exit(False);              // parando, o error de socket -> cerrar
      // timeout normal y no estamos parando: seguir esperando datos
    end;
  until False;
end;

procedure TTcpServer.DoConnect(Sender: TObject; Data: TSocketStream);
var
  line, resp: string;
begin
  SetRecvTimeout(Data.Handle);
  try
    while ReadLine(Data, line) do
    begin
      if Assigned(FHandler) then
        resp := FHandler(Trim(line)) + #13#10
      else
        resp := 'ERROR NoHandler'#13#10;
      Data.Write(resp[1], Length(resp));
    end;
  except
    // cliente caido a media lectura/escritura: cerrar la conexion sin propagar.
  end;
end;

end.
