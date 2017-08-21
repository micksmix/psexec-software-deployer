unit uWorkerThread;

interface

uses
  Classes,
  SysUtils,
  Windows,
  uHelpers,
  IdGlobal,
  IdUDPClient,
  IdException,
  Variants,
  ActiveX,
  ComObj,
  StrUtils,
  ThreadUtilities;

type
  TWorkerThread = class(TObject) //class(TThread)
  strict private
    FFormHandle: THandle;
    FThreadPool: TThreadPool;
  private
    procedure PrepareThreadVars;
    procedure ExecuteWork(Data: Pointer; AThread: TThread);
    procedure UpdateCaption;
    //    function ExecuteCommand(CommandLine: string): string;
    function HostAlive(sAddress: string): Boolean;
    procedure PrepareCommandLine;
    //    function GetConsoleOutput(const Command: string;
    //      var Output: TStringList): Boolean;
    procedure ReadTempFile(var slOutput: TStringList; sTempFilename: string);
    procedure WmiDeleteFile(const FileName, WbemComputer, WbemUser,
      WbemPassword: string);
    function WmiGetWindowsFolder(const WbemComputer, WbemUser,
      WbemPassword: string): string;
    procedure WmiStopAndDeleteService(const sService, WbemComputer, WbemUser,
      WbemPassword: string);
    { Private declarations }
  public
    procedure BeginWork(athrdtask: PWorkerThreadTask);
    constructor Create(formHandle: THandle);
    destructor Destroy; override;
  end;

threadvar
  FCurThreadTask              : PWorkerThreadTask;
  FHostname                   : string;
  FPsexecCmd                  : string;
  FCommandOutput              : string;
  FSuccess                    : string;
  FErrorCode                  : string;
  mOutputs, mCommand          : string;

implementation

procedure TWorkerThread.PrepareThreadVars();
begin
  FHostname := '';
end;

constructor TWorkerThread.Create(formHandle: THandle);
begin
  FFormHandle := formHandle;
  FThreadPool := TThreadPool.Create(ExecuteWork, MAX_THREADS); //MAX_PV_THREADS);

  inherited Create;
end;

destructor TWorkerThread.Destroy;
begin
  FThreadPool.Free;
  inherited;
end;

procedure TWorkerThread.ReadTempFile(var slOutput: TStringList; sTempFilename: string);
var
  fsReadOutput                : TFileStream;
begin
  //ExecuteCommand(FPsexecCmd);
  //GetConsoleOutput(FPsexecCmd, slOutput);
  //FCommandOutput := slOutput.Text;
  if FileExists(sTempFilename) then
  begin
    fsReadOutput := TFileStream.Create(sTempFilename, fmShareDenyNone);
    try
      slOutput.LoadFromStream(fsReadOutput);

    finally
      FreeAndNil(fsReadOutput);
    end;
  end;
end;

procedure TWorkerThread.BeginWork(athrdtask: PWorkerThreadTask);
begin
  FThreadPool.Add(athrdtask);
end;

procedure TWorkerThread.WmiStopAndDeleteService(const sService, WbemComputer, WbemUser,
  WbemPassword: string);
var
  FSWbemLocator               : OLEVariant;
  FWMIService                 : OLEVariant;
  FWbemObjectSet              : OLEVariant;
  FOutParams                  : OLEVariant;
begin
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService := FSWbemLocator.ConnectServer(WbemComputer, 'root\CIMV2', WbemUser,
    WbemPassword);
  FWbemObjectSet := FWMIService.Get('Win32_Service.Name="' + sService + '"');
  FWbemObjectSet.StopService();
  Sleep(500);
  Sleep(500);
  Sleep(500);
  Sleep(500);
  Sleep(500);
  Sleep(500);
  FWbemObjectSet.Delete();
end;

function TWorkerThread.WmiGetWindowsFolder(const WbemComputer, WbemUser, WbemPassword:
  string): string;
var
  FSWbemLocator               : OLEVariant;
  FWMIService                 : OLEVariant;
  FWbemObject                 : OLEVariant;
