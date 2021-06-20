unit fmStdForm;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Registry;

type
  THCIForm = class(TForm)
    // forms which "know" how to save & restore their position but don't necessarily do so
  protected
    procedure SavePosition; virtual;
    procedure RestorePosition; virtual;
  end;

  // standard client form which notifies the MainForm on it's activation & closure
  // DO NOT implement an OnClose handler within the PlugIn - use the OnClosure/OnActivation events
  TStdFormClass = class of TfrmStandard;

  TfrmStandard = class(THCIForm)
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormActivate(Sender: TObject);
  private
    FFormManager: TObject;
    FGUID: string;
    FActivation: TNotifyEvent;
    FCloseNotify: TNotifyEvent;
  protected
    procedure DoCloseNotify;
    procedure DoActivation;
  public
    property GUID: string read FGUID write FGUID;
    property FormManager: TObject read FFormManager write FFormManager;
  published
    property OnClosure: TNotifyEvent read FCloseNotify write FCloseNotify;
    property OnActivation: TNotifyEvent read FActivation write FActivation;
  end;

implementation

{$R *.DFM}

uses hcApplicationIntf, hcApplicationConsts;

procedure THCIForm.RestorePosition;
(*
  Purpose:  Restore the window position from the registry.
*)
var
  Registry: TRegistry;
begin
  try
    Registry := TRegistry.Create;
    try
      with Registry do
      begin
        OpenKey(REG_ApplicationRegistryPath + '\' + Self.ClassName, True);

        // check if position was previously saved
        if Registry.ValueExists('Top') then
        begin
          Self.Top := ReadInteger('Top');
          Self.Left := ReadInteger('Left');
          Self.Height := ReadInteger('Height');
          Self.Width := ReadInteger('Width');
        end;
        CloseKey;
      end; // with
    finally
      Registry.Free;
    end;
  except
    ; // do nothing if the entries were not found in the registry
  end; // try/except
end;

procedure THCIForm.SavePosition;
(*
  Purpose:  Save the window position and State to the registry.
*)
var
  Registry: TRegistry;
begin
  Registry := TRegistry.Create;
  try
    Registry.OpenKey(REG_ApplicationRegistryPath + '\' + Self.ClassName, True);
    Registry.WriteInteger('Top', Self.Top);
    Registry.WriteInteger('Left', Self.Left);
    Registry.WriteInteger('Height', Self.Height);
    Registry.WriteInteger('Width', Self.Width);
    Registry.CloseKey;
  finally
    Registry.Free;
  end;
end;

procedure TfrmStandard.DoActivation;
begin
  if assigned(FActivation) then
    FActivation(Self);
end;

procedure TfrmStandard.DoCloseNotify;
begin
  if assigned(FCloseNotify) then
    FCloseNotify(Self);
end;

procedure TfrmStandard.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caNone;
  // The form manager removes all references to the form and then frees it
  assert(FormManager <> nil, 'FormManager has not been assigned!');
  DoCloseNotify;
  // notify anyone interested that the form is closing and will be destroyed
  TAbstractFormManager(FormManager).RemoveForm(Self);
end;

procedure TfrmStandard.FormActivate(Sender: TObject);
begin
  assert(FormManager <> nil, 'FormManager has not been assigned!');
  TAbstractFormManager(FormManager).ActivateForm(Self);
  DoActivation;
end;

end.
