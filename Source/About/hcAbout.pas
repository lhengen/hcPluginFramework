unit hcAbout;

interface

uses
  hcApplicationIntf
  ,StdActns
  ,ActnList
  ;

type
  TAboutPlugIn = class(TAbstractPlugIn)
  private
    actAbout: TAction;
    actHelp: TAction;
    actHelpContents: THelpContents;
    actTopicSearch: THelpTopicSearch;
    actHelponHelp: THelpOnHelp;
    actHelpContext: THelpContextAction;
    procedure Execute(Sender:TObject);
    procedure EmptyActionExecuteHandler(Sender: TObject);
  protected
  public
    function Name: string; override;
    function GUID: string; override;
    function Description: string; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  end;

implementation



uses
  Windows
  ,Forms
  ,fmAbout
  ;

var
  myPlugIn: TAboutPlugIn;

function TAboutPlugIn.GUID: string;
begin
  Result := '{55942094-A149-4360-A056-8032FD565DC7}';
end;

procedure TAboutPlugIn.BeforeDestruction;
begin
  inherited BeforeDestruction;
end;

procedure TAboutPlugIn.EmptyActionExecuteHandler(Sender: TObject);
begin
  //
end;

procedure TAboutPlugIn.AfterConstruction;
begin
  inherited AfterConstruction;

  actHelp := TAction.Create(nil);
  actHelp.Caption := '&Help';
  actHelp.OnExecute := EmptyActionExecuteHandler;
  ApplicationServices.MenuManager.AddAction(Self,actHelp,'Window',True,False);
  actHelpContents := THelpContents.Create(nil);
  actHelpContents.Caption := 'Contents';
  ApplicationServices.MenuManager.AddAction(Self,actHelpContents,actHelp.Caption,True,True);
  actTopicSearch := THelpTopicSearch.Create(nil);
  actTopicSearch.Caption := '&Search';
  ApplicationServices.MenuManager.AddAction(Self,actTopicSearch,actHelp.Caption,True,True);
  actHelponHelp := THelpOnHelp.Create(nil);
  actHelponHelp.Caption := 'Help using Help';
  ApplicationServices.MenuManager.AddAction(Self,actHelponHelp,actHelp.Caption,True,True);
  actHelpContext := THelpContextAction.Create(nil);
  actHelpContext.Caption := 'Context Sensitive Help';
  ApplicationServices.MenuManager.AddAction(Self,actHelpContext,actHelp.Caption,True,True);
  actAbout := TAction.Create(nil);
  actAbout.Caption := '&About ';
  actAbout.OnExecute := Execute;
  ApplicationServices.MenuManager.AddAction(Self,actAbout,actHelp.Caption,True,True);
end;

procedure TAboutPlugIn.Execute(Sender :TObject);
begin
  TfrmAbout.Execute;
end;

function TAboutPlugIn.Description: string;
begin
	result := 'Hengen Computing About PlugIn';
end;

function TAboutPlugIn.Name: string;
begin
	result := 'Hengen Computing About Dialog';
end;

initialization
	myPlugIn := TAboutPlugIn.Create;
  ApplicationServices.RegisterPlugIn(myPlugIn);

finalization
  myPlugIn.Free;


end.
