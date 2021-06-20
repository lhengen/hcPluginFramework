unit fmSplash;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, StdCtrls, System.ImageList, Vcl.ImgList, SVGIconImageListBase,
  SVGIconImageList, Vcl.BaseImageCollection, SVGIconImageCollection;

type
  TfrmSplash = class(TForm)
    lblProgress: TLabel;
    Timer1: TTimer;
    SVGIconImageCollection1: TSVGIconImageCollection;
    Image1: TImage;
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormActivate(Sender: TObject);
  private
  public
    class procedure ShowSplash;
  end;

var
  frmSplash: TfrmSplash;

implementation

{$R *.DFM}

class procedure TfrmSplash.ShowSplash;
begin
  frmSplash := TfrmSplash.Create(nil);
  frmSplash.FormStyle := fsStayOnTop;
  frmSplash.Show;
  Application.ProcessMessages;
end;

procedure TfrmSplash.FormShow(Sender: TObject);
begin
  //wait a few secs so user can see splash screen
  Timer1.enabled := True;
end;

procedure TfrmSplash.Timer1Timer(Sender: TObject);
begin
  Close;
end;

procedure TfrmSplash.FormActivate(Sender: TObject);
begin
  SVGIconImageCollection1.Draw(Image1.Canvas, Image1.ClientRect, 0, True);
end;

procedure TfrmSplash.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

end.
