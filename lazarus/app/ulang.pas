unit ulang;
{ i18n para la app LCL. La LCL trabaja en UTF-8, asi que aqui los literales
  son UTF-8 reales (no codigos #NNN como en la version Delphi/UTF-16). }
{$mode objfpc}{$H+}
{$codepage UTF8}

interface

type
  TLanguage = (lnEs, lnEn);

  TStrId = (
    siAppTitle, siGbSerial, siLblPort, siLblBaud, siLblData, siLblParity, siLblStop,
    siGbAddr, siLblX, siLblY, siLblZ, siGbServer, siLblSrvPort, siGbParams,
    siLblInterval, siLblLang, siConnect, siDisconnect, siConnected, siDisconnected,
    siCoilX, siCoilY, siCoilZ, siConnecting
  );

procedure SetLanguage(ALang: TLanguage);
function CurrentLanguage: TLanguage;
function Tr(Id: TStrId): string;
function LanguageName(L: TLanguage): string;
function DetectDefaultLanguage: TLanguage;
function CoilTitle(Axis: Integer): string;

implementation

uses
  SysUtils
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

var
  GLang: TLanguage = lnEs;

const
  STRINGS: array [TLanguage, TStrId] of string = (
    // Español
    (
      'BHC2000 — Control de campo magnético (Lazarus)',
      ' Configuración Puerto Serie ', 'Puerto:', 'Baudios:', 'Data Bits:',
      'Paridad:', 'Stop Bits:', ' Dirección equipos ', 'Eje X:', 'Eje Y:', 'Eje Z:',
      ' Puerto servidor', 'Puerto', ' Parámetros ', 'Intervalo', 'Idioma:',
      'Conectar Modbus', 'Desconectar Modbus', 'Conectado al dispositivo Modbus',
      'Desconectado del dispositivo Modbus', 'BOBINA EJE X', 'BOBINA EJE Y', 'BOBINA EJE Z',
      'Conectando...'
    ),
    // English
    (
      'BHC2000 — Magnetic field control (Lazarus)',
      ' Serial Port Settings ', 'Port:', 'Baud rate:', 'Data bits:',
      'Parity:', 'Stop bits:', ' Device addresses ', 'X axis:', 'Y axis:', 'Z axis:',
      ' Server port', 'Port', ' Parameters ', 'Interval', 'Language:',
      'Connect Modbus', 'Disconnect Modbus', 'Connected to Modbus device',
      'Disconnected from Modbus device', 'X AXIS COIL', 'Y AXIS COIL', 'Z AXIS COIL',
      'Connecting...'
    )
  );

procedure SetLanguage(ALang: TLanguage);
begin
  GLang := ALang;
end;

function CurrentLanguage: TLanguage;
begin
  Result := GLang;
end;

function Tr(Id: TStrId): string;
begin
  Result := STRINGS[GLang, Id];
end;

function LanguageName(L: TLanguage): string;
begin
  case L of
    lnEs: Result := 'Español';
    lnEn: Result := 'English';
  else
    Result := '';
  end;
end;

function CoilTitle(Axis: Integer): string;
begin
  case Axis of
    0: Result := Tr(siCoilX);
    1: Result := Tr(siCoilY);
    2: Result := Tr(siCoilZ);
  else
    Result := '';
  end;
end;

function DetectDefaultLanguage: TLanguage;
{$IFDEF MSWINDOWS}
begin
  // PRIMARYLANGID(LANGID) and $3FF; LANG_ENGLISH = 9
  if (GetUserDefaultLangID and $3FF) = 9 then
    Result := lnEn
  else
    Result := lnEs;
end;
{$ELSE}
var
  s: string;
begin
  s := UpperCase(GetEnvironmentVariable('LANG'));
  if Copy(s, 1, 2) = 'EN' then
    Result := lnEn
  else
    Result := lnEs;
end;
{$ENDIF}

end.
