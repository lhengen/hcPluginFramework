unit hcPlugInDesignTime;

interface

procedure Register;

implementation

uses Classes, hcCorePlugInLoader;

procedure Register;
begin
  RegisterComponents('HCI', [ThcCorePlugInLoader]);
end;

end.
 