begin
  Result := ''; //default
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService := FSWbemLocator.ConnectServer(WbemComputer, 'root\CIMV2', WbemUser,
    WbemPassword);
  FWbemObject := FWMIService.Get('Win32_OperatingSystem=@');
  Result := ExcludeTrailingPathDelimiter(Format('%s',
    [string(FWbemObject.WindowsDirectory)]));

  //  Result := ''; //default
  //  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  //  FWMIService := FSWbemLocator.ConnectServer(WbemComputer, 'root\CIMV2', WbemUser,
  //    WbemPassword);
  //  FWbemObjectSet :=
  //    FWMIService.ExecQuery('SELECT WindowsDirectory FROM Win32_OperatingSystem', 'WQL',
  //    wbemFlagForwardOnly);
  //  oEnum := IUnknown(FWbemObjectSet._NewEnum) as IEnumVariant;
  //  while oEnum.Next(1, FWbemObject, iValue) = 0 do
  //  begin
  //    Result := ExcludeTrailingPathDelimiter(Format('%s',
  //      [string(FWbemObject.WindowsDirectory)]));
  //    // String
  //
  //    FWbemObject := Unassigned;
  //  end;

end;

procedure TWorkerThread.WmiDeleteFile(const FileName, WbemComputer, WbemUser,
  WbemPassword:
  string);
var
  FSWbemLocator               : OLEVariant;
  FWMIService                 : OLEVariant;
  FWbemObjectSet              : OLEVariant;
  FOutParams                  : OLEVariant;
