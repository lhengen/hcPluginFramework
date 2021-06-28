unit hcApplicationIntf;
{
  This unit declares two abstract classes. Your
  plug-ins descend from TAbstractPlugIn. Plug-ins
  are registered and unregistered using the global
  variable ApplicationServices, which is a descendant
  of the abstract class TAbstractApplicationServices
  (this descendant is placed in the application's
  core engine).
}

interface

uses
  StdActns
  ,ActnList
	,Classes
	,Forms
  ,Menus
  ,fmStdForm
  ,contnrs
  ,SysUtils
  ,hcPackageList
  ,StdCtrls
  ,hcCompositeAppTypes
  ;

resourcestring
  sLoading = 'Loading %s...';
  sPackageAlreadyLoaded = 'Package "%s" is already loaded.';
  sPackageAlreadyUnloaded = 'Package "%s" is not currently loaded. Unable to unload.';
  sLoadPackage = 'Load package "%s"?';
  sConfirm = 'Confirm';
  sWarning = 'Warning';
  sError = 'Error';

const
  REG_DisabledPackages = 'Disabled Packages';
  REG_UserPackages = 'Known Packages';
  REG_SystemPackages = 'System Packages';
  REG_GlobalSettings = 'GlobalSettings';
  REG_DynamicPackages = 'Dynamic Packages';

	ufAllUnits = ufMainUnit or ufPackageUnit or ufWeakUnit or ufOrgWeakUnit or ufImplicitUnit;

