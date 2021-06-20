unit hcPackageInfo;

interface

uses
  Classes, SysUtils;

type
  ThcPackageLoadOption = (loOnStartup, loOnDemand, loOnIdle, loDisabled);
  {
    All Package information we want to display or track for plugin packages.
  }
  ThcPackageInfoClass = class of ThcPackageInfo;

  ThcPackageInfo = class(TCollectionItem)
  private
    FLoadOption: ThcPackageLoadOption;
    FUnits: TStringList;
    FRequiredPackages: TStringList;
    FPackageName: string;
    FVersion: string;
    FCreationDate: TDateTime;
    FLastLoaded: TDateTime;
    FFileName: TFileName;
    FModuleHandle: HModule;
    function GetDescription: string;
    procedure SetLastLoaded(const Value: TDateTime);
  protected
    procedure SetFileName(Value: TFileName);
  public
    property Description: string read GetDescription;
    property Version: string read FVersion;
    property CreationDate: TDateTime read FCreationDate;
    property ModuleHandle: HModule read FModuleHandle write FModuleHandle;
    property PackageName: string read FPackageName write FPackageName;
    property RequiredPackages: TStringList read FRequiredPackages;
    property Units: TStringList read FUnits;
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
  published
    property FileName: TFileName read FFileName write SetFileName;
    property LastLoaded: TDateTime read FLastLoaded write SetLastLoaded;
    property LoadOption: ThcPackageLoadOption read FLoadOption
      write FLoadOption;
  end;

implementation

uses
  hcVersionInfo, Windows;

{ ThcPackageInfo }

procedure ThcPackageInfo.SetFileName(Value: TFileName);
begin
  if not FileExists(Value) then
    raise Exception.CreateFmt('%s does not exist!', [Value]);
  FFileName := Value;
  FVersion := GetFileVersionText(FFileName);
  FModuleHandle := 0;
  FLastLoaded := 0;
  FileAge(FFileName, FCreationDate);
end;

destructor ThcPackageInfo.Destroy;
begin
  FUnits.Free;
  FRequiredPackages.Free;
  inherited Destroy;
end;

constructor ThcPackageInfo.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FUnits := TStringList.Create;
  FRequiredPackages := TStringList.Create;
end;

function ThcPackageInfo.GetDescription: string;
{
  Get the description from the BPL
}
begin
  Result := SysUtils.GetPackageDescription(PChar(FFileName));
end;

procedure ThcPackageInfo.SetLastLoaded(const Value: TDateTime);
begin
  FLastLoaded := Value;
end;

end.
