unit faPackageInfo;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, 
  Dialogs, StdCtrls, ComCtrls, CheckLst, ExtCtrls, hcPackageList, hcPackageInfo;

type
  TfraPackageInfo = class(TFrame)
    Panel1: TPanel;
    Splitter1: TSplitter;
    Panel5: TPanel;
    lstPackages: TCheckListBox;
    hdrPackages: THeaderControl;
    Panel4: TPanel;
    meProfile: TMemo;
    Panel6: TPanel;
    procedure FrameResize(Sender: TObject);
    procedure lstPackagesClick(Sender: TObject);
    procedure lstPackagesClickCheck(Sender: TObject);
  private
    FAllowUnloading: boolean;
    procedure SetAllowUnloading(Value :boolean);    
    procedure ShowPackageDetails(PackageInfo:ThcPackageInfo);
    procedure ScrollToTopofMemo(Memo:TCustomMemo);
  public
    procedure DisplayPackageInfo(Packages :ThcPackageCollection);
    property AllowPackageUnloading :boolean read FAllowUnloading write SetAllowUnloading;
  end;

implementation

{$R *.dfm}

uses
  hcApplicationIntf
  ;


procedure TfraPackageInfo.SetAllowUnloading(Value:boolean);
begin
  lstPackages.Enabled := Value;
end;

procedure TfraPackageInfo.DisplayPackageInfo(Packages :ThcPackageCollection);
var
  nIndex: Integer;
  I: Integer;
begin
  meProfile.Lines.Clear;
  lstPackages.Items.Clear;
  for I := 0 to Packages.Count - 1 do    // Iterate
  begin
    with Packages[I] do
    begin
      nIndex := lstPackages.Items.AddObject(Description,Packages[I]);
      lstPackages.Checked[nIndex] := LoadOption <> loDisabled;
    end;  // with
  end;    // for

  //show details for first package
  if Packages.Count > 0 then
  begin
    lstPackages.ItemIndex := 0;
    ShowPackageDetails(Packages[lstPackages.ItemIndex]);
  end;
end;

procedure TfraPackageInfo.ShowPackageDetails(PackageInfo :ThcPackageInfo);
begin
  with meProfile.Lines do
  begin
    Clear;
    Add(Format('File Name: %s'#13#10'Location: %s'#13#10'TimeStamp: %s'#13#10,[ExtractFileName(PackageInfo.FileName),ExtractFilePath(PackageInfo.FileName),DateTimeToStr(PackageInfo.CreationDate)]));
    Add(Format('Last Loaded: %s'#13#10,[DateTimeToStr(PackageInfo.LastLoaded)]));

    Add('Contains Units: ');
    Add('  '+StringReplace(PackageInfo.Units.Text,#13#10,#13#10'  ',[rfReplaceAll]));

    Add('Required Packages: ');
    Add('  '+StringReplace(PackageInfo.RequiredPackages.Text,#13#10,#13#10'  ',[rfReplaceAll]));
  end;  // with
  ScrollToTopofMemo(meProfile);
end;

procedure TfraPackageInfo.ScrollToTopofMemo(Memo :TCustomMemo);
begin
  //set cursor position to 0,0
  Memo.SelStart := SendMessage(Memo.Handle, EM_LINEINDEX, 0{Row}, 0) + 0{Col};
  // scroll caret into view,
  // the wParam, lParam parameters are ignored
  SendMessage(Memo.handle, EM_SCROLLCARET,0,0);
end;

procedure TfraPackageInfo.FrameResize(Sender: TObject);
begin
  hdrPackages.Sections[0].Width := lstPackages.Width;
end;

procedure TfraPackageInfo.lstPackagesClick(Sender: TObject);
begin
  ShowPackageDetails(ThcPackageInfo(lstPackages.Items.Objects[lstPackages.ItemIndex]));
end;

procedure TfraPackageInfo.lstPackagesClickCheck(Sender: TObject);
var
  PackageInfo: ThcPackageInfo;
begin
  //the current state of the current item
  PackageInfo := ThcPackageInfo(lstPackages.Items.Objects[lstPackages.ItemIndex]);
  if lstPackages.checked[lstPackages.itemindex] then
    ApplicationServices.Plugins.EnablePackage(PackageInfo.FileName)
  else
    ApplicationServices.Plugins.DisablePackage(PackageInfo.FileName);
end;


end.