type
  TAbstractPlugIn = class;
  TAbstractPlugInClass = class of TAbstractPlugIn;

  {
    The Application core and any gui form that manipulate the packages or plugins
    loaded, uses this list.  The list contains plugin objects as well as lists of known,
    disabled and dynamically loaded packages.  Known - Disabled + Dynamic = list of
    packages actually loaded.

    When a package is unloaded it's finalization section is called.  Finalization should
    contain code to destroy all plugins created in the package.  The plugin destructor
    automatically calls ApplicationServices methods to unregister itself and any registered
    actions etc.  Therefore, the package need not know what plugins it contains and
    the plugin need not know what package it resides within.
  }
  ThcApplicationPlugInList = class(TList)
  private
    FDynamicallyLoadedPackages: ThcPackageCollection;
    FUserPackages: ThcPackageCollection;
    FSystemPackages: ThcPackageCollection;
	protected
    function Get(Index: Integer): TAbstractPlugin;
    procedure Put(Index: Integer; PlugIn: TAbstractPlugin);
    procedure UnloadPackages(Collection: ThcPackageCollection);
    procedure LoadPackages(Collection :ThcPackageCollection; withConfirm: Boolean; displayLabel: TLabel);
    function LoadPackage(const PackageFileName: string; Permanent, ShowErrorMessages: Boolean): Boolean;
    function UnLoadPackage(const PackageFileName: string; Permanent, ShowErrorMessages: Boolean): boolean;
	public
    //package related methods
    procedure LoadAllPackages(withConfirm: boolean; displayLabel: TLabel);
    procedure DisablePackage(const PackageFileName:string);
    procedure EnablePackage(const PackageFileName:string);
    procedure AddPackage(const PackageFileName:string);
    function PackageAlreadyLoaded(PackageFileName: string): boolean;
    // function PackageDisabled(PackageFileName: string): boolean;
    procedure RemovePackage(const PackageFileName: string);
    procedure UnLoadAllPackages;

    //plugin related methods
  	constructor Create;
		destructor Destroy; override;
		function IndexOf(const PlugInName: string): integer;
    property Items[ndx: Integer]: TAbstractPlugin read Get write Put; default;

    property SystemPackages: ThcPackageCollection read FSystemPackages;  //System packages cannot be disabled by the user and appear in the Known packages list
    property DynamicallyLoadedPackages: ThcPackageCollection read FDynamicallyLoadedPackages;
    property UserPackages: ThcPackageCollection read FUserPackages;
  end;


  {
    Form Manager

    Most actions registered will invoke user dialogs and forms.  These forms instances will have to be managed
    so when the plugin is unloaded all form instances can be destroyed.  Any UI element may be added to existing
    forms or dialogs such as tabs appearing in existing dialogs like the Preferences dialog typically found
    in applications.  These elements are edge cases and have to be manually handled by the plugin developer.  The form
    manager automates instance tracking, window menuing and destruction of complete forms or dialogs.
  }
  TAbstractFormManager = class(TComponent)
  private
    FWindowMenu: TMenuItem;
    function GetWindowMenu:TMenuItem;
  public
    function CanCloseApp :boolean; virtual; abstract;
    function GetPlugInFormInfo(APlugin :TAbstractPlugIn) :TStringList; virtual; abstract;
    procedure ActivateForm(FormInstance :TfrmStandard); virtual; abstract;
    procedure RemoveForm(FormInstance :TfrmStandard); virtual; abstract;
    procedure RemovePlugInForms(APlugin :TAbstractPlugIn); virtual; abstract;
    procedure RegisterFormAction(aPlugIn :TAbstractPlugIn; FormClass :TStdFormClass; Action :TCustomAction; InstanceSpecifier :ThcInstanceSpecifier);  virtual; abstract;
    procedure RegisterFormInstance(aPlugIn :TAbstractPlugIn; FormInstance :TfrmStandard); virtual; abstract;
    property WindowMenu :TMenuItem read GetWindowMenu write FWindowMenu;
  end;

  {
    Menu Manager that supports only TAction and descendants.

    The string is the pluginIdentifier (GUID) used to identify all menu items registered by the
    plugin so they can be destroyed when the plug is unloaded.

    The Menu Manager must deal with the random load order of packages.  Each package will request menu items to be created
    based on existing ones.  For example, a basic application will always have a File menu even if it only has a single subitem
    (Close or Exit).  Packages will typically look for the File item when placing their menu actions.  Unless package load order can
    be dictated, and maintained for at least System type packages (packages included in the core of an application) then it is impossible
    to gurantee the consistent placement of menu items.  This is further complicated by the ability to dynamically unload or disable packages
    even when they are currently loaded.
  }
  TAbstractMenuManager = class(TComponent)
  private
  protected
    FRegisteredActions :TStringList;
    FMenu: TMainMenu;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    procedure AddAction(const PlugIn: TAbstractPlugIn; const Action: TCustomAction; const TargetItemCaption: string;
      const AddAfterTargetItem:boolean = True; const AddAsSubMenuItem:boolean = false; const Anchored :boolean = False); virtual; abstract;
    procedure RemovePlugInActions(PlugIn :TAbstractPlugIn); virtual; abstract;
    function GetPluginActionInfo(PlugIn :TAbstractPlugIn) :TStringList; virtual; abstract;
    property Menu: TMainMenu read FMenu write FMenu;
  end;

	TAbstractApplicationServices = class(TComponent)
  protected
    FFormManager: TAbstractFormManager;
    FMenuManager: TAbstractMenuManager;
    FPlugIns :ThcApplicationPlugInList;
    function GetMenuManager :TAbstractMenuManager; virtual; abstract;  //override to provide a different concrete implementation
    function GetPlugInList :ThcApplicationPlugInList;
  public
    procedure SavePlugInLists; virtual; abstract;  {method used to Save User and System Package Info from storage}
    procedure LoadPlugInLists; virtual; abstract;  {method used to Load User and System Package Info from storage}
    procedure RegisterPlugIn(APlugIn: TAbstractPlugIn); virtual; abstract;
    { Call RegisterPlugIn from your main plug-in unit passing a newly-created instance of your plug-in.

      For example:

        initialization
          myPlugIn := TMyPlugIn.Create;
          ApplicationServices.RegisterPlugIn(myPlugIn);

        finalization
          myPlugIn.Free;
    }
    procedure UnregisterPlugIn(APlugIn: TAbstractPlugIn); virtual; abstract;
    { Unregisters  }
    procedure RegisterFormAction(APlugIn: TAbstractPlugIn; FormClass :TStdFormClass; InstanceSpecifier :ThcInstanceSpecifier; Action :TCustomAction; TargetItemCaption :string; AddAfterTargetItem :boolean = True; AddAsSubMenuItem :boolean = false); virtual; abstract;

    function GetPlugIn(const plugInName: string): TAbstractPlugIn; virtual; abstract;
		{ Returns a reference to the plug-in specified by plugInName. }

    property FormManager :TAbstractFormManager read FFormManager write FFormManager;
    property MenuManager :TAbstractMenuManager read GetMenuManager write FMenuManager;
  published
    property Plugins: ThcApplicationPlugInList read GetPlugInList;
  end;		{ TAbstractApplicationServices }


  TAbstractPlugIn = class(TObject)
  public
    // property RegisteredActions :ThcActionList read FRegisteredActions; {exposed so ApplicationServices can use this information to insert actions }
    {removes objects registered with ApplicationServices }


    constructor Create; virtual;
    destructor Destroy; override;
    function Name: string; virtual; abstract;   { Override required }
    { Descendant classes must override and return the name of your plug-in.
      This must be a legal pascal identifier, without spaces and without
      punctuation. }

    function GUID :string; virtual; abstract;
    {
      Descendant classes must return a GUID which is used to uniquely identify
      plugins which may have the same name.  This forms the key used to track
      all items registered with ApplicationServices so they can be destroyed when
      the plugin is unloaded.
    }

    function Description: string; virtual;
    { This method may be called by the application to display a short
      description of your plug-in to the user. It is recommended that you
      override this method, but not required. }

    procedure AllPlugInsAreLoaded; virtual;
    { This method is called after all plug-ins have been loaded and
      initialized. }

  end;

