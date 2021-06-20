unit hcCorePlugIn;

interface

uses
	Classes
  ,hcApplicationIntf
  ,ActnMan
  ,ActnList
  ,contnrs
  ,ActnMenus
  ,Menus
  ,Forms
  ,hcCompositeAppTypes
  ,fmStdForm
  ;

type
  {
    Class used to track RegisteredFormClass information on a plugin basis
  }
  ThcFormInfo = class(TObject)
    GUID :string;  //GUID for the plugin that registered the FormClass
    FormClass :TStdFormClass;
    InstanceSpecifier :ThcInstanceSpecifier;
  end;

  {
    The FormManagers role is to manage the instances of all registered forms including their presentation
    on the Window menu.  The Window menu serves as both a list of all form instances and a UI element used
    to switch between and control the appearance of all form instances.

    Forms are associated with Actions for their initial invocation.  These actions must be registered with
    the MenuManager in order for the user to invoke a form.  The FormManager only needs to know the Action
    because it populates the Action.OnExecute handler with the ExecuteForm() handler.

    Forms may be invoked only by local menus and never appear on the Window menu.  Such forms must be modal.

  }
  ThcFormManager = class(TAbstractFormManager)
  private
    FRegisteredFormClasses :TObjectList;
    FFormInstances :TList;
    procedure AddWindowMenuItem(FormInstance :TfrmStandard);
    procedure WindowMenuItemClick(Sender:TObject);
    procedure CheckWindowMenuItem(FormInstance :TForm);
    procedure CreateFormInstance(FormInfo:ThcFormInfo);
    procedure ActivateInstance(FormInfo:ThcFormInfo);
    function InstanceCount(FormInfo :ThcFormInfo): Integer;
    procedure ExecuteForm(Sender :TObject);
  public
    function CanCloseApp :boolean; override;
    function GetPlugInFormInfo(APlugin :TAbstractPlugIn) :TStringList; override;
    procedure ActivateForm(FormInstance :TfrmStandard); override;
    procedure RemoveForm(FormInstance :TfrmStandard); override;
    procedure RemovePlugInForms(aPlugIn :TAbstractPlugIn); override;
    procedure RegisterFormAction(aPlugIn :TAbstractPlugIn; FormClass :TStdFormClass; Action :TCustomAction; InstanceSpecifier :ThcInstanceSpecifier); override;
    procedure RegisterFormInstance(aPlugIn :TAbstractPlugIn; FormInstance :TfrmStandard); override;

    constructor Create(aOwner :TComponent); override;
    destructor Destroy; override;
  end;

  ThcMainMenuMenuManager = class(TAbstractMenuManager)
  private
    function FindMenuItemByAction(const Action :TCustomAction): TMenuItem;
    function ProcessMenu(const AMenu :TMenuItem; const Action: TCustomAction): TMenuItem;
  public
    procedure AddAction(const PlugIn: TAbstractPlugIn; const Action: TCustomAction; const TargetItemCaption: string;
      const AddAfterTargetItem:boolean = True; const AddAsSubMenuItem:boolean = false; const Anchored :boolean = False); override;
    procedure RemovePlugInActions(PlugIn :TAbstractPlugIn); override;
    function GetPluginActionInfo(PlugIn :TAbstractPlugIn) :TStringList; override;
  end;

  TApplicationServices = class(TAbstractApplicationServices)
  private
    FRegisteredActions :TObjectList;
  protected
    function GetMenuManager :TAbstractMenuManager; override;
  public
    procedure RegisterFormAction(APlugIn: TAbstractPlugIn; FormClass :TStdFormClass; InstanceSpecifier :ThcInstanceSpecifier; Action :TCustomAction; TargetItemCaption :string; AddAfterTargetItem :boolean = True; AddAsSubMenuItem :boolean = false); override;
    procedure SavePlugInLists; override;
    procedure LoadPlugInLists; override;
  	constructor Create(aOwner :TComponent); override;
    destructor Destroy; override;
    function GetPlugIn(const plugInName: string): TAbstractPlugIn; override;
    procedure RegisterPlugIn(APlugIn: TAbstractPlugIn); override;
    procedure UnregisterPlugIn(APlugIn: TAbstractPlugIn); override; //useful if one plugin wants to destroy and unregister another plugin
  end;