begin
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService := FSWbemLocator.ConnectServer(WbemComputer, 'root\CIMV2', WbemUser,
    WbemPassword);
  FWbemObjectSet := FWMIService.Get(Format('CIM_DataFile.Name="%s"',
    [StringReplace(FileName,
      '\', '\\', [rfReplaceAll])]));
  FOutParams := FWbemObjectSet.Delete();

end;

procedure TWorkerThread.UpdateCaption();
var
  msg_prm                     : PWMUCommand;
begin
  New(msg_prm);
  msg_prm.sComputer := FHostname;
  msg_prm.sResult := FCommandOutput;
  msg_prm.sErrorCode := FErrorCode;
  msg_prm.sSuccess := FSuccess; // + ' --- ' + BoolToStr(Length(FCommandOutput) > 0);

  if not PostMessage(FFormHandle, WM_POSTED_MSG, WM_THRD_MSG, integer(msg_prm)) then
  begin
    Sleep(35);
    PostMessage(FFormHandle, WM_POSTED_MSG, WM_THRD_MSG, integer(msg_prm));
    if not PostMessage(FFormHandle, WM_POSTED_MSG, WM_THRD_MSG, integer(msg_prm)) then
    begin
      Sleep(35);
      PostMessage(FFormHandle, WM_POSTED_MSG, WM_THRD_MSG, integer(msg_prm));
    end;
  end;
end;

function TWorkerThread.HostAlive(sAddress: string): Boolean;
const
  NB_REQUEST                  = #$A2#$48#$00#$00#$00#$01#$00#$00 +
    #$00#$00#$00#$00#$20#$43#$4B#$41 +
    #$41#$41#$41#$41#$41#$41#$41#$41 +
    #$41#$41#$41#$41#$41#$41#$41#$41 +
    #$41#$41#$41#$41#$41#$41#$41#$41 +
    #$41#$41#$41#$41#$41#$00#$00#$21 +
    #$00#$01;

  NB_PORT                     = 137;
  NB_BUFSIZE                  = 8192;
var
  Buffer                      : TIdBytes;
  UDPClient                   : TIdUDPClient;
  bResult                     : boolean;
begin

  if (sAddress = '127.0.0.1') or (SameText(sAddress, 'localhost')) then
  begin
    Result := True;
    Exit;
  end;

  bResult := False;
  UDPClient := nil;

  try
    UDPClient := TIdUDPClient.Create(nil);
    UDPClient.Host := Trim(sAddress);
    UDPClient.Port := NB_PORT;
    SetLength(Buffer, NB_BUFSIZE);

    UDPClient.Send(NB_REQUEST);

    if (0 < UDPClient.ReceiveBuffer(Buffer, 5000)) then
    begin
      bResult := True;
    end;
  except
    on E: EIdSocketHandleError do
    begin
      // do nothing
    end;
    on E: Exception do
    begin
      begin
        FCommandOutput := StringToHex(E.Message);
        Result := False;
      end;
    end;

  end;

  if Assigned(UDPClient) then
    FreeAndNil(UDPClient);

  Result := bResult;
end;

procedure TWorkerThread.PrepareCommandLine;
var
  sWorkDir                    : string;
  sFile                       : string;
  sEscapedPass                : string;
  bFileAdded                  : boolean;
  idx                         : integer;
begin
  //

  bFileAdded := False;
  FPsexecCmd := '\\' + FCurThreadTask.sComputer;

  if FCurThreadTask.bAlternateUser then
  begin

    //lets add CMD supported escape character (^) for every character in password
    for idx := 1 to Length(FCurThreadTask.sPass) do
    begin
      sEscapedPass := sEscapedPass + '^' + FCurThreadTask.sPass[idx];
    end;

    FPsexecCmd := FPsexecCmd + ' -u ' + FCurThreadTask.sUser + ' -p ' + sEscapedPass;
  end;

  if FCurThreadTask.bSetConnectionTimeout then
    FPsexecCmd := FPsexecCmd + ' -n ' + IntToStr(FCurThreadTask.iConnectTimeout);

  if FCurThreadTask.bRunAsSystem then
    FPsexecCmd := FPsexecCmd + ' -s';

  if FCurThreadTask.bDoNotLoadProfile then
    FPsexecCmd := FPsexecCmd + ' -e';

  sWorkDir := ExtractFilePath(FCurThreadTask.sFileWithPath);
  sFile := ExtractFileName(FCurThreadTask.sFileWithPath);
  //FPsexecCmd := FPsexecCmd + ' -w ' + sWorkDir;

  if FCurThreadTask.bInteractDesktop then
    FPsexecCmd := FPsexecCmd + ' -i';

  if FCurThreadTask.bCopyFileToRemote then
  begin

    if FCurThreadTask.bOverwriteExisting then
      FPsexecCmd := FPsexecCmd + ' -f'
    else if FCurThreadTask.bCopyOnlyIfNewer then
      FPsexecCmd := FPsexecCmd + ' -v';

    FPsexecCmd := FPsexecCmd + ' -c ' + FCurThreadTask.sFileWithPath;
    bFileAdded := True;
  end;

  if FCurThreadTask.bDontWaitForTermination then
    FPsexecCmd := FPsexecCmd + ' -d';

  if TPriority(FCurThreadTask.iThreadPriority) <> tpnormal then
  begin
    case TPriority(FCurThreadTask.iThreadPriority) of
      tplow: FPsexecCmd := FPsexecCmd + ' -low';
      tpbelownormal: FPsexecCmd := FPsexecCmd + ' -belownormal';
      tpabovenormal: FPsexecCmd := FPsexecCmd + ' -abovenormal';
      tphigh: FPsexecCmd := FPsexecCmd + ' -high';
      tprealtime: FPsexecCmd := FPsexecCmd + ' -realtime';
    end;
  end;

  {   -priority  Specifies -low, -belownormal, -abovenormal, -high or
                -realtime to run the process at a different priority. Use
                -background to run at low memory and I/O priority on Vista.
  }

  //if FCurThreadTask.bRunExistingRemoteCmd then
  //begin
  if Length(FCurThreadTask.sCmdLine) > 0 then
  begin
    if not bFileAdded then
      FPsexecCmd := FPsexecCmd + ' ' + FCurThreadTask.sFileWithPath + ' ' +
        FCurThreadTask.sCmdLine
    else
      FPsexecCmd := FPsexecCmd + ' ' + FCurThreadTask.sCmdLine
  end
  else
  begin
    if not bFileAdded then
      FPsexecCmd := FPsexecCmd + ' ' + FCurThreadTask.sFileWithPath;
  end;

end;

procedure TWorkerThread.ExecuteWork(Data: Pointer; AThread: TThread);
var
  FoundMatch                  : Boolean;
  slOutput                    : TStringList;
  sTempFilename               : string;
  iResult                     : Cardinal;
  sWinFolder                  : string;
  bTryAgain                   : boolean;
  //Regex             : TPerlRegEx;
begin
  { Place thread code here }
  bTryAgain := False;
  //
  New(FCurThreadTask);
  try
    PrepareThreadVars();

    FCurThreadTask.bAlternateUser := TWorkerThreadTask(Data^).bAlternateUser;
    FCurThreadTask.sUser := TWorkerThreadTask(Data^).sUser;
    FCurThreadTask.sPass := TWorkerThreadTask(Data^).sPass;
    FCurThreadTask.sFileWithPath := Trim(TWorkerThreadTask(Data^).sFileWithPath);
    FCurThreadTask.sCmdLine := Trim(TWorkerThreadTask(Data^).sCmdLine);
    FCurThreadTask.bCheckIfOnline := TWorkerThreadTask(Data^).bCheckIfOnline;
    FCurThreadTask.bRunExistingRemoteCmd :=
      TWorkerThreadTask(Data^).bRunExistingRemoteCmd;
    FCurThreadTask.bCopyFileToRemote := TWorkerThreadTask(Data^).bCopyFileToRemote;
    FCurThreadTask.bOverwriteExisting := TWorkerThreadTask(Data^).bOverwriteExisting;
    FCurThreadTask.bCopyOnlyIfNewer := TWorkerThreadTask(Data^).bCopyOnlyIfNewer;
    FCurThreadTask.bDoNotLoadProfile := TWorkerThreadTask(Data^).bDoNotLoadProfile;
    FCurThreadTask.bInteractDesktop := TWorkerThreadTask(Data^).bInteractDesktop;
    FCurThreadTask.bRunAsSystem := TWorkerThreadTask(Data^).bRunAsSystem;
    FCurThreadTask.iThreadPriority := TWorkerThreadTask(Data^).iThreadPriority;
    FCurThreadTask.bDontWaitForTermination :=
      TWorkerThreadTask(Data^).bDontWaitForTermination;
    FCurThreadTask.bSetConnectionTimeout :=
      TWorkerThreadTask(Data^).bSetConnectionTimeout;
    FCurThreadTask.iConnectTimeout := TWorkerThreadTask(Data^).iConnectTimeout;
    FCurThreadTask.sComputer := TWorkerThreadTask(Data^).sComputer;

    FHostname := FCurThreadTask.sComputer;
    FCommandOutput := StringToHex('-'); //default
    FErrorCode := '-'; //default
    FSuccess := 'False'; //default

    if FCurThreadTask.bCheckIfOnline then
    begin
      if not HostAlive(FHostname) then
      begin
        FCommandOutput := StringToHex('Host offline');
        UpdateCaption;
        Exit;
      end;
    end;

    PrepareCommandLine();

    if not FCurThreadTask.bAlternateUser then
    begin
      UninstallPsexecService(FHostname);
    end;

    sTempFilename := MgGetTempFileName('psexec', '');
    FPsexecCmd := ReplaceText(FPsexecCmd, '"', '"""');

    FPsexecCmd := 'cmd.exe /c "psexec ' + FPsexecCmd + ' >' + sTempFilename + '"';

    slOutput := TStringList.Create;
    try
      iResult := StartApp(FPsexecCmd, '', True);
      if iResult = 0 then
      begin
        FSuccess := 'Success: ' + SysErrorMessage(iResult);
      end
      else
      begin
        FSuccess := 'Error: ' + SysErrorMessage(iResult);

        if ContainsText(FSuccess, 'The handle is invalid') then
        begin
          //
          FSuccess := FSuccess +
            ' --- Make sure that the default admin$ share is enabled';
        end;

        if ContainsText(FSuccess, 'requires a newer version of Windows') then
        begin
          try
            CoInitialize(nil);
            try
              try
                begin
                  sWinFolder := WmiGetWindowsFolder(FHostname, FCurThreadTask.sUser,
                    FCurThreadTask.sPass);

                  if Length(sWinFolder) > 0 then
                  begin
                    WmiStopAndDeleteService('psexesvc', FHostname, FCurThreadTask.sUser,
                      FCurThreadTask.sPass);

                    WmiDeleteFile(sWinFolder + '\psexesvc.exe', FHostname,
                      FCurThreadTask.sUser,
                      FCurThreadTask.sPass);
                  end;
                end;
              except
                on E: EOleException do
                  FSuccess := FSuccess + ' --- ' + (Format('%s %x', [E.Message,
                    E.ErrorCode]));
                on E: Exception do
                  FSuccess := FSuccess + ' --- ' + (E.Classname + ':' + E.Message);
              end;
            finally
              CoUninitialize;
            end;
          except
            on E: EOleException do
              OutputDebugString(PChar(Format('EOleException %s %x', [E.Message,
                E.ErrorCode])));
            on E: Exception do
              OutputDebugString(PChar(E.Classname + ':' + E.Message));
          end;
          bTryAgain := True;

        end;

        if bTryAgain then
        begin
          iResult := StartApp(FPsexecCmd, '', True);
          if iResult = 0 then
          begin
            FSuccess := 'Success: ' + SysErrorMessage(iResult);
          end
          else
          begin
            FSuccess := 'Error: ' + SysErrorMessage(iResult);
          end;
        end;

      end;
      //MgExecute(FPsexecCmd, SW_NORMAL, '', True);
      ReadTempFile(slOutput, sTempFilename);
      FCommandOutput := StringToHex(slOutput.Text);

    finally
      FreeAndNil(slOutput);
    end;

    if FileExists(sTempFilename) then
    begin
      DeleteFile(PChar(sTempFilename));
    end;

    UpdateCaption;
  finally
    Dispose(FCurThreadTask);
  end;
end;

end.

