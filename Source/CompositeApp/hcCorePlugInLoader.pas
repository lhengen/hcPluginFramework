unit hcCorePlugInLoader;
{
  This unit declares ThcCorePlugInLoader, which is responsible for loading and
	unloading the CorePlugIn which in turn loads all user plug-ins.  By loading the
  CorePlugIn dynamically, the application knows nothing about the interfaces used
  by the TApplicationServices and TAbstractPlugIn objects.  We are free to evolve
  these interfaces without having to distribute the main EXE and can upgrade these
  packages without shutting down the application.
}

interface

uses
  Windows
  ,Classes
  ,SysUtils
  ,StdCtrls
  ;

type
  ThcCorePlugInLoader = class(TComponent)
  private
    FLabel: TLabel;
    FFileName: TFileName;
    FApplicationCoreHandle: HModule;
    FAfterCoreLoaded: TNotifyEvent;
    function GetIsLoaded: boolean;
    procedure DoAfterCoreLoaded;
  public
    procedure LoadCoreEngineAndPlugIns;
    procedure UnloadCoreEngineAndPlugIns;

  	property IsLoaded: boolean read GetIsLoaded;
  published
    property CorePlugin: TFileName read FFileName write FFileName;
    property LoadProgressLabel: TLabel read FLabel write FLabel;
    property OnAfterCoreLoaded: TNotifyEvent read FAfterCoreLoaded write FAfterCoreLoaded;
  end;

implementation

uses
  Dialogs
  ,hcApplicationIntf
  ,Forms
  ;

resourcestring
  sPluginNotFound = 'Plug-in "%s" not found.';
  sConfirmIndividualPlugInLoad = 'Confirm loading of individual plug-ins?';
	sInterfacePackageFailure = 'Interface Package Failure. Unable to access GlobalUserPlugIns.';
	sGlobalUserPlugInsNotAssigned = 'GlobalUserPlugIns is not assigned! Unable to unload custom packages.';
  sError = 'Error';
  sConfirm = 'Confirm';

procedure ThcCorePlugInLoader.DoAfterCoreLoaded;
begin
  if assigned(FAfterCoreLoaded) then
    FAfterCoreLoaded(Self);
end;

function ThcCorePlugInLoader.GetIsLoaded: boolean;
begin
	result := (FApplicationCoreHandle <> 0);
end;		{ GetIsLoaded }

procedure ThcCorePlugInLoader.LoadCoreEngineAndPlugIns;
var
  withConfirmation: boolean;
begin

  withConfirmation := False;

  if GetKeyState(VK_SHIFT) and $80 = $80 then   // Shift key is down.... Confirm loading of individual plug-ins?
   	withConfirmation := (Application.MessageBox(PChar(sConfirmIndividualPlugInLoad), PChar(sConfirm), MB_YESNO + MB_ICONQUESTION) = IDYES);

  // Load the Application Core (that implements all the functionality of ApplicationIntf.pas):
  if FApplicationCoreHandle <> 0 then
    ShowMessage('ApplicationCore already loaded.')
  else if FFileName = '' then
  begin
    MessageDlg('FileName of Application Core Package is Missing',mtError,[mbOk],0);
  end
  else
    begin
      {$ifdef MarkPackageLoading}
      ShowMessage('About to load ' + FFileName);
      try
      {$endif}  // MarkPackageLoading

        try
          FApplicationCoreHandle := LoadPackage(FFileName);
          DoAfterCoreLoaded;
        except
        	on e: Exception do
        		Application.HandleException(nil);
        end;  { try/except }

      {$ifdef MarkPackageLoading}
      finally
	      ShowMessage('Finished loading ' + FFileName);
      end;
      {$endif}  // MarkPackageLoading
    end;

  if not assigned(ApplicationServices) then
  	begin
    	Application.MessageBox(PChar(sInterfacePackageFailure), PChar(sError), MB_OK + MB_ICONERROR);
      exit;
    end
  else		// GlobalUserPlugIns is assigned!
  begin
    ApplicationServices.Plugins.LoadAllPackages(withConfirmation,FLabel);
  end;
end;		{ LoadCoreEngineAndPlugIns }

procedure ThcCorePlugInLoader.UnloadCoreEngineAndPlugIns;
begin
	if FApplicationCoreHandle = 0 then
    ShowMessage('ApplicationCore is already unloaded.')
  else
    begin
      UnloadPackage(FApplicationCoreHandle);
      FApplicationCoreHandle := 0;
    end;

  if assigned(ApplicationServices) then
    ApplicationServices.Plugins.UnLoadAllPackages
  else
    Application.MessageBox(PChar(sGlobalUserPlugInsNotAssigned), PChar(sError), MB_OK + MB_ICONERROR);
end;		{ UnloadCoreEngineAndPlugIns }


end.
