program CompositeApp;



uses
  Forms,
  fmToolbar in '..\..\Source\CompositeApp\fmToolbar.pas' {ToolBarFrm},
  fmSplash in '..\..\Source\CompositeApp\fmSplash.pas' {frmSplash},
  hcCorePlugInLoader in '..\..\Source\CompositeApp\hcCorePlugInLoader.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'CompositeApp';
  TfrmSplash.ShowSplash;
  Application.CreateForm(TToolBarFrm, ToolBarFrm);
  Application.Run;
end.