var
  ApplicationServices: TAbstractApplicationServices = nil;

procedure PackageIsLoadingProc(const Name: string; NameType: TNameType; Flags: Byte; Param: Pointer);

implementation

uses
  Dialogs
  {$ifdef hcCodeSite}
  ,CodeSiteLogging
  {$endif}  // DEBUG
  ,hcPackageInfo
  ,Windows
  ,Controls
  ;


function TAbstractFormManager.GetWindowMenu:TMenuItem;
begin
  assert(assigned(FWindowMenu),'ThcFormManager.GetWindowMenu - WindowMenu has nto been assigned!');
  Result := FWindowMenu;
end;

procedure PackageIsLoadingProc(const Name: string; NameType: TNameType; Flags: Byte; Param: Pointer);
{
  This routine is called by GetPackageInfo() while a package is being loaded.  It was used to call
  the Register method in the package, but there is no need when the Initialization section can be used
  instead.  We may need to adapt this routine to capture the PackageInfo so we can display it.
}
var
  PackageInfo :ThcPackageInfo;
begin
//	Flags:
//  ufMainUnit = $01;
//  ufPackageUnit = $02;
//  ufWeakUnit = $04;
//  ufOrgWeakUnit = $08;
//  ufImplicitUnit = $10;
//  ufWeakPackageUnit = ufPackageUnit or ufWeakUnit;

  PackageInfo := ThcPackageInfo(Param);
  case NameType of    //
    ntContainsUnit: PackageInfo.Units.Add(Name);
    ntRequiresPackage:  PackageInfo.RequiredPackages.Add(Name);
    ntDcpBpiName: PackageInfo.PackageName := Name;
  end;    // case
end;


function TAbstractApplicationServices.GetPlugInList:ThcApplicationPlugInList;
begin
  if not assigned(FPlugins) then
  begin
    FPlugins := ThcApplicationPlugInList.Create;
    LoadPlugInLists;
  end;
  Result := FPlugins;
end;

constructor TAbstractPlugIn.Create;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod('TAbstractPlugIn.Create');
  {$endif}  // hcCodeSite
  inherited Create;
  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('TAbstractPlugIn.Create');
  {$endif}  // hcCodeSite
end;

procedure TAbstractPlugIn.AllPlugInsAreLoaded;
begin
	// Do nothing. Descendants may override.
end;		{ AllPlugInsAreLoaded }

destructor TAbstractPlugin.Destroy;
{
  This method is redundant under normal circumstances.  The PlugIn should only need
  to register itself and then the PluginManager will UnRegister all plugins contained
  in a package when it unloads the package.
}
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod(Format('TAbstractPlugIn.Destroy %s',[Self.Name]));
  {$endif}  // hcCodeSite
  if assigned(ApplicationServices) then
    ApplicationServices.UnregisterPlugIn(Self);
  // FRegisteredActions.Free;
  inherited Destroy;
  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('TAbstractPlugIn.Destroy');
  {$endif}  // hcCodeSite
end;    { Destroy }

function TAbstractPlugIn.Description: string;
{
  Returns the Description entered in the Project Options for the package.  If multiple
  PlugIns reside in the same package, this method must be overridden to provide a
  unique description for each plugin.
}
begin
	result := '';
	// Descendants may override.
