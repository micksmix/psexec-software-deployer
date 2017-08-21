unit main;

interface

uses
  Classes,
  Controls,
  Forms,
  StdCtrls,
  SysUtils,
  ExtCtrls,
  Spin,
  uHelpers,
  uThrdAbortThreads,
  uWorkerThread,
  Windows,
  Messages,
  Dialogs,
  ComCtrls,
  DB,
  AsyncCalls,
  ShellAnimations,
  ActnList,
  Menus,
  JvMemoryDataset,
  ImgList,
  Buttons,
  XPMan,
  Math,
  Grids,
  DBGrids,
  JvExDBGrids,
  JvDBGrid,
  JvDBGridExport,
  JvComponentBase;

type
  TForm1 = class(TForm)
    grpOptionalParameters: TGroupBox;
    cbInteractDesktop: TCheckBox;
    cbSystemAcct: TCheckBox;
    cbOverwriteExistingFile: TCheckBox;
    cbDontWait: TCheckBox;
    cbThreadPriority: TComboBox;
    grpRequiredParams: TGroupBox;
    lblPass: TLabeledEdit;
    cbDontLoadProfile: TCheckBox;
    seTimeoutSeconds: TSpinEdit;
    cbConnTimeout: TCheckBox;
    Label1: TLabel;
    lblFileToRun: TLabeledEdit;
    rbCopyRemote: TRadioButton;
    rbRunExistingRemote: TRadioButton;
    cbCopyIfNewer: TCheckBox;
    btnBrowse: TButton;
    lblCommandLineParams: TLabeledEdit;
    Label2: TLabel;
    btnBeginDeploy: TButton;
    MemoHosts: TMemo;
    Label3: TLabel;
    lblConcurrentDeployemnts: TLabel;
    seThreads: TSpinEdit;
    cbShowPasswd: TCheckBox;
    StatusBar1: TStatusBar;
    cbCheckIfAlive: TCheckBox;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    jvmem: TDataSource;
    edtUser: TEdit;
    cbUsername: TCheckBox;
    SaveDialog1: TSaveDialog;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Exit1: TMenuItem;
    ClearResults1: TMenuItem;
    Saveas2: TMenuItem;
    ools1: TMenuItem;
    Downloadpsexectocurrentdirectory1: TMenuItem;
    Help1: TMenuItem;
    JvMemoryData1: TJvMemoryData;
    actAbout1: TMenuItem;
    Animate1: TAnimate;
    ImageList1: TImageList;
    btnCancel: TBitBtn;
    xpmnfst1: TXPManifest;
    //mxstrg1: TmxStorage;
    Usage1: TMenuItem;
    jvdbgrd1: TJvDBGrid;
    jvdbgrdcsvxprt1: TJvDBGridCSVExport;
    jvdbgrdhtmlxprt1: TJvDBGridHTMLExport;
    jvdbgrdxmlxprt1: TJvDBGridXMLExport;
    jvdbgrdxclxprt1: TJvDBGridExcelExport;
    pnlParamBox: TPanel;
    pnlCopyFileOptions: TPanel;
    pb1: TProgressBar;
    procedure rbCopyRemoteClick(Sender: TObject);
    procedure rbRunExistingRemoteClick(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure MemoHostsKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure cbShowPasswdClick(Sender: TObject);
    procedure btnClearResultsClick(Sender: TObject);
    procedure btnBeginDeployClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure cbUsernameClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Saveas2Click(Sender: TObject);
    procedure ClearResults1Click(Sender: TObject);
    procedure Copytoclipboard1Click(Sender: TObject);
    procedure Downloadpsexectocurrentdirectory1Click(Sender: TObject);
    procedure cbDontLoadProfileClick(Sender: TObject);
    procedure cbSystemAcctClick(Sender: TObject);
    procedure cbOverwriteExistingFileClick(Sender: TObject);
    procedure cbCopyIfNewerClick(Sender: TObject);
    procedure Help1Click(Sender: TObject);
    procedure Usage1Click(Sender: TObject);
    procedure ExtractRunAsLOU1Click(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure jvdbgrd1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure seThreadsChange(Sender: TObject);
    procedure seThreadsExit(Sender: TObject);
    procedure seThreadsKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    procedure ScanDone;
    procedure ThreadMessage(var Msg: TMessage); message WM_POSTED_MSG;
    function ValidateSelections(): boolean;
    procedure SetCheckboxCheckedState(const checkBox: TCheckBox; const check:
      boolean);
    procedure ExportGrid(sFileName, sFileExt: string);
    //function GetExportFileExt(const Exporter: TJvCustomDBGridExport): string;
    function GetExporterByFileExt(sFileExt: string;
      var Exporter: TJvCustomDBGridExport): string;

    { Private declarations }
  public
    //function ExtractRunAsLou: boolean;
    { Public declarations }
  end;

var
  WorkerThread: TWorkerThread;
  Form1: TForm1;
  iRunningTasks: integer;

implementation

uses
  frmExamples;

{$R *.dfm}

function DeleteLineBreaks(const S: string): string;
var
  Source, SourceEnd: PChar;
begin
  Source := Pointer(S);
  SourceEnd := Source + Length(S);
  while Source < SourceEnd do
  begin
    case Source^ of
      #10: Source^ := #32;
      #13: Source^ := #32;
    end;
    Inc(Source);
  end;
  Result := S;
end;

//function TForm1.ExtractRunAsLou(): boolean;
//var
//  sPath: string;
//begin
//  //
//  sPath := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
//  Result := mxstrg1.ExtractTo(sPath);
//end;

procedure TForm1.Exit1Click(Sender: TObject);
begin
  Close();
end;

procedure TForm1.ExtractRunAsLOU1Click(Sender: TObject);
var
  sPath: string;
begin
  //
  if
    (MessageDlg('Are you sure you want to extract RunAsLOU.exe to the program''s current directory?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
  begin
    Exit;
  end;

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

procedure TForm1.ThreadMessage(var Msg: TMessage);
var
  msg_prm: PWMUCommand;
  sResult: string;
begin
  //
  case Msg.WParam of
    WM_THRD_MSG:
      begin
        msg_prm := PWMUCommand(Msg.LParam);
        try
          JvMemoryData1.Append;
          try
            JvMemoryData1.FieldByName('Date').AsString := DateTimeToStr(Now);
            JvMemoryData1.FieldByName('Host').AsString := msg_prm.sComputer;
            //
            sResult := HexToString(msg_prm.sResult);
            JvMemoryData1.FieldByName('Result').AsString := 'Process started?: '
              +
              msg_prm.sSuccess + #13#10 + sResult;
            //
          finally
            JvMemoryData1.Post;
            InterlockedDecrement(iRunningTasks);
            StatusBar1.Panels[0].Text := 'Remaining tasks: ' +
              IntToStr(iRunningTasks);

            pb1.Step := Min(pb1.Step, pb1.Max - pb1.Position);
            //
            if iRunningTasks <= 0 then
            begin
              ScanDone();
              //cxGrid1DBTableView1.ApplyBestFit();
            end;
          end;
        finally
          Dispose(msg_prm);
        end;
      end;
  end;
end;

procedure TForm1.Usage1Click(Sender: TObject);
var
  frmUsage: TfrmUsageExamples;
begin
  //
  frmUsage := TfrmUsageExamples.Create(Self);
  try
    frmUsage.Position := poMainFormCenter;
    frmUsage.ShowModal;
  finally
    frmUsage.Release;
    Pointer(frmUsage) := nil;
  end;

end;

function TForm1.ValidateSelections(): boolean;
begin
  Result := False; //default

  if (not rbRunExistingRemote.Checked) and (not rbCopyRemote.Checked) then
  begin
    MessageDlg('Select one of the following:' + #13#10 +
      ' * Run command on the remote host' +
      #13#10 + ' * Copy file to remote host', mtError, [mbOK], 0);
    Exit;
  end;

  if Length(lblFileToRun.Text) < 1 then
  begin
    MessageDlg('You must provide a file!', mtError, [mbOK], 0);
    Exit;
  end;

  if MemoHosts.Lines.Count < 1 then
  begin
    MessageDlg('Click the ''Hosts'' tab and add 1 or more computers/IP addresses to target for deployment.',
      mtError, [mbOK], 0);
    Exit;
  end;

  Result := True;
end;

procedure TForm1.btnBeginDeployClick(Sender: TObject);
var
  i: integer;
  myCurTask: PWorkerThreadTask;
  sCurHost: string;
begin
  //
  if not ValidateSelections() then
    Exit;

  MAX_THREADS := StrToInt(seThreads.Text);

  if MAX_THREADS > MemoHosts.Lines.Count - 1 then
  begin
    MAX_THREADS := MemoHosts.Lines.Count;
  end;
  //
  iRunningTasks := 0;
  //
  for i := 0 to MemoHosts.Lines.Count - 1 do
  begin
    sCurHost := Trim(MemoHosts.Lines[i]);
    New(myCurTask);

    if cbUsername.Checked then
    begin
      myCurTask.sUser := Trim(edtUser.Text);
      myCurTask.sPass := lblPass.Text;
    end
    else
    begin
      myCurTask.sUser := '';
      myCurTask.sPass := '';
    end;

    myCurTask.bAlternateUser := cbUsername.Checked;
    myCurTask.sFileWithPath := Trim(lblFileToRun.Text);
    myCurTask.sCmdLine := Trim(lblCommandLineParams.Text);
    myCurTask.bCheckIfOnline := cbCheckIfAlive.Checked;
    myCurTask.bRunExistingRemoteCmd := rbRunExistingRemote.Checked;
    myCurTask.bCopyFileToRemote := rbCopyRemote.Checked;
    myCurTask.bOverwriteExisting := cbOverwriteExistingFile.Checked;
    myCurTask.bCopyOnlyIfNewer := cbCopyIfNewer.Checked;
    myCurTask.bDoNotLoadProfile := cbDontLoadProfile.Checked;
    myCurTask.bInteractDesktop := cbInteractDesktop.Checked;
    myCurTask.bRunAsSystem := cbSystemAcct.Checked;
    myCurTask.iThreadPriority := cbThreadPriority.ItemIndex;
    myCurTask.bDontWaitForTermination := cbDontWait.Checked;
    myCurTask.bSetConnectionTimeout := cbConnTimeout.Checked;
    myCurTask.iConnectTimeout := StrToInt(seTimeoutSeconds.Text);
    myCurTask.sComputer := sCurHost;

    if not Assigned(WorkerThread) then
      WorkerThread := TWorkerThread.Create(Self.Handle);

    WorkerThread.BeginWork(myCurTask);
    InterlockedIncrement(iRunningTasks);
  end;
  StatusBar1.Panels[0].Text := 'Remaining tasks: ' + IntToStr(iRunningTasks);
  //
  pb1.Position := 0;
  pb1.Min := 0;
  pb1.Max := iRunningTasks;
  pb1.Enabled := True;
  pb1.Visible := True;
  //
  Animate1.Active := True;
  Animate1.Visible := True;
  btnBeginDeploy.Enabled := False;
  btnCancel.Enabled := True;

end;

procedure TForm1.ExportGrid(sFileName, sFileExt: string);
var
  Exporter: TJvCustomDBGridExport;
begin
  GetExporterByFileExt(sFileExt, Exporter);

  Exporter.Grid := jvdbgrd1;
  sFileName := SaveDialog1.FileName;
  if not AnsiSameText(ExtractFileExt(sFileName), sFileExt) then
    sFileName := sFileName + sFileExt;

  Exporter.FileName := sFileName;

  try
    Exporter.ExportGrid;
  except
    on E: Exception do
  else
    raise; // Supressing strange OLE exception
  end;
end;

function TForm1.GetExporterByFileExt(sFileExt: string; var Exporter:
  TJvCustomDBGridExport): string;
begin
  //ExportGrid(TJvDBGridExcelExport);
  if SameText(sFileExt, '.xls') then
    Exporter := jvdbgrdcsvxprt1
  else if SameText(sFileExt, '.xml') then
    Exporter := jvdbgrdxmlxprt1
  else if SameText(sFileExt, '.csv') then
    Exporter := jvdbgrdcsvxprt1
  else if SameText(sFileExt, '.html') then
    Exporter := jvdbgrdhtmlxprt1;

end;

procedure TForm1.Saveas2Click(Sender: TObject);
var
  sExtension: string;
begin
  //
  if SaveDialog1.Execute then
  begin
    //ShowMessage('File : ' + SaveDialog1.FileName);
    sExtension := ExtractFileExt(SaveDialog1.Filename);

    ExportGrid(SaveDialog1.FileName, sExtension);
    //    //ExportGrid(TJvDBGridExcelExport);
    //    if SameText(sExtension, '.xls') then
    //      ExportGridToExcel(SaveDialog1.FileName, cxGrid1, True, True, True, 'xls')
    //    else if SameText(sExtension, '.xml') then
    //      ExportGridToXML(SaveDialog1.FileName, cxGrid1, True, True, 'xml')
    //        //mxDBGridExport1.ExportType := xtHTML
    //    else if SameText(sExtension, '.txt') then
    //      ExportGridToText(SaveDialog1.FileName, cxGrid1, True, True, '   ', '> ',
    //        ' <', 'txt')
    //        //mxDBGridExport1.ExportType := xtHTML
    //    else if SameText(sExtension, '.html') then
    //      ExportGridToHTML(SaveDialog1.FileName, cxGrid1, True, True, 'html');

  end
  else
  begin
    //ShowMessage('Save file was cancelled');
  end;
  //

end;

procedure TForm1.ScanDone();
begin
  uThrdAbortThreads.TAbortThreads.Create(Addr(WorkerThread)); //kill old threads
  Animate1.Active := False;
  Animate1.Visible := False;

  pb1.Position := 0;
  pb1.Enabled := False;
  pb1.Visible := False;

  btnBeginDeploy.Enabled := True;
  btnCancel.Enabled := False;
end;

procedure TForm1.btnCancelClick(Sender: TObject);
begin
  ScanDone();
end;

procedure TForm1.btnClearResultsClick(Sender: TObject);
begin
  JvMemoryData1.EmptyTable;
end;

procedure TForm1.btnBrowseClick(Sender: TObject);
var
  WinVistaPlus: Boolean;
  OpenDialog: TOpenDialog;
  FileOpenDialog1: TFileOpenDialog;
begin
  //  WinXP := CheckWin32Version(5, 1);
  WinVistaPlus := CheckWin32Version(6, 0);

  if WinVistaPlus then
  begin
    FileOpenDialog1 := TFileOpenDialog.Create(Self);

    with FileOpenDialog1 do
    begin
      Name := 'FileOpenDialog1';
      //FavoriteLinks := <>;
      with FileTypes.Add do
      begin
        DisplayName := 'Executable files';
        FileMask := '*.exe;*.bat;*.cmd;*.com';
      end;
      with FileTypes.Add do
      begin
        DisplayName := 'All Files';
        FileMask := '*';
      end;
      Options := [];
    end;

    // Display the open file dialog
    if FileOpenDialog1.Execute then
    begin
      lblFileToRun.Text := Trim(FileOpenDialog1.FileName);
    end
    else
    begin
      // cancelled
    end;
  end
  else
  begin

    OpenDialog := TOpenDialog.Create(Self);

    with OpenDialog do
    begin
      Name := 'OpenDialog';
      Filter := 'Executable files|*.exe;*.bat;*.cmd;*.com|All Files|*';
      Options := [ofHideReadOnly, ofEnableSizing, ofDontAddToRecent];
    end;

    // Display the open file dialog
    if OpenDialog.Execute then
    begin
      lblFileToRun.Text := Trim(OpenDialog.Files.Text);
    end
    else
    begin
      // cancelled
    end;
  end;

end;

procedure TForm1.cbCopyIfNewerClick(Sender: TObject);
begin

  if cbCopyIfNewer.Checked then
  begin
    cbOverwriteExistingFile.Enabled := False
  end
  else
  begin
    cbOverwriteExistingFile.Enabled := True;
  end;
end;

procedure TForm1.cbDontLoadProfileClick(Sender: TObject);
begin
  if cbDontLoadProfile.Checked then
    cbSystemAcct.Enabled := False
  else
    cbSystemAcct.Enabled := True;

end;

procedure TForm1.cbOverwriteExistingFileClick(Sender: TObject);
begin
  if cbOverwriteExistingFile.Checked then
    cbCopyIfNewer.Enabled := False
  else
    cbCopyIfNewer.Enabled := True;
end;

procedure TForm1.cbShowPasswdClick(Sender: TObject);
begin
  if cbShowPasswd.Checked then
    lblPass.PasswordChar := #0
  else
    lblPass.PasswordChar := '*';
end;

procedure TForm1.cbSystemAcctClick(Sender: TObject);
begin
  if cbSystemAcct.Checked then
    cbDontLoadProfile.Enabled := False
  else
    cbDontLoadProfile.Enabled := True;
end;

procedure TForm1.cbUsernameClick(Sender: TObject);
begin
  if cbUsername.Checked then
  begin
    //
    edtUser.Enabled := True;
    lblPass.Enabled := True;
    edtUser.Text := getCurrentUserAndDomain();
  end
  else
  begin
    //
    edtUser.Enabled := False;
    lblPass.Enabled := False;
    edtUser.Text := '';
  end;
end;

procedure TForm1.ClearResults1Click(Sender: TObject);
begin
  if
    (MessageDlg('Are you sure you want to clear the grid data?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
  begin
    Exit;
  end;

  JvMemoryData1.EmptyTable;
end;

procedure TForm1.Copytoclipboard1Click(Sender: TObject);
begin
  ShowMessage('not implemented');
  //  mxDBGridExport1.ExportType := xtClipboard;
  //  mxDBGridExport1.Execute;
  //  DBGrid1.Columns[0].Width := 100;
  //  //DBGrid1.Columns[1].Width := 150;
  //  DBGrid1.Columns[1].Width := 500;
end;

//procedure TForm1.cxGrid1DBTableView1GetCellHeight(
//  Sender: TcxCustomGridTableView; ARecord: TcxCustomGridRecord;
//  AItem: TcxCustomGridTableItem; ACellViewInfo: TcxGridTableDataCellViewInfo;
//  var AHeight: Integer);
//begin
//  //
//end;
//
//procedure TForm1.cxGrid1DBTableView1InitEditValue(Sender:
//  TcxCustomGridTableView; AItem:
//  TcxCustomGridTableItem; AEdit: TcxCustomEdit; var AValue: Variant);
//begin
//  if AEdit is TcxMemo then
//  begin
//    AEdit.EditValue := AValue;
//    if TcxMemo(AEdit).Lines.Count = 2 then
//      TcxMemo(AEdit).Properties.ScrollBars := ssVertical;
//
//    if TcxMemo(AEdit).Lines.Count >= 5 then
//      TcxMemo(AEdit).Properties.VisibleLineCount := 10;
//  end;
//end;

procedure TForm1.Downloadpsexectocurrentdirectory1Click(Sender: TObject);
var
  asDownloadFile: IAsyncCall;
  fs: TFileStream;
  i: integer;
  sFileType: string;
  B: Byte;
begin
  //

  UseLatestCommonDialogs := False;
  if
    (MessageDlg('Are you sure you want to download psexec to the program''s current directory?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
  begin
    Exit;
  end;

  asDownloadFile := AsyncCall(@GetInetFile, [
    'http://live.sysinternals.com/psexec.exe', 'psexec.exe']);

  while AsyncMultiSync([asDownloadFile], True, 10) = WAIT_TIMEOUT do
    Application.ProcessMessages;

  fs := TFileStream.Create('psexec.exe', fmOpenRead);
  try
    fs.Position := 0;
    for i := 1 to 2 do
    begin
      fs.Read(B, 1);
      sFileType := SysUtils.UpperCase(sFileType + Format('%2.2x', [B]));
    end;
  finally
    FreeAndNil(fs);
  end;

  if sFileType = '4D5A' then
    //if FileExists('psexec.exe') then
  begin
    MessageDlg('Done!', mtInformation, [mbOK], 0);
  end
  else
  begin
    MessageDlg('There was a problem downloading psexec to the current directory.'
      + #13#10
      +
      ' Verify your internet connectivity, firewall settings, and that you have access to write to the current directory.',
      mtError, [mbOK], 0);
  end;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Form1.Caption := Form1.Caption + ' - v' + GetShortBuildInfoAsString();
  seThreads.Text := '4';

end;

procedure TForm1.FormShow(Sender: TObject);
begin
  //edtUser.Text := getCurrentUserAndDomain();
end;

procedure TForm1.Help1Click(Sender: TObject);
begin
  MessageDlg('v' + GetShortBuildInfoAsString() + #13#10 +
    'If you have questions about PsExec, please refer to the PsTools help file available online here:'
    + #13#10 + '' + #13#10 + 'http://live.sysinternals.com/Pstools.chm' + #13#10
    + '' +
    #13
    + #10 + '' + #13#10 + 'This program was written by Mick Grove' +
    #13#10 + '' + #13#10 + 'https://github.com/micksmix',
    mtInformation,
    [mbOK], 0);
end;

procedure TForm1.jvdbgrd1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  pt: TGridCoord;
begin
  pt := jvdbgrd1.MouseCoord(x, y);

  if pt.y = 0 then
    jvdbgrd1.Cursor := crHandPoint
  else
    jvdbgrd1.Cursor := crDefault;
end;

procedure TForm1.MemoHostsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = Ord('A')) and (ssCtrl in Shift) then
  begin
    TMemo(Sender).SelectAll;
    Key := 0;
  end;
end;

procedure TForm1.rbCopyRemoteClick(Sender: TObject);
begin
  if not rbCopyRemote.Checked then
  begin
    cbOverwriteExistingFile.Enabled := False;
    cbCopyIfNewer.Enabled := False;
    AnimateWindow(pnlCopyFileOptions.Handle, 200, AW_VER_NEGATIVE or AW_SLIDE or
      AW_HIDE);
  end
  else
  begin
    cbOverwriteExistingFile.Enabled := True;
    cbCopyIfNewer.Enabled := True;

    SetCheckboxCheckedState(cbOverwriteExistingFile, False);
    SetCheckboxCheckedState(cbCopyIfNewer, False);

    lblFileToRun.EditLabel.Caption := 'File to copy and execute:';
    pnlCopyFileOptions.Visible := True;
    pnlCopyFileOptions.DoubleBuffered := False;
    pnlParamBox.DoubleBuffered := False;
    AnimateWindow(pnlParamBox.Handle, 200, AW_VER_NEGATIVE or AW_SLIDE or
      AW_HIDE);

    Sleep(200);
    AnimateWindow(pnlCopyFileOptions.Handle, 200, AW_VER_POSITIVE or AW_SLIDE);
    pnlCopyFileOptions.DoubleBuffered := True;
    pnlParamBox.DoubleBuffered := True;

  end;
end;

procedure TForm1.SetCheckboxCheckedState(const checkBox: TCheckBox; const check:
  boolean);
var
  onClickHandler: TNotifyEvent;
begin
  with checkBox do
  begin
    onClickHandler := OnClick;
    OnClick := nil;
    Checked := check;
    OnClick := onClickHandler;
  end;
end;

procedure TForm1.seThreadsChange(Sender: TObject);
begin
  //
  if seThreads.Value < 1 then
  begin
    seThreads.Text := '4';
  end;
end;

procedure TForm1.seThreadsExit(Sender: TObject);
begin
  //
  if seThreads.Value < 1 then
  begin
    seThreads.Text := '4';
  end;
end;

procedure TForm1.seThreadsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  //
  if seThreads.Value < 1 then
  begin
    seThreads.Text := '4';
  end;
end;

procedure TForm1.rbRunExistingRemoteClick(Sender: TObject);
begin
  if rbRunExistingRemote.Checked then
  begin
    cbOverwriteExistingFile.Enabled := False;
    cbCopyIfNewer.Enabled := False;

    SetCheckboxCheckedState(cbOverwriteExistingFile, False);
    SetCheckboxCheckedState(cbCopyIfNewer, False);

    lblFileToRun.EditLabel.Caption := 'Path to file on remote host:';

    pnlCopyFileOptions.DoubleBuffered := False;
    pnlParamBox.DoubleBuffered := False;
    AnimateWindow(pnlCopyFileOptions.Handle, 200, AW_VER_NEGATIVE or AW_SLIDE or
      AW_HIDE);

    pnlParamBox.Visible := True;
    Sleep(200);
    AnimateWindow(pnlParamBox.Handle, 200, AW_VER_POSITIVE or AW_SLIDE);
    pnlCopyFileOptions.DoubleBuffered := True;
    pnlParamBox.DoubleBuffered := True;
  end
  else
  begin
    cbOverwriteExistingFile.Enabled := True;
    cbCopyIfNewer.Enabled := True;
  end;
end;

end.

