object ConfigForm: TConfigForm
  Left = 721
  Top = 348
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Dragon: A 3D Game based on the DelphiDoom Engine'
  ClientHeight = 258
  ClientWidth = 330
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Icon.Data = {
    0000010001002020100000000000E80200001600000028000000200000004000
    0000010004000000000080020000000000000000000000000000000000000000
    000000008000008000000080800080000000800080008080000080808000C0C0
    C0000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0044444444400000044000000000000000444444444440000440000000000000
    0044000000444000044000000000000000440000000044000440000000000000
    0044000000004400044000000000000000440000000004400440000000000000
    0044000000000440044000000000000000440000000004400440000000000000
    0044000000000440044400000000000000440000000004400444444000000000
    0044000000004400044044400000000000440000000044000000000000000000
    0044000000444400000000000000000000444444444440000000000000000000
    0044444444400000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    000000000000000000000000000000000000000000000000000000000000FFFF
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    FFFFFFFFFFFFFE01F9FFFE0079FFFE7E39FFFE7F39FFFE7F99FFFE7F99FFFE7F
    99FFFE7F99FFFE7F98FFFE7F981FFE7F991FFE7F3FFFFE7E3FFFFE007FFFFE01
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 40
    Top = 32
    Width = 90
    Height = 13
    Caption = 'Screen resolution: '
    FocusControl = ComboBox1
  end
  object ComboBox1: TComboBox
    Left = 152
    Top = 32
    Width = 145
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    TabOrder = 0
  end
  object CheckBox1: TCheckBox
    Left = 32
    Top = 80
    Width = 97
    Height = 17
    Caption = 'Fullscreen'
    Checked = True
    State = cbChecked
    TabOrder = 1
  end
  object CheckBox2: TCheckBox
    Left = 32
    Top = 112
    Width = 97
    Height = 17
    Caption = 'Low resolution'
    TabOrder = 2
  end
  object Button1: TButton
    Left = 32
    Top = 208
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Run Dragon'
    ModalResult = 1
    TabOrder = 5
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 120
    Top = 208
    Width = 75
    Height = 25
    Caption = 'Play demo'
    ModalResult = 1
    TabOrder = 6
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 208
    Top = 208
    Width = 75
    Height = 25
    Caption = 'Record demo'
    ModalResult = 1
    TabOrder = 7
    OnClick = Button3Click
  end
  object RadioGroup1: TRadioGroup
    Left = 168
    Top = 72
    Width = 121
    Height = 105
    Caption = '      '
    ItemIndex = 0
    Items.Strings = (
      'Beginner'
      'Easy'
      'Medium'
      'Hard')
    TabOrder = 4
  end
  object CheckBox3: TCheckBox
    Left = 182
    Top = 71
    Width = 73
    Height = 17
    Caption = ' Autostart '
    TabOrder = 3
  end
  object XPManifest1: TXPManifest
    Left = 32
    Top = 152
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = 'dem'
    Filter = 'Demo Files (*.dem)|*.dem|All Files (*.*)|*.*'
    InitialDir = '.'
    Options = [ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 120
    Top = 152
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'dem'
    Filter = 'Demo Files (*.dem)|*.dem|All Files (*.*)|*.*'
    InitialDir = '.'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofPathMustExist, ofEnableSizing]
    Left = 200
    Top = 152
  end
end
