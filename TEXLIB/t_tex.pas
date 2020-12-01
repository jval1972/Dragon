{$I Doom32.inc}

unit t_tex;

interface

uses
  d_delphi,
  t_main;

type
  TTexTextureManager = object(TTextureManager)
    tex1: PTexture;
  public
    constructor Create;
    function LoadHeader(stream: TStream): boolean; virtual;
    function LoadImage(stream: TStream): boolean; virtual;
    destructor Destroy; virtual;
  end;

implementation

constructor TTexTextureManager.Create;
begin
  inherited Create;
  SetFileExt('.TEX');
end;

function TTexTextureManager.LoadHeader(stream: TStream): boolean;
var
  w, h: integer;
begin
  stream.seek(0, sFromBeginning);
  stream.Read(w, SizeOf(w));
  stream.Read(h, SizeOf(h));
  FBitmap^.SetBytesPerPixel(4);
  FBitmap^.SetWidth(w);
  FBitmap^.SetHeight(h);
  result := true;
end;

function TTexTextureManager.LoadImage(stream: TStream): boolean;
begin
  stream.Read(FBitmap.GetImage^, FBitmap.GetWidth * FBitmap.GetHeight * 4);
  result := true;
end;

destructor TTexTextureManager.Destroy;
begin
  Inherited destroy;
end;

end.