implementation

uses
	Dialogs
	,SysUtils
  {$ifdef DEBUG}
  ,CodeSiteLogging
  {$endif}  // DEBUG
  ,Math
  ,OmniXMLPersistent
  ,OmniXML
  ;

procedure ThcFormManager.RegisterFormInstance(aPlugIn :TAbstractPlugIn; FormInstance:TfrmStandard);
begin
  FFormInstances.Add(FormInstance);
  FormInstance.FormManager := Self;
  FormInstance.GUID := aPlugIn.GUID;
  AddWindowMenuItem(FormInstance);
  //show the form instance
  FormInstance.Show;
end;

procedure ThcFormManager.ActivateForm(FormInstance:TfrmStandard);
{
  Perform any action necessary when the user activates a form or if the developer
  calls this method to make an instance the active form.
}
begin
  if not FormInstance.CanFocus then
    Exit;

  if not FormInstance.Active then
    FormInstance.SetFocus;
  CheckWindowMenuItem(FormInstance);
end;


destructor ThcFormManager.Destroy;
begin
  FRegisteredFormClasses.Free;
  FFormInstances.Free;
  inherited Destroy;
end;

constructor ThcFormManager.Create(aOwner:TComponent);
begin
  inherited Create(aOwner);
  FRegisteredFormClasses := TObjectList.Create;
  FFormInstances := TList.Create;
end;

procedure ThcFormManager.RegisterFormAction(aPlugIn :TAbstractPlugIn; FormClass :TStdFormClass; Action :TCustomAction; InstanceSpecifier :ThcInstanceSpecifier);
var
  FormInfo: ThcFormInfo;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('ThcFormManager.RegisterFormAction');
  {$endif}  // DEBUG
  FormInfo := ThcFormInfo.Create;
  FormInfo.FormClass := FormClass;
  FormInfo.InstanceSpecifier := InstanceSpecifier;
  FormInfo.GUID := aPlugin.GUID;
  FRegisteredFormClasses.Add(FormInfo);
  Action.OnExecute := ExecuteForm;
  {
    Attach FormInfo object to Action so when action is executed we know what form
    to create or activate depending on instance count
    and searching the list of registered forms is not required
  }
  Action.Tag := Integer(FormInfo);

  {$ifdef DEBUG}
  CodeSite.ExitMethod('ThcFormManager.RegisterFormAction');
  {$endif}  // DEBUG
end;


function ThcFormManager.InstanceCount(FormInfo :ThcFormInfo): Integer;
{
  Return number of instances created for a given Form Class supplied via
  the FormInfo object.  Iterates over the Window Menu, counting instances.
}
var
  Count,
  I: Integer;
begin
  Count := 0;
  for I := 0 to FFormInstances.Count - 1 do    // Iterate
  begin
    //only check menu items that contain a pointer to a form instance - other SB 0
    if (TForm(FFormInstances[I]).ClassType = FormInfo.FormClass) then
        Inc(Count,1);
  end;    // for
  Result := Count;
end;

function ThcFormManager.GetPlugInFormInfo(APlugin :TAbstractPlugIn) :TStringList;
{
  Routine to return a unique list of all ClassNames for RegisteredFormActions and FormInstances.
}
var
  I: Integer;
  GUID: string;