end;		{ Description }


function ThcApplicationPlugInList.Get(Index: Integer): TAbstractPlugin;
begin
	result := TAbstractPlugin(inherited Get(Index));
end;

constructor ThcApplicationPlugInList.Create;
{
}
begin
  inherited Create;
  FUserPackages := ThcPackageCollection.Create(ApplicationServices);
  FSystemPackages := ThcPackageCollection.Create(ApplicationServices);
  FDynamicallyLoadedPackages := ThcPackageCollection.Create(ApplicationServices);
end;

procedure ThcApplicationPlugInList.Put(Index: Integer; PlugIn: TAbstractPlugin);
begin
	inherited Put(Index, PlugIn);
end;

destructor ThcApplicationPlugInList.Destroy;
var
	j: integer;
begin
	for j := 0 to Count - 1 do		{ Free all PlugIns in the list, SB None after packages are unloaded }
  	Items[j].Free;

  FreeAndNil(FUserPackages);
  FreeAndNil(FDynamicallyLoadedPackages);
	inherited Destroy;
end;

function ThcApplicationPlugInList.IndexOf(const PlugInName: string): integer;
var
	j: integer;
begin
	for j := 0 to Count - 1 do		{ Iterate through interfaces, look for one with a name that matches parameter PlugInName. }
		if CompareText(Items[j].Name, PlugInName) = 0 then
			begin
				result := j;
				exit;
			end;
	result := -1;
end;

procedure ThcApplicationPlugInList.EnablePackage(const PackageFileName :string);
var
  nIndex: Integer;
begin
  nIndex := UserPackages.IndexOf(PackageFileName);
  if nIndex >= 0 then
    UserPackages[nIndex].LoadOption := loOnStartup;

  LoadPackage(PackageFileName,True,True)
end;

procedure ThcApplicationPlugInList.DisablePackage(const PackageFileName :string);
var
  nIndex: Integer;
begin
  nIndex := UserPackages.IndexOf(PackageFileName);
  if nIndex >= 0 then
    UserPackages[nIndex].LoadOption := loDisabled;

  UnLoadPackage(PackageFileName,True,True);
end;

procedure ThcApplicationPlugInList.AddPackage(const PackageFileName :string);
begin
  UserPackages.Add.FileName := PackageFileName;
  LoadPackage(PackageFileName,True,False);
end;

function ThcApplicationPlugInList.LoadPackage(const PackageFileName: string; permanent, showErrorMessages: boolean): boolean;
{
  Loads the package
}
var
  saveCursor: TCursor;
  PackageInfo: ThcPackageInfo;
  localKnownPackageIndex: Integer;
  Flags: integer;
  localModuleHandle: HModule;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod('ThcApplicationPlugInList.LoadPackage');
  {$endif}  // hcCodeSite

	saveCursor := Screen.Cursor;
	Screen.Cursor := crHourGlass;
	try
    result := False;
    { Step 1. Check to see if package is already loaded. If it is, exit (and if showErrorMessages is true, alert user): }
    if PackageAlreadyLoaded(PackageFileName) then
    begin
      if showErrorMessages then
        MessageDlg(Format(sPackageAlreadyLoaded, [PackageFileName]),mtWarning,[mbOk],0);
      exit;
    end;

    localKnownPackageIndex := UserPackages.IndexOf(PackageFileName);

    { Step 2. Load package: }
    try
      localModuleHandle := SysUtils.LoadPackage(PackageFileName);

      if localKnownPackageIndex >= 0 then
      begin
        // We already have this package in our known packages list
        PackageInfo := UserPackages.Items[localKnownPackageIndex];
        { GetPackageInfo accesses the given package's info table and enumerates
          all the contained units and required packages }
        Flags := ufAllUnits;
        GetPackageInfo(localModuleHandle, Pointer(PackageInfo), Flags, PackageIsLoadingProc);
        //update HModule (stored in Objects array which is accessed through HModules property) accordingly
        PackageInfo.ModuleHandle := localModuleHandle;
      end
      else    // Add to FDynamicallyLoadedPackages list:
      begin
        PackageInfo := FDynamicallyLoadedPackages.Add;
        PackageInfo.FileName := PackageFileName;
        { GetPackageInfo accesses the given package's info table and enumerates
          all the contained units and required packages }
        Flags := ufAllUnits;
        GetPackageInfo(localModuleHandle, Pointer(PackageInfo), Flags, PackageIsLoadingProc);
        PackageInfo.ModuleHandle := localModuleHandle;
        { If permanent, AND not already present, add to UserPackages}
        if permanent then
        begin
          UserPackages.Add.Assign(PackageInfo);
        end;
      end;
      PackageInfo.LastLoaded := Now;
    except
      on e: Exception do
        MessageDlg(e.Message,mtError,[mbOk],0);
    end;  { try/except }

    result := True;
	finally
		Screen.Cursor := saveCursor;
	end;  // try/finally
  {$ifdef hcCodeSite}
  hcCodeSite.ExitMethod('ThcApplicationPlugInList.LoadPackage');
  {$endif}  // hcCodeSite
