unit fmToolbar;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, fmStdForm, ComCtrls, ToolWin, StdActns, ActnList,
  XPStyleActnCtrls, ActnMan, ActnCtrls, ActnMenus, ExtCtrls, ImgList,
  BandActn, contnrs, hcCorePlugInLoader, fmSplash,
  hcApplicationIntf, System.ImageList
  ;

const
  MAX_FORMS = 10;   //maximum forms a user can have open at once
  MIN_WIDTH = 210;  //min width and height of toolbar
  MIN_HEIGHT = 56;  //100 with toolbar, 56 without

type
  TToolBarFrm = class(THCIForm)
    ImageList1: TImageList;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Exit1: TMenuItem;
    hcCoreManager: ThcCorePlugInLoader;
    Window1: TMenuItem;
    mnuTools: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormResize(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
  private
    procedure CoreIsLoaded(Sender: TObject);
  public
  end;

var
  ToolBarFrm :TToolBarFrm;

  function UsingLargeFonts: boolean;

implementation

uses
  Registry
  ;

{$R *.DFM}

procedure TToolBarFrm.FormCreate(Sender: TObject);
var
  FormHeight: TConstraintSize;
begin
  Caption := Application.Title;
  RestorePosition;
  ClientHeight := 0;

  //adjust the height of the window to compensate for Large Fonts if necessary
  if UsingLargeFonts then
    FormHeight := Trunc(MIN_HEIGHT * 1.25)
  else
    FormHeight := MIN_HEIGHT;

  Constraints.MaxHeight := FormHeight;
  Constraints.MinHeight := FormHeight;
  Constraints.MaxWidth := Screen.Width;
  Constraints.MinWidth := MIN_WIDTH;

  hcCoreManager.OnAfterCoreLoaded := CoreIsLoaded;
  hcCoreManager.LoadProgressLabel := frmSplash.lblProgress;
  hcCoreManager.CorePlugin := ExtractFilePath(Application.ExeName) + 'ApplicationCore270.bpl';
  hcCoreManager.LoadCoreEngineAndPlugIns;
  Visible := True;
end;

procedure TToolBarFrm.CoreIsLoaded(Sender: TObject);
begin
  ApplicationServices.MenuManager.Menu := MainMenu1;
  ApplicationServices.FormManager.WindowMenu := Window1;
end;

procedure TToolBarFrm.FormDestroy(Sender: TObject);
begin
  SavePosition;
end;

procedure TToolBarFrm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
(*
  Author: Larry Hengen
  Date: 09/14/2000
  Purpose:  Don't allow the user to close the main application form if any of
    the application forms have an operation in progress.
*)
begin
  if assigned(ApplicationServices.FormManager) then
    CanClose := ApplicationServices.FormManager.CanCloseApp
  else
    CanClose := True;
end;

procedure TToolBarFrm.FormResize(Sender: TObject);
(*
  Author: Larry Hengen
  Date: 09/14/2000
  Purpose:  If we're maximizing the form then put it at the top of the screen
*)
begin
  if (Width = Constraints.MaxWidth) then
  begin
    Top := 0;
    Left := 0;
  end;
end;

function UsingLargeFonts: boolean;
var
  fontsize : integer;
  hdc : Thandle;
begin
  result := false;
  hdc := GetDc(HWND_DESKTOP);
  try
    fontsize := GetDeviceCaps(hdc,logpixelsx);
  finally
    ReleaseDc(HWND_DESKTOP,hdc);
  end;  // try/finally
  if fontsize = 96 then result := False
    else if fontsize = 120 then result := True;
end; { of GetLargeFonts }


procedure TToolBarFrm.Exit1Click(Sender: TObject);
begin
  Close;
end;

end.