begin
  GUID := APlugin.GUID;
  Result := TStringList.Create;
  Result.Duplicates := dupIgnore;
  Result.Sorted := True;

  //free all form instances matching the plugin's GUID
  for I := FFormInstances.Count - 1 downto 0 do    // Iterate
  begin
    if (TfrmStandard(FFormInstances[I]).GUID = GUID) then
      Result.Add(TObject(FFormInstances[I]).ClassName);
  end;    // for

  //remove all FormClass registrations for this plugin
  for I := FRegisteredFormClasses.Count - 1 downto 0 do    // Iterate
  begin
    if ThcFormInfo(FRegisteredFormClasses[I]).GUID = GUID then
      Result.Add(ThcFormInfo(FRegisteredFormClasses[I]).FormClass.ClassName);
  end;    // for
end;

procedure ThcFormManager.RemoveForm(FormInstance:TfrmStandard);
{
  Removes the Window item associated with a form instance if there is one, and removes the
  form instance from the instance list and frees the forminstance.
}
var
  nIndex,
  I: Integer;
begin
  for I := 0 to WindowMenu.Count - 1 do    // Iterate
  begin
    if (WindowMenu.Items[I].Tag <> 0) and (TfrmStandard(WindowMenu.Items[I].Tag) = FormInstance) then
    begin
      nIndex := FFormInstances.IndexOf(FormInstance);
      //if found free and nil the form instance and delete it form the instance list
      if nIndex <> -1 then
      begin
        FreeAndNil(FormInstance);
        FFormInstances.Delete(nIndex);
      end;
      //Free associated Window menu item
      WindowMenu[I].Free;
      break;
    end;
  end;    // for
  //activate the first form in the window Menu if one exists
  if (FFormInstances.count > 0) then
    ActivateForm(FFormInstances[0]);
end;

procedure ThcFormManager.RemovePlugInForms(APlugin :TAbstractPlugIn);
{
  Frees instances of forms registered by the plugin and their FormInfo objects
  as well as removing any Window menu items.
}
var
  nIndex: Integer;
  I: Integer;
  GUID: string;
  FormInstance :TfrmStandard;
begin
  GUID := APlugin.GUID;

  //remove all Window menu items and all form instances for the GUID
  for I := WindowMenu.Count - 1 downto 0 do    // Iterate
  begin
    if (WindowMenu.Items[I].Tag <> 0) and (TFrmStandard(WindowMenu.Items[I].Tag).GUID = GUID) then
    begin
      FormInstance := TFrmStandard(WindowMenu.Items[I].Tag);
      nIndex := FFormInstances.IndexOf(FormInstance);
      if nIndex <> -1 then
      begin
        FreeAndNil(FormInstance);
        FFormInstances.Delete(nIndex);
      end;
      WindowMenu[I].Free;
    end;
  end;    // for

  //remove all FormClass registrations for this plugin
  for I := FRegisteredFormClasses.Count - 1 downto 0 do    // Iterate
  begin
    if ThcFormInfo(FRegisteredFormClasses[I]).GUID = GUID then
      FRegisteredFormClasses.Delete(I);  //removes and frees FormInfo object
  end;    // for
end;

procedure ThcFormManager.ExecuteForm(Sender :TObject);
var
  FormInfo: ThcFormInfo;
  Action: TCustomAction;
begin
  Action := Sender as TCustomAction;
  assert(Action.Tag <> 0 ,'Form Action does not have form Info in Tag (Tag = 0)');
  FormInfo := ThcFormInfo(Action.Tag);
  {$ifdef DEBUG}
//  CodeSite.SendObject('FormInfo', FormInfo);
  {$endif}  // DEBUG
  if ((FormInfo.InstanceSpecifier = isSingle) and (InstanceCount(FormInfo) = 0))
    or (FormInfo.InstanceSpecifier = isMultiple) then
  begin
    {$ifdef DEBUG}
    CodeSite.SendMsg('Creating Form Instance');
    {$endif}  // DEBUG
    CreateFormInstance(FormInfo);
  end
  else
  begin
    {$ifdef DEBUG}
    CodeSite.SendMsg('Activating Existing Form Instance');
    {$endif}  // DEBUG
    ActivateInstance(FormInfo);
  end;
end;

