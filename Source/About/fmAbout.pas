unit fmAbout;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, StdCtrls, ComCtrls, ImgList, hcVersionInfo, jpeg,
  CheckLst, hcPackageInfo, faPackageInfo, System.ImageList, Vcl.Imaging.pngimage;

type
  TfrmAbout = class(TForm)
    pgPlugIns: TPageControl;
    tbPlugIns: TTabSheet;
    tbPackages: TTabSheet;
    tvPlugIns: TTreeView;
    imlPlugIns: TImageList;
    Panel2: TPanel;
    pnlLogo: TImage;
    edCredits: TMemo;
    btOK: TButton;
    tbSystemPackages: TTabSheet;
    fraSystemPackageInfo: TfraPackageInfo;
    Panel1: TPanel;
    btRefresh: TButton;
    btAdd: TButton;
    btRemove: TButton;
    pnlFrameContainer: TPanel;
    fraUserPackageInfo: TfraPackageInfo;
    procedure btAddClick(Sender: TObject);
    procedure pgPlugInsChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btRemoveClick(Sender: TObject);
    procedure btRefreshClick(Sender: TObject);
    procedure lstPackagesClick(Sender: TObject);
    procedure fraUserPackageInfolstPackagesClickCheck(Sender: TObject);
    procedure btOKClick(Sender: TObject);
    procedure fraSystemPackageInfolstPackagesClick(Sender: TObject);
  private
    procedure UpdateButtons;
    procedure DisplayCurrentPage;
    procedure DisplayPlugIns;
  public
    class function Execute :boolean;
  end;

implementation

{$R *.DFM}

uses
	hcApplicationIntf
  ,ActnList
  ;


procedure TfrmAbout.UpdateButtons;
begin
  btRefresh.Enabled := True;
  btAdd.Enabled := True;
  btRemove.Enabled := (fraUserPackageInfo.lstPackages.Count > 0);
end;

class function TfrmAbout.Execute:boolean;
var
  dlg: TfrmAbout;
begin
  dlg := TfrmAbout.Create(nil);
  try
    Result := dlg.ShowModal = mrOk;
  finally
  	dlg.Free;
  end;  // try/finally
end;

procedure TfrmAbout.btAddClick(Sender: TObject);
var
  dlgOpen: TOpenDialog;
begin
  dlgOpen := TOpenDialog.Create(nil);
  try
    dlgOpen.InitialDir := ExtractFilePath(Application.EXEName);
    dlgOpen.Filter := 'Borland Package Library (*.bpl)|*.BPL';
    dlgOpen.Title := 'Select Package to Load';
    if dlgOpen.Execute then
    begin
      ApplicationServices.Plugins.AddPackage(dlgOpen.FileName);
      fraUserPackageInfo.DisplayPackageInfo(ApplicationServices.Plugins.UserPackages);
    end;
  finally // wrap up
    dlgOpen.Free;
  end;    // try/finally
end;

procedure TfrmAbout.pgPlugInsChange(Sender: TObject);
begin
  DisplayCurrentPage;
end;

procedure TfrmAbout.FormShow(Sender: TObject);
begin
  //force initial display of information for current tab
  pgPlugIns.ActivePage := tbPlugIns;
  pgPlugInsChange(Self);
  fraSystemPackageInfo.AllowPackageUnloading := False;
  fraUserPackageInfo.AllowPackageUnloading := True;

  Caption := 'About '+Application.Title;
  edCredits.Lines.Text := StringReplace(edCredits.Lines.Text,'%1',hcVersionInfo.GetFileVersionText,[rfReplaceAll]);
  UpdateButtons;
end;

procedure TfrmAbout.btRemoveClick(Sender: TObject);
begin
  ApplicationServices.PlugIns.RemovePackage(ThcPackageInfo(fraUserPackageInfo.lstPackages.Items.Objects[fraUserPackageInfo.lstPackages.ItemIndex]).FileName);
  fraUserPackageInfo.DisplayPackageInfo(ApplicationServices.Plugins.UserPackages);
end;

procedure TfrmAbout.DisplayPlugIns;
var
  PlugInForms,
  PlugInActions: TStringList;
  GUID: string;
  ChildNode: TTreeNode;
  J: Integer;
  Node: TTreeNode;
  I: Integer;
begin
  //show list of all current packages loaded
  with ApplicationServices.Plugins do
  begin
    tvPlugIns.Items.BeginUpdate;
    try
      tvPlugIns.Items.Clear;
      for I := 0 to Count - 1 do    // Iterate over all plugins
      begin
        Node := tvPlugIns.Items.AddChild(nil,Items[I].Name);
        Node.Data := Items[I];
        Node.ImageIndex := 1;
        Node.SelectedIndex := 1;
        GUID := Items[I].GUID;

        //display plugin actions
        PlugInActions := ApplicationServices.MenuManager.GetPluginActionInfo(ApplicationServices.Plugins[I]);
        try
          //add any registered Actions as child nodes
          for J := 0 to PlugInActions.Count - 1 do    // Iterate
          begin
            ChildNode := tvPlugIns.Items.AddChild(Node,StringReplace(PlugInActions[J],'&','',[rfReplaceAll]));
            ChildNode.OverlayIndex := -1;
            ChildNode.StateIndex  := -1;  //don't draw any state image
            ChildNode.ImageIndex := 2;
            ChildNode.SelectedIndex := ChildNode.ImageIndex;
          end;    // for
        finally // wrap up
          PlugInActions.Free;
        end;    // try/finally

        //display plugin forms
        PlugInForms := ApplicationServices.FormManager.GetPlugInFormInfo(ApplicationServices.Plugins[I]);
        try
          for J := 0 to PlugInForms.Count - 1 do    // Iterate
          begin
            ChildNode := tvPlugIns.Items.AddChild(Node,StringReplace(PlugInForms[J],'&','',[rfReplaceAll]));
            ChildNode.OverlayIndex := -1;
            ChildNode.StateIndex  := -1;  //don't draw any state image
            ChildNode.ImageIndex := 3;
            ChildNode.SelectedIndex := ChildNode.ImageIndex;
          end;    // for
        finally // wrap up
          PlugInForms.Free;
        end;    // try/finally


      end;    // for
    finally
    	tvPlugIns.Items.EndUpdate;
    end;  // try/finally
  end;  // with
end;

procedure TfrmAbout.btRefreshClick(Sender: TObject);
begin
  DisplayCurrentPage;
end;

procedure TfrmAbout.DisplayCurrentPage;
begin
  if pgPlugIns.ActivePage = tbPackages then
    fraUserPackageInfo.DisplayPackageInfo(ApplicationServices.Plugins.UserPackages)
  else
  if pgPlugIns.ActivePage = tbPlugIns then
    DisplayPlugIns
  else
  if pgPlugIns.ActivePage = tbSystemPackages then
    fraSystemPackageInfo.DisplayPackageInfo(ApplicationServices.Plugins.SystemPackages);
end;

procedure TfrmAbout.lstPackagesClick(Sender: TObject);
begin
  UpdateButtons;
  fraUserPackageInfo.lstPackagesClick(Sender);
end;

procedure TfrmAbout.fraUserPackageInfolstPackagesClickCheck(
  Sender: TObject);
begin
  fraUserPackageInfo.lstPackagesClickCheck(Sender);
end;

procedure TfrmAbout.btOKClick(Sender: TObject);
begin
  ApplicationServices.SavePlugInLists;
end;

procedure TfrmAbout.fraSystemPackageInfolstPackagesClick(Sender: TObject);
begin
  fraSystemPackageInfo.lstPackagesClick(Sender);
end;

end.