end;

function ThcApplicationPlugInList.UnLoadPackage(const PackageFileName: string; permanent, showErrorMessages: boolean): boolean;
var
  saveCursor: TCursor;
  localNdx: integer;
  matchingPackageList: ThcPackageCollection;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod('ThcApplicationPlugInList.UnLoadPackage');
  {$endif}  // hcCodeSite

	saveCursor := Screen.Cursor;
	Screen.Cursor := crHourGlass;
	try
    result := False;
    matchingPackageList := nil;

    { Step 1: Match the package name with the HModule (either be inside UserPackages or DynamicallyLoadedPackages). }
    localNdx := UserPackages.IndexOf(PackageFileName);
    if localNdx >= 0 then
      matchingPackageList := UserPackages;

    if localNdx = -1 then
    begin
      localNdx := DynamicallyLoadedPackages.IndexOf(PackageFileName);
      if localNdx >= 0 then
        matchingPackageList := DynamicallyLoadedPackages;
    end;

    if (not assigned(matchingPackageList)) or (localNdx = -1) or (matchingPackageList.Items[localNdx].ModuleHandle = 0) then   // Package not loaded.
    begin
      OutputDebugString(PChar(Format(sPackageAlreadyUnloaded, [PackageFileName])));
      if showErrorMessages then
        Application.MessageBox(PChar(Format(sPackageAlreadyUnloaded, [PackageFileName])), PChar(sWarning), MB_OK + MB_ICONWARNING);
      exit;
    end;

    { Step 2. Unload the package using HModule }
    SysUtils.UnloadPackage(matchingPackageList.Items[localNdx].ModuleHandle);
    matchingPackageList.Items[localNdx].ModuleHandle := 0;

    { Step 3. If Permanent, add PackageFileName to the disabled packages list: }
    if permanent then
    begin
      matchingPackageList.Items[localNdx].LoadOption := loDisabled;

      { Step 4. If Permanent and in DynamicallyLoadedPackages, Remove package name }
      if matchingPackageList = DynamicallyLoadedPackages then
        DynamicallyLoadedPackages.Delete(localNdx);
    end;
	finally
		Screen.Cursor := saveCursor;
	end;  // try/finally
  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('ThcApplicationPlugInList.UnLoadPackage');
  {$endif}  // hcCodeSite
end;

function ThcApplicationPlugInList.PackageAlreadyLoaded(PackageFileName: string): boolean;
begin
  result := False;
  if assigned(UserPackages) then
    result := UserPackages.PackageInList(PackageFileName, True{checkLoaded});

  if not result then
    if assigned(DynamicallyLoadedPackages) then
      result := DynamicallyLoadedPackages.PackageInList(PackageFileName, True{checkLoaded});
end;

procedure ThcApplicationPlugInList.LoadAllPackages(withConfirm: boolean; displayLabel: TLabel);
begin
  LoadPackages(FSystemPackages,withConfirm, displayLabel);
  LoadPackages(FUserPackages,withConfirm, displayLabel);
end;

procedure ThcApplicationPlugInList.LoadPackages(Collection :ThcPackageCollection; withConfirm: boolean; displayLabel: TLabel);
{
  Routine to load all System packages, followed by all User Packages that are not currently disabled.
}