procedure ThcFormManager.AddWindowMenuItem(FormInstance :TfrmStandard);
var
  aMenuItem: TMenuItem;
begin
  //create a new Window Menu MenuItem for the form instance
  aMenuItem := TMenuItem.Create(Self);
  aMenuItem.Caption := FormInstance.Caption;
  aMenuItem.Tag := integer(FormInstance);
  aMenuItem.OnClick := WindowMenuItemClick;

  //add the MenuItem to the end of the Window menu
  WindowMenu.Insert(WindowMenu.Count,aMenuItem);
  CheckWindowMenuItem(FormInstance);
end;

procedure ThcFormManager.CreateFormInstance(FormInfo :ThcFormInfo);
{
  Creates an instance of the Form Specified, Adds it to the Window menu and makes it the current
  active form.
}
var
  aFormInstance: TfrmStandard;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('ThcFormManager.CreateFormInstance');
  {$endif}  // DEBUG
  //create an instance of the form
  aFormInstance := FormInfo.FormClass.Create(nil);  //todo - fix - do not pass Nil
  aFormInstance.GUID := FormInfo.GUID;
  aFormInstance.FormManager := Self;
  FFormInstances.Add(aFormInstance);

  AddWindowMenuItem(aFormInstance);

  //show the form instance
  aFormInstance.Show;
  {$ifdef DEBUG}
  CodeSite.ExitMethod('ThcFormManager.CreateFormInstance');
  {$endif}  // DEBUG
end;

procedure ThcFormManager.WindowMenuItemClick(Sender :TObject);
{
  Switch focus to form instance in Tag field of this menu item and Check/UnCheck the appropriate
  Window Menu items.
}
var
  aFormInstance: TForm;
begin
  with (Sender as TMenuItem) do
  begin
    aFormInstance := TForm(Tag);
    if not aFormInstance.Visible then
      aFormInstance.Show;
    aFormInstance.SetFocus;
    CheckWindowMenuItem(aFormInstance);
  end;    // with
end;

function ThcFormManager.CanCloseApp: boolean;
var
  I: Integer;
  CanClose: boolean;
begin
	Result := True;
  for I := FFormInstances.Count - 1 downto 0  do    // Iterate
  begin
    with TfrmStandard(FFormInstances[i]) do
    begin
      //call the forms CloseQuery event handler to see if we can close it
      CanClose := True;
      if assigned(OnCloseQuery) then
        OnCloseQuery(Self,CanClose);

      if CanClose then
        Close
      else
      begin
        Result := False;
        break;
      end;
    end;  // with
  end;
end;

procedure ThcFormManager.CheckWindowMenuItem(FormInstance :TForm);
var
  j: Integer;
begin
  for j := 0 to WindowMenu.Count - 1 do
  begin

    //uncheck the previous active window menu item
    if WindowMenu.Items[J].Checked then
      WindowMenu.Items[J].Checked := False;

    //check the window item for the FormInfo instance passed
    if ((WindowMenu.Items[J].Tag <> 0) and (TForm(WindowMenu.Items[J].Tag) = FormInstance)) then
      WindowMenu.Items[J].Checked := True;

  end;    // for
end;

procedure ThcFormManager.ActivateInstance(FormInfo :ThcFormInfo);
{
  Searches for an existing form instance for the formclass specified via the FormInfo object
  and makes it the current active form.
}
var
  I: Integer;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('ThcFormManager.ActivateInstance');
  {$endif}  // DEBUG
  for I := 0 to FFormInstances.Count - 1 do    // Iterate
  begin
    if (TForm(FFormInstances[I]).ClassType = FormInfo.FormClass) then
      with TForm(FFormInstances[I]) do
      begin
        //check the appropriate Window menu item (unchecking all others)
        CheckWindowMenuItem(TForm(FFormInstances[I]));
        if not Visible {default form close action is hide} then
          Visible := True;
        if CanFocus then
          SetFocus;
      end;    // with
  end;    // for
  {$ifdef DEBUG}
  CodeSite.ExitMethod('ThcFormManager.ActivateInstance');
  {$endif}  // DEBUG
