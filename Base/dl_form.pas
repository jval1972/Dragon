//
//  Dragon
//  A game for Windows based on a modified and improved version of the
//  DelphiDoom engine
//
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2021 by Jim Valavanis
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit dl_form;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, XPMan, ExtCtrls;

type
  TConfigForm = class(TForm)
    ComboBox1: TComboBox;
    CheckBox1: TCheckBox;
    Label1: TLabel;
    CheckBox2: TCheckBox;
    Button1: TButton;
    XPManifest1: TXPManifest;
    Button2: TButton;
    Button3: TButton;
    RadioGroup1: TRadioGroup;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    CheckBox3: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    function GetDefCmd(const demo: Boolean): string;
    procedure DoneCmd(const cmd: string);
  public
    { Public declarations }
    addcmds: string;
  end;

implementation

uses
  dl_utils;

{$R *.dfm}

procedure TConfigForm.FormCreate(Sender: TObject);
var
  dm: TDevMode;
  i: integer;
  s: string;
begin
  addcmds := '';
  i := 0;
  while EnumDisplaySettings(nil, i, dm) do
  begin
    if (dm.dmPelsWidth >= 640) and (dm.dmBitsPerPel = 32) then
    begin
      s := Format('%dx%d', [dm.dmPelsWidth, dm.dmPelsHeight]);
      if ComboBox1.Items.IndexOf(s) = -1 then
        ComboBox1.Items.Add(s);
    end;
    Inc(i);
  end;
  if ComboBox1.Items.Count = 0 then // JVAL -> uneeded :)
    ComboBox1.Items.Add('640x480');
  ComboBox1.ItemIndex := ComboBox1.Items.Count - 1;
end;

function TConfigForm.GetDefCmd(const demo: Boolean): string;
var
  s: string;
  w, h: integer;
begin
  result := '';
  if not CheckBox1.Checked then
    result := result + '-nofullscreen'#13#10;
  if CheckBox2.Checked then
    result := result + '-pakfile'#13#10 + 'dragon3.dat'#13#10;
  if demo or CheckBox3.Checked then
    result := result + '-skill'#13#10 + IntToStr(RadioGroup1.ItemIndex) + #13#10;
  if ComboBox1.Itemindex >= 0 then
  begin
    s := ComboBox1.Items.Strings[ComboBox1.Itemindex];
    Get2Ints(s, w, h);
    result := result + '-screenwidth'#13#10 + IntToStr(w) + #13#10'-screenheight'#13#10 + IntToStr(h) + #13#10;
  end;
end;


procedure TConfigForm.DoneCmd(const cmd: string);
begin
  addcmds := cmd;
  Close;
end;



procedure TConfigForm.Button1Click(Sender: TObject);
begin
  DoneCmd(GetDefCmd(False));
end;

procedure TConfigForm.Button2Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
    DoneCmd(GetDefCmd(True) + '-playdemo'#13#10 + OpenDialog1.FileName + #13#10);
end;

procedure TConfigForm.Button3Click(Sender: TObject);
begin
  if SaveDialog1.Execute then
    DoneCmd(GetDefCmd(True) + '-record'#13#10 + SaveDialog1.FileName + #13#10);
end;

end.
