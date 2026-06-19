unit uLang;

// Gestion de idioma (Espanol / Ingles) para la UI.
// Las cadenas con acentos se escriben con codigos #NNN (cp1252/Unicode)
// para que el fuente sea ASCII puro y no dependa de la codificacion del archivo.
// NOTA: el protocolo del servidor TCP NO se traduce (es para clientes maquina).

interface

type
  TLanguage = (lnEs, lnEn);

  TStrId = (
    siGbSerial, siLblPuerto, siLblBaudios, siLblDataBits, siLblParidad, siLblStopBits,
    siGbDirecciones, siLblEjeX, siLblEjeY, siLblEjeZ,
    siGbPuertoServidor, siLblPuertoSrv, siGbParametros, siLblIntervalo,
    siConectar, siDesconectar, siDeteniendo, siErrIniciando, siErrorPrefix,
    siConectado, siDesconectado,
    siBobinaX, siBobinaY, siBobinaZ, siVoltage, siCurrent,
    siErrNoAddr, siErrLectura, siErrExcepHilo, siErrAbrirPuerto, siErrNoPudoAbrir,
    siErrConfig, siErrEscribiendo, siErrLeyendo, siErrEnviando, siErrTimeout,
    siErrRespCorta, siErrCRC, siErrEscritura, siErrModbusCode, siErrRespIncReg,
    siErrRespIncCoils,
    siLblIdioma, siAppTitle
  );

procedure SetLanguage(ALang: TLanguage);
function CurrentLanguage: TLanguage;
function Tr(Id: TStrId): string;
function DetectDefaultLanguage: TLanguage;
function LanguageName(L: TLanguage): string;

implementation

uses
  Winapi.Windows;

var
  GLang: TLanguage = lnEs;

const
  STRINGS: array [TLanguage, TStrId] of string = (
    // ===== Espanol (lnEs) =====
    (
      ' Configuraci'#243'n Puerto Serie ',
      'Puerto:',
      'Baudios:',
      'Data Bits:',
      'Paridad:',
      'Stop Bits:',
      ' Direcci'#243'n equipos ',
      'Eje X:',
      'Eje Y:',
      'Eje Z:',
      ' Puerto servidor',
      'Puerto',
      ' Par'#225'metros ',
      'Intervalo ',
      'Conectar Modbus',
      'Desconectar Modbus',
      'Deteniendo hilo existente...',
      'Error iniciando comunicaci'#243'n Modbus: ',
      'ERROR: ',
      'Conectado al dispositivo Modbus',
      'Desconectado del dispositivo Modbus',
      'BOBINA EJE X',
      'BOBINA EJE Y',
      'BOBINA EJE Z',
      'VOLTAJE',
      'CORRIENTE',
      'No hay direcciones modbus definidas.',
      'Error en lectura peri'#243'dica: ',
      'Excepci'#243'n en hilo Modbus: ',
      'Error al abrir puerto serie: ',
      'No se pudo abrir el puerto ',
      'Error configurando puerto serie: ',
      'Error escribiendo al puerto serie: ',
      'Error leyendo del puerto serie: ',
      'Error enviando comando',
      'Timeout esperando respuesta',
      'Respuesta muy corta',
      'Error de CRC (Calc: $%4.4x, Recv: $%4.4x)',
      'Error en escritura: ',
      'Error Modbus c'#243'digo: ',
      'Respuesta incompleta para registros',
      'Respuesta incompleta para coils',
      'Idioma:',
      'BHC2000 - Escuela de Ingenier'#237'a Aeron'#225'utica y del Espacio de la Universidad de Vigo'
    ),
    // ===== English (lnEn) =====
    (
      ' Serial Port Settings ',
      'Port:',
      'Baud rate:',
      'Data bits:',
      'Parity:',
      'Stop bits:',
      ' Device addresses ',
      'X axis:',
      'Y axis:',
      'Z axis:',
      ' Server port',
      'Port',
      ' Parameters ',
      'Interval ',
      'Connect Modbus',
      'Disconnect Modbus',
      'Stopping existing thread...',
      'Error starting Modbus communication: ',
      'ERROR: ',
      'Connected to Modbus device',
      'Disconnected from Modbus device',
      'X AXIS COIL',
      'Y AXIS COIL',
      'Z AXIS COIL',
      'VOLTAGE',
      'CURRENT',
      'No Modbus addresses defined.',
      'Periodic read error: ',
      'Modbus thread exception: ',
      'Error opening serial port: ',
      'Could not open port ',
      'Error configuring serial port: ',
      'Error writing to serial port: ',
      'Error reading from serial port: ',
      'Error sending command',
      'Timeout waiting for response',
      'Response too short',
      'CRC error (Calc: $%4.4x, Recv: $%4.4x)',
      'Write error: ',
      'Modbus error code: ',
      'Incomplete response for registers',
      'Incomplete response for coils',
      'Language:',
      'BHC2000 - School of Aeronautical and Space Engineering of the University of Vigo'
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
  // Autonimo: cada idioma se muestra en su propio nombre.
  case L of
    lnEs: Result := 'Espa'#241'ol';
    lnEn: Result := 'English';
  else
    Result := '';
  end;
end;

function DetectDefaultLanguage: TLanguage;
begin
  // Ingles si el idioma de la UI de Windows es ingles; en cualquier otro caso, espanol.
  if PRIMARYLANGID(GetUserDefaultUILanguage) = LANG_ENGLISH then
    Result := lnEn
  else
    Result := lnEs;
end;

end.