end;

function ThcMainMenuMenuManager.GetPluginActionInfo(PlugIn:TAbstractPlugIn):TStringList;
{
  Routine to return a list of the actions registered by a PlugIn.
  TODO - consider returning an interface so the user does not have to explicitly free the
  stringlist.
}
var
  I: Integer;
  nIndex: Integer;
  GUID: string;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('ThcMainMenuMenuManager.GetPluginActionInfo');
  {$endif}  // DEBUG
  Result := TStringList.Create;
  GUID := PlugIn.GUID;
  nIndex := FRegisteredActions.IndexOf(GUID);
  if nIndex > -1 then
  begin
    //if we have one or more actions then iterate over list removing any actions for this plugin
    for I := FRegisteredActions.Count - 1 downto nIndex do    // Iterate
    begin
      if FRegisteredActions[I] = GUID then
      begin
        {$ifdef DEBUG}
//        CodeSite.SendObject(Format('Found Registered Action for GUID %s',[GUID]),FRegisteredActions.Objects[I]);
        {$endif}  // DEBUG
        Result.Add(TAction(FRegisteredActions.Objects[I]).Caption);
      end;
    end;    // for
  end;
  {$ifdef DEBUG}
  CodeSite.ExitMethod('ThcMainMenuMenuManager.GetPluginActionInfo');
  {$endif}  // DEBUG
end;

function ThcMainMenuMenuManager.ProcessMenu(const AMenu :TMenuItem; const Action: TCustomAction): TMenuItem;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to AMenu.Count - 1 do
  begin
    if AMenu.Items[I].Action = Action then
    begin
      Result := AMenu.Items[I];
      break;
    end
    else
      ProcessMenu(AMenu[i], Action);
  end;
end;

function ThcMainMenuMenuManager.FindMenuItemByAction(const Action: TCustomAction): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FMenu.Items.Count - 1 do    // Iterate
  begin
    //check current root menu item
    if FMenu.Items[I].Action = Action then
      Result := FMenu.Items[I]
    else  //if not the root item check all sub menu items
      Result := ProcessMenu (FMenu.Items[I], Action);
    if Result <> nil then
      break;
  end;
end;

procedure ThcMainMenuMenuManager.AddAction(const PlugIn: TAbstractPlugIn; const Action: TCustomAction; const TargetItemCaption: string;
      const AddAfterTargetItem:boolean = True; const AddAsSubMenuItem:boolean = false; const Anchored :boolean = False);
var
  ParentMenuItem: TMenuItem;
  ParentComponent :TComponent;
  NewItem,
  TargetItem: TMenuItem;
begin
  //add to list of registered actions for the menu
  FRegisteredActions.AddObject(Plugin.GUID, Action);
  //add action to the menu in the proper position
  TargetItem := FMenu.Items.Find(TargetItemCaption);
  if assigned(TargetItem) then
  begin
    {$ifdef DEBUG}
    CodeSite.SendMsg(Format('TargetMenu Item with Caption ''%s'' was found', [TargetItemCaption]));
    {$endif}  // DEBUG
    NewItem := TMenuItem.Create(FMenu);
    NewItem.Action := Action;
    //if the target item was found and we are to add the action as a sub menu item then just add to end of menu
    if AddAsSubMenuItem then
    begin
      {$ifdef DEBUG}
      CodeSite.SendMsg(Format('Adding Action ''%s'' as SubMenuItem ', [Action.Caption]));
      {$endif}  // DEBUG
      TargetItem.Add(NewItem)
    end
    else
    begin
      //if the target was found and it is a root level menu item then
      ParentComponent := TargetItem.GetParentComponent;
      if ParentComponent is TMenu then  //root menu item
        ParentMenuItem := FMenu.Items
      else
        ParentMenuItem := TMenuItem(ParentComponent);

      {$ifdef DEBUG}
      CodeSite.SendMsg(Format('Inserting Action ''%s'' into Menu',[Action.Caption]));
      {$endif}  // DEBUG
      if (AddAfterTargetItem) then
        ParentMenuItem.Insert(TargetItem.MenuIndex + 1, NewItem)
      else
        ParentMenuItem.Insert(TargetItem.MenuIndex, NewItem);
    end;
  end
  else
  begin
    {$ifdef DEBUG}
    CodeSite.Send(Format('Could not find menu item with Caption of %s so skipping addition of Action %s', [TargetItemCaption, Action.Caption]));
    {$endif}  // DEBUG
  end;