var
  saveCursor: TCursor;
	Flags: Integer;
  j: integer;
  localModuleHandle: HModule;
  localModuleName: string;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod('ThcApplicationPlugInList.LoadPackages');
  {$endif}  // hcCodeSite

  saveCursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    for j := 0 to Collection.Count - 1 do    { Iterate through known packages... }
      if not (Collection[j].LoadOption = loDisabled) then
      begin
        localModuleHandle := Collection[j].ModuleHandle;
        localModuleName := Collection[j].FileName;

        if localModuleHandle <> 0 then
          ShowMessage(localModuleName + ' already loaded.')
        else    // Loading for the first time...
          begin
            if assigned(displayLabel) then
            begin
              displayLabel.Caption := Format(sLoading, [ExtractFileName(localModuleName)]);
              displayLabel.Repaint;
            end;

            if withConfirm then
              if Application.MessageBox(PChar(Format(sLoadPackage, [localModuleName])), PChar(sConfirm), MB_YESNO + MB_ICONQUESTION) <> IDYES then
                continue;

            try
              localModuleHandle := SysUtils.LoadPackage(localModuleName);
              { GetPackageInfo accesses the given package's info table and enumerates
                all the contained units and required packages }
              Flags := ufAllUnits;
              GetPackageInfo(localModuleHandle, Pointer(Collection[j]), Flags, PackageIsLoadingProc);
              Collection[j].ModuleHandle := localModuleHandle;
              Collection[j].LastLoaded := Now;
            except
              on e: Exception do
                Application.MessageBox(PChar(e.Message), PChar(sError), MB_OK + MB_ICONWARNING);
            end;  { try/except }

            if assigned(displayLabel) then
            begin
              displayLabel.Caption := '';
              displayLabel.Repaint;
            end;
          end;
      end
      else    // Disabled package....
      begin
      end;
  finally
  	Screen.Cursor := saveCursor;
  end;  // try/finally
  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('ThcApplicationPlugInList.LoadPackages');
  {$endif}  // hcCodeSite
end;

procedure ThcApplicationPlugInList.UnloadPackages(Collection: ThcPackageCollection);
var
  saveCursor: TCursor;
  j: integer;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod('ThcApplicationPlugInList.UnloadPackages');
  {$endif}  // hcCodeSite

  saveCursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    if not assigned(Collection) then
      exit;
    for j := 0 to Collection.Count - 1 do    { Iterate through known packages... }
    begin
      if Collection.Items[j].ModuleHandle = 0 then           // Package never loaded or already unloaded.
      begin
      end
      else            // This package is loaded, so let's unload it...
      begin
        SysUtils.UnloadPackage(Collection.Items[j].ModuleHandle);
        Collection.Items[j].ModuleHandle := 0;
      end;
    end;
  finally
  	Screen.Cursor := saveCursor;
  end;  // try/finally
  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('ThcApplicationPlugInList.UnloadPackages');
  {$endif}  // hcCodeSite
end;

procedure ThcApplicationPlugInList.UnLoadAllPackages;
begin
  UnloadPackages(FUserPackages);
  UnloadPackages(FSystemPackages);
  UnloadPackages(FDynamicallyLoadedPackages);
end;

procedure ThcApplicationPlugInList.RemovePackage(const PackageFileName: string);
var
  nIndex: Integer;
  PackageInfo :ThcPackageInfo;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod('ThcApplicationPlugInList.RemovePackage');
  {$endif}  // hcCodeSite

  nIndex := UserPackages.IndexOf(PackageFileName);
  if nIndex >= 0 then
  begin
    PackageInfo := UserPackages[nIndex];
    UnLoadPackage(PackageInfo.FileName, True{permanent}, True{showErrorMessages});
    DynamicallyLoadedPackages.RemovePackage(PackageInfo.FileName);
    UserPackages.Delete(nIndex);
  end;

  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('ThcApplicationPlugInList.RemovePackage');
  {$endif}  // hcCodeSite
end;

{ TAbstractMenuManager }

procedure TAbstractMenuManager.AfterConstruction;
begin
  inherited AfterConstruction;
  FRegisteredActions := TStringList.Create;
  //sort strings in list so all actions registered by a plugin will be grouped together
  FRegisteredActions.Duplicates := dupAccept;
  FRegisteredActions.Sorted := True;
end;

procedure TAbstractMenuManager.BeforeDestruction;
begin
  FRegisteredActions.Free;
  inherited BeforeDestruction;
end;

end.

