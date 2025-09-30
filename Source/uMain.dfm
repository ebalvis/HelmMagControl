object fMain: TfMain
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'BHC2000 - Escola de Ingienier'#237'a Aeron'#225'utica y del Espacio'
  ClientHeight = 898
  ClientWidth = 705
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnClose = FormClose
  OnCreate = FormCreate
  TextHeight = 15
  object StatusBar1: TStatusBar
    Left = 0
    Top = 879
    Width = 705
    Height = 19
    Panels = <
      item
        Width = 150
      end
      item
        Width = 200
      end
      item
        Width = 50
      end>
    ExplicitTop = 871
    ExplicitWidth = 703
  end
  object ScrollBox1: TScrollBox
    Left = 0
    Top = 0
    Width = 482
    Height = 879
    Align = alLeft
    BorderStyle = bsNone
    TabOrder = 1
    ExplicitLeft = -2
    ExplicitTop = 8
  end
  object Panel1: TPanel
    Left = 482
    Top = 0
    Width = 223
    Height = 879
    Align = alClient
    TabOrder = 2
    ExplicitWidth = 221
    ExplicitHeight = 871
    object btnConnect: TButton
      AlignWithMargins = True
      Left = 4
      Top = 4
      Width = 215
      Height = 25
      Action = actConectar
      Align = alTop
      TabOrder = 0
      ExplicitWidth = 213
    end
    object GroupBox1: TGroupBox
      Left = 1
      Top = 32
      Width = 221
      Height = 169
      Align = alTop
      Caption = ' Configuraci'#243'n Puerto Serie '
      TabOrder = 1
      ExplicitWidth = 219
      object Label1: TLabel
        Left = 16
        Top = 24
        Width = 38
        Height = 15
        Caption = 'Puerto:'
      end
      object Label2: TLabel
        Left = 16
        Top = 51
        Width = 45
        Height = 15
        Caption = 'Baudios:'
      end
      object Label3: TLabel
        Left = 16
        Top = 78
        Width = 49
        Height = 15
        Caption = 'Data Bits:'
      end
      object Label4: TLabel
        Left = 16
        Top = 105
        Width = 43
        Height = 15
        Caption = 'Paridad:'
      end
      object Label5: TLabel
        Left = 16
        Top = 132
        Width = 49
        Height = 15
        Caption = 'Stop Bits:'
      end
      object cmbPuerto: TComboBox
        Left = 80
        Top = 21
        Width = 73
        Height = 23
        Style = csDropDownList
        TabOrder = 0
      end
      object cmbBaudios: TComboBox
        Left = 80
        Top = 48
        Width = 73
        Height = 23
        Style = csDropDownList
        TabOrder = 1
      end
      object edtBits: TEdit
        Left = 80
        Top = 75
        Width = 73
        Height = 23
        NumbersOnly = True
        TabOrder = 2
        Text = '8'
      end
      object cmbParidad: TComboBox
        Left = 80
        Top = 102
        Width = 73
        Height = 23
        Style = csDropDownList
        TabOrder = 3
      end
      object cmbStopBit: TComboBox
        Left = 80
        Top = 129
        Width = 73
        Height = 23
        Style = csDropDownList
        TabOrder = 4
      end
    end
    object GroupBox2: TGroupBox
      Left = 1
      Top = 201
      Width = 221
      Height = 105
      Align = alTop
      Caption = ' Direcci'#243'n equipos '
      TabOrder = 2
      ExplicitWidth = 219
      object Label8: TLabel
        Left = 16
        Top = 24
        Width = 28
        Height = 15
        Caption = 'Eje X:'
      end
      object Label6: TLabel
        Left = 16
        Top = 51
        Width = 28
        Height = 15
        Caption = 'Eje Y:'
      end
      object Label7: TLabel
        Left = 16
        Top = 81
        Width = 28
        Height = 15
        Caption = 'Eje Z:'
      end
      object edtEjeX: TEdit
        Left = 80
        Top = 21
        Width = 73
        Height = 23
        NumbersOnly = True
        TabOrder = 0
        Text = '8'
      end
      object edtEjeY: TEdit
        Left = 80
        Top = 48
        Width = 73
        Height = 23
        NumbersOnly = True
        TabOrder = 1
        Text = '8'
      end
      object edtEjeZ: TEdit
        Left = 80
        Top = 78
        Width = 73
        Height = 23
        NumbersOnly = True
        TabOrder = 2
        Text = '8'
      end
    end
    object GroupBox3: TGroupBox
      Left = 1
      Top = 364
      Width = 221
      Height = 58
      Align = alTop
      Caption = ' Puerto servidor'
      TabOrder = 3
      ExplicitWidth = 219
      object Label9: TLabel
        Left = 16
        Top = 24
        Width = 35
        Height = 15
        Caption = 'Puerto'
      end
      object edtPuerto: TEdit
        Left = 80
        Top = 19
        Width = 73
        Height = 23
        NumbersOnly = True
        TabOrder = 0
        Text = '4444'
      end
    end
    object GroupBox4: TGroupBox
      Left = 1
      Top = 306
      Width = 221
      Height = 58
      Align = alTop
      Caption = ' Par'#225'metros '
      TabOrder = 4
      ExplicitWidth = 219
      object Label10: TLabel
        Left = 16
        Top = 24
        Width = 49
        Height = 15
        Caption = 'Intervalo '
      end
      object edtRefresco: TEdit
        Left = 80
        Top = 21
        Width = 73
        Height = 23
        NumbersOnly = True
        TabOrder = 0
        Text = '4444'
      end
    end
  end
  object JvFormStorage1: TJvFormStorage
    AppStorage = JvAppRegistryStorage1
    AppStoragePath = '%FORM_NAME%\'
    StoredProps.Strings = (
      'cmbPuerto.ItemIndex'
      'cmbBaudios.ItemIndex'
      'cmbParidad.ItemIndex'
      'cmbStopBit.ItemIndex'
      'edtBits.Text'
      'edtEjeX.Text'
      'edtEjeY.Text'
      'edtEjeZ.Text'
      'edtRefresco.Text'
      'edtPuerto.Text')
    StoredValues = <>
    Left = 264
    Top = 304
  end
  object JvAppRegistryStorage1: TJvAppRegistryStorage
    StorageOptions.BooleanStringTrueValues = 'TRUE, YES, Y'
    StorageOptions.BooleanStringFalseValues = 'FALSE, NO, N'
    Root = '%NONE%'
    SubStorages = <>
    Left = 264
    Top = 360
  end
  object ActionList1: TActionList
    OnUpdate = ActionList1Update
    Left = 538
    Top = 680
    object actConectar: TAction
      Caption = 'Conectar Modbus'
      OnExecute = actConectarExecute
    end
  end
  object ImageList1: TImageList
    Left = 538
    Top = 624
  end
  object IdTCPServer1: TIdTCPServer
    Bindings = <>
    DefaultPort = 0
    Left = 538
    Top = 488
  end
end