end;

procedure ThcMainMenuMenuManager.RemovePlugInActions(PlugIn:TAbstractPlugIn);
{
  Routine to remove any TMenuItem objects linked to Actions registered by the
  PlugIn specified.
}
var
  GUID: string;
  MenuItem: TMenuItem;
  nIndex: integer;
  I: Integer;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('ThcMainMenuMenuManager.RemovePlugInActions');
  {$endif}  // DEBUG
  GUID := PlugIn.GUID;
  nIndex := FRegisteredActions.IndexOf(GUID);
  if nIndex > -1 then
  begin
    //if we have one or more actions then iterate over list removing any actions for this plugin
    for I := FRegisteredActions.Count - 1 downto nIndex do    // Iterate
    begin
      if FRegisteredActions[I] = GUID then
      begin
        {$ifdef DEBUG}
        CodeSite.Send(Format('Found Registered Action for GUID %s',[GUID]),TCustomAction(FRegisteredActions.Objects[I]).Caption);
        {$endif}  // DEBUG

        MenuItem := FindMenuItemByAction(TCustomAction(FRegisteredActions.Objects[I]));
        //if we free a Root menu item it will free all it's sub MenuItems so FindMenuItemByAction may return nil
        if assigned(MenuItem) then
        begin
          {$ifdef DEBUG}
          CodeSite.Send('Freeing Menu Item', MenuItem.Caption);
          {$endif}  // DEBUG
          MenuItem.Action := nil;  //free the action links
          MenuItem.Free;
        end;

        {$ifdef DEBUG}
        CodeSite.Send('Freeing Action Item', TAction(FRegisteredActions.Objects[I]).Caption);
        {$endif}  // DEBUG
        FRegisteredActions.Objects[I].Free;


        {$ifdef DEBUG}
        CodeSite.SendFmtMsg('Deleting Registered Action Entry at Index %d',[I]);
        {$endif}  // DEBUG
        FRegisteredActions.Delete(I);
      end;
    end;    // for
  end;
  {$ifdef DEBUG}
  CodeSite.ExitMethod('ThcMainMenuMenuManager.RemovePlugInActions');
  {$endif}  // DEBUG
end;

procedure TApplicationServices.RegisterFormAction(APlugIn: TAbstractPlugIn; FormClass :TStdFormClass; InstanceSpecifier :ThcInstanceSpecifier; Action :TCustomAction; TargetItemCaption :string; AddAfterTargetItem :boolean = True; AddAsSubMenuItem :boolean = false);
begin
  MenuManager.AddAction(APlugIn,Action,TargetItemCaption,AddAfterTargetItem,AddAsSubMenuItem);
  FormManager.RegisterFormAction(APlugIn,FormClass,Action,InstanceSpecifier);
end;

procedure TApplicationServices.SavePlugInLists;
var
  BinFolder: string;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('TApplicationServices.SavePlugInLists');
  {$endif}  // DEBUG
  BinFolder := ExtractFilePath(Application.EXEName);
  {$ifdef DEBUG}
  CodeSite.SendMsg('BinFolder = '+BinFolder);
  {$endif}  // DEBUG
  TOmniXMLWriter.SaveToFile(Plugins.UserPackages, BinFolder +'UserPackages.xml',pfAttributes,ofIndent);
  TOmniXMLWriter.SaveToFile(Plugins.SystemPackages, BinFolder +'SystemPackages.xml',pfAttributes,ofIndent);
  {$ifdef DEBUG}
  CodeSite.ExitMethod('TApplicationServices.SavePlugInLists');
  {$endif}  // DEBUG
