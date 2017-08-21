unit frmExamples;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  ExtCtrls,
  StdCtrls,
  ComCtrls, Vcl.Imaging.pngimage;

type
  TfrmUsageExamples = class(TForm)
    scrlbx1: TScrollBox;
    mmo1: TMemo;
    img1: TImage;
    pgc1: TPageControl;
    ts1: TTabSheet;
    mmo2: TMemo;
    img2: TImage;
    mmo3: TMemo;
    img3: TImage;
    mmo4: TMemo;
    img4: TImage;
    procedure btnExtractRunAsLouClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmUsageExamples            : TfrmUsageExamples;

implementation


{$R *.dfm}

procedure TfrmUsageExamples.btnExtractRunAsLouClick(Sender: TObject);
var
  sPath                       : string;
begin
  if
    (MessageDlg('Are you sure you want to extract RunAsLOU.exe to the program''s current directory?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
  begin
    Exit;
  end;
  //
  sPath := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));

//  if main.Form1.ExtractRunAsLou then
//  begin
//    MessageBox(0, PChar('RunAsLOU.exe succesfully extracted to: ' + #13#10
//      + '<' + sPath + '\>'), '', MB_ICONINFORMATION or MB_OK);
//  end
//  else
//  begin
//    MessageBox(0, PChar('RunAsLOU.exe succesfully extracted to: ' + #13#10
//      + '<' + sPath + '\>'), '', MB_ICONERROR or MB_OK);
//  end;

end;

end.

