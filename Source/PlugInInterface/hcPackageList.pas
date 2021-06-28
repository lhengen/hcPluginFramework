unit hcPackageList;

interface

uses
  contnrs
  ,hcPackageInfo
  ,hcCompositeAppTypes
  ,Classes
  ;

type
  {
    List used to manage packages and persist any package info to storage for subsequent
    application executions.

    The order of the items in the list is important!

    As changes are made to the list, they are immediately saved to prevent problems resulting
    from an application crash.
  }
  ThcPackageCollection = class(TOwnedCollection)
  private
  protected
    function GetItem(Index: Integer): ThcPackageInfo;
    procedure SetItem(Index: Integer; Value: ThcPackageInfo);
  public
    constructor Create(AOwner: TComponent);

    function PackageInList(const PackageFileName: string; checkLoaded: boolean): boolean;
    procedure RemovePackage(const PackageFileName: string);
    function IndexOf(const PackageFileName: string) :integer;

    function Add : ThcPackageInfo; overload;
    function Insert(Index: Integer): ThcPackageInfo;
    property Items[Index: Integer]: ThcPackageInfo read GetItem write SetItem;  default;
  end;


implementation

uses
  SysUtils
  ,Registry
  ,INIFiles
  {$ifdef hcCodeSite}
  ,CodeSiteLogging
  {$endif}  // DEBUG
  ;

function ThcPackageCollection.Insert(Index: Integer): ThcPackageInfo;
begin
  Result := ThcPackageInfo(inherited Insert(Index));
end;

function ThcPackageCollection.Add: ThcPackageInfo;
begin
  Result := ThcPackageInfo(inherited Add);
end;

procedure ThcPackageCollection.SetItem(Index: Integer; Value: ThcPackageInfo);
begin
  inherited SetItem(Index,Value);
end;

constructor ThcPackageCollection.Create(AOwner: TComponent);
begin
  inherited Create(aOwner,ThcPackageInfo);
end;

function ThcPackageCollection.PackageInList(const PackageFileName: string; checkLoaded: boolean): boolean;
var
  j: integer;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod('ThcPackageCollection.PackageInList');
  {$endif}  // DEBUG
  result := False;
  for j := 0 to Count - 1 do    { Iterate through all packages in list... }
  begin
    if CompareText(PackageFileName, Items[J].FileName) = 0 then   // Found a match!
    begin
      {$ifdef DebugPackageLoading}
      CodeSite.SendMsg('Found a match!');
      {$endif}
      if not checkLoaded then   // No need to check to see if the package is really loaded...
        Result := True
      else
      begin
        {$ifdef DebugPackageLoading}
        CodeSite.SendMsg('Check to see if loaded...');
        {$endif}
        if Items[J].ModuleHandle <> 0 then   // Must check to see if package is loaded...
        begin
          {$ifdef DebugPackageLoading}
          CodeSite.SendMsg('Package "' + PackageFileName + '" is loaded.');
          {$endif}
          Result := True;
        end;
      end;
      break;
    end;
  end;    { for }
  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('ThcPackageCollection.PackageInList');
  {$endif}  // DEBUG
end;    { PackageInList }


function ThcPackageCollection.IndexOf(const PackageFileName: string):integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Count - 1 do    // Iterate
  begin
    if (CompareText(Items[I].FileName,PackageFileName) = 0) then
    begin
      Result := I;
      break;
    end;
  end;    // for
end;

procedure ThcPackageCollection.RemovePackage(const PackageFileName: string);
var
  nIndex: Integer;
begin
  {$ifdef hcCodeSite}
  CodeSite.EnterMethod(Format('ThcPackageCollection.RemovePackage - %s',[PackageFileName]));
  {$endif}  // DEBUG
  nIndex := IndexOf(PackageFileName);
  if nIndex >= 0 then
    Delete(nIndex);
  {$ifdef hcCodeSite}
  CodeSite.ExitMethod('ThcPackageCollection.RemovePackage');
  {$endif}  // DEBUG
end;

function ThcPackageCollection.GetItem(Index: Integer): ThcPackageInfo;
begin
  Result := ThcPackageInfo(inherited GetItem(Index));
end;

end.