end;

procedure TApplicationServices.LoadPlugInLists;
var
  BinFolder: string;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('TApplicationServices.LoadPlugInLists');
  {$endif}  // DEBUG
  BinFolder := ExtractFilePath(Application.EXEName);
  if FileExists(BinFolder +'SystemPackages.xml') then
    TOmniXMLReader.LoadFromFile(Plugins.SystemPackages, BinFolder +'SystemPackages.xml');
  if FileExists(BinFolder +'UserPackages.xml') then
    TOmniXMLReader.LoadFromFile(Plugins.UserPackages, BinFolder +'UserPackages.xml');
  {$ifdef DEBUG}
  CodeSite.ExitMethod('TApplicationServices.LoadPlugInLists');
  {$endif}  // DEBUG
end;

function TApplicationServices.GetMenuManager:TAbstractMenuManager;
begin
  assert(assigned(FMenuManager),'ApplicationServices - MenuManager is not assigned!');
  result := FMenuManager;
end;

constructor TApplicationServices.Create(aOwner :TComponent);
begin
	inherited Create(aOwner);
  FRegisteredActions := TObjectList.Create;
end;    { Create }

destructor TApplicationServices.Destroy;
begin
	FreeAndNil(FRegisteredActions);
  inherited Destroy;
end;    { Destroy }

procedure TApplicationServices.RegisterPlugIn(APlugIn: TAbstractPlugIn);
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('TApplicationServices.RegisterPlugIn');
  {$endif}  // DEBUG
  //add the Plugin to the list if it's Name is not found
  if assigned(APlugIn) and (Plugins.IndexOf(APlugIn.Name) = -1) then
  begin
    Plugins.Add(APlugIn);
  end;
  {$ifdef DEBUG}
  CodeSite.ExitMethod('TApplicationServices.RegisterPlugIn');
  {$endif}  // DEBUG
end;		{ RegisterPlugIn }

procedure TApplicationServices.UnregisterPlugIn(APlugIn: TAbstractPlugIn);
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('TApplicationServices.UnregisterPlugIn');
  {$endif}  // DEBUG
 	if assigned(APlugIn) then
  begin
    //remove the plugin from the list
    Plugins.Remove(APlugIn);

    //remove any form instances for this plugin
    FormManager.RemovePlugInForms(APlugin);

    //remove any actions from the menu
    MenuManager.RemovePlugInActions(APlugIn);

  end;
  {$ifdef DEBUG}
  CodeSite.ExitMethod('TApplicationServices.UnregisterPlugIn');
  {$endif}  // DEBUG
end;		{ UnregisterPlugIn }

function TApplicationServices.GetPlugIn(const plugInName: string): TAbstractPlugIn;
var
	j: integer;
begin
  {$ifdef DEBUG}
  CodeSite.EnterMethod('TApplicationServices.GetPlugIn');
  {$endif}  // DEBUG
	result := nil;
	with PlugIns do
		for j := 0 to Count - 1 do		{ Iterate through registered plug-ins. }
			if CompareText(TAbstractPlugIn(Items[j]).Name, plugInName) = 0 then
      begin
        result := TAbstractPlugIn(Items[j]);
        exit;
      end;
  {$ifdef DEBUG}
  CodeSite.ExitMethod('TApplicationServices.GetPlugIn');
  {$endif}  // DEBUG
end;		{ GetPlugIn }


initialization
  ApplicationServices := TApplicationServices.Create(nil);
  ApplicationServices.MenuManager := ThcMainMenuMenuManager.Create(ApplicationServices);
  ApplicationServices.FormManager := ThcFormManager.Create(ApplicationServices);


finalization
  FreeAndNil(ApplicationServices);

end.
