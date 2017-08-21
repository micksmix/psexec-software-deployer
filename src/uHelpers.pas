unit uHelpers;

interface

uses
  WinSvc,
  Windows,
  Messages,
  WinInet,
  SysUtils,
  SHFolder,
  uMiniReg;

const
  WM_THRD_SITE_MSG            = WM_USER + 5;
  WM_POSTED_MSG               = WM_USER + 8;
  WM_THRD_MSG                 = WM_USER + 9;

var
  MAX_THREADS                 : integer = 4;

type
  PTokenUser = ^TTokenUser;
  _TOKEN_USER = record
    User: TSIDAndAttributes;
  end;
  TTokenUser = _TOKEN_USER;

type
  TPriority = (tplow = 0, tpbelownormal, tpnormal, tpabovenormal, tphigh, tprealtime);

  PWorkerThreadTask = ^TWorkerThreadTask;

  TWorkerThreadTask = record
    //hMainForm: THandle;
    bAlternateUser: boolean;
    sUser: string;
    sPass: string;
    sFileWithPath: string;
    sCmdLine: string;
    bRunExistingRemoteCmd: boolean;
    bCopyFileToRemote: boolean;
    bOverwriteExisting: boolean;
    bCopyOnlyIfNewer: boolean;
    bDoNotLoadProfile: boolean;
    bInteractDesktop: boolean;
    bRunAsSystem: boolean;
    iThreadPriority: integer;
    bDontWaitForTermination: boolean;
    bSetConnectionTimeout: boolean;
    iConnectTimeout: integer;
    bCheckIfOnline: boolean;
    sComputer: string;
  end;

type
  PWMUCommand = ^TWMUCommand;

  TWMUCommand = record
    sComputer: string;
    sResult: string;
    sErrorCode: string;
    sSuccess: string;
  end;

procedure UninstallPsexecService(MachineName: string);
function MgGetUserName: string;
procedure AcceptLocalPsexecEula();
function getCurrentUserAndDomain(): string;
function GetInetFile(const fileURL, FileName: string): boolean; cdecl;
function MgGetTempFileName(const prefix, tempPath: string): string;
//function MgExecute(const commandLine: string; visibility: integer; const workDir: string;
//  wait: boolean): cardinal;
function StartApp(const sCmdLine, CurDir: string; wait: boolean): Cardinal;
function GetSpecialFolderPath(folder: integer): string;
function MgGetWindowsFolder: string;
function GetShortBuildInfoAsString: string;
function HexToString(aHex: string): string;
function StringToHex(const S: string): string;
function DeleteLineBreaks(const S: string): string;

implementation

function CreateEnvironmentBlock(var lpEnvironment: Pointer; hToken: THandle; bInherit:
  BOOL): BOOL; stdcall; external 'userenv';

function DestroyEnvironmentBlock(pEnvironment: Pointer): BOOL; stdcall; external
'userenv';

function GetEnvVarValue(const VarName: string): string;
var
  BufSize                     : Integer; // buffer size required for value
begin
  // Get required buffer size (inc. terminal #0)
  BufSize := GetEnvironmentVariable(
    PChar(VarName), nil, 0);
  if BufSize > 0 then
  begin
    // Read env var value into result string
    SetLength(Result, BufSize - 1);
    GetEnvironmentVariable(PChar(VarName),
      PChar(Result), BufSize);
  end
  else
    // No such environment variable
    Result := '';
end;

function DeleteLineBreaks(const S: string): string;
var
  Source, SourceEnd           : PChar;
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

function TransChar(AChar: Char): Integer;
begin
  if AChar in ['0'..'9'] then
    Result := Ord(AChar) - Ord('0')
  else
    Result := 10 + Ord(AChar) - Ord('A');
end;

function HexToString(aHex: string): string;
var
  I                           : Integer;
  CharValue                   : Word;
begin
  Result := '';
  for I := 1 to Trunc(Length(aHex) / 2) do
  begin
    Result := Result + ' ';
    CharValue := TransChar(aHex[2 * I - 1]) * 16 + TransChar(aHex[2 * I]);
    Result[I] := Char(CharValue);
  end;
end;

function StringToHex(const S: string): string;
var
  Index                       : Integer;
begin
  Result := '';
  for Index := 1 to Length(S) do
    Result := Result + IntToHex(Byte(S[Index]), 2);
end;

procedure GetBuildInfo(var V1, V2, V3, V4: word);
var
  VerInfoSize, VerValueSize, Dummy: DWORD;
  VerInfo                     : Pointer;
  VerValue                    : PVSFixedFileInfo;
begin
  VerInfoSize := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
  GetMem(VerInfo, VerInfoSize);
  try
    GetFileVersionInfo(PChar(ParamStr(0)), 0, VerInfoSize, VerInfo);
    VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
    with VerValue^ do
    begin
      V1 := dwFileVersionMS shr 16;
      V2 := dwFileVersionMS and $FFFF;
      V3 := dwFileVersionLS shr 16;
      V4 := dwFileVersionLS and $FFFF;
    end;
  finally
    FreeMem(VerInfo, VerInfoSize);
  end;
end;

function GetBuildInfoAsString: string;
var
  V1, V2, V3, V4              : word;
begin
  GetBuildInfo(V1, V2, V3, V4);
  Result := IntToStr(V1) + '.' + IntToStr(V2) + '.' + IntToStr(V3)
    + '.' + IntToStr(V4);
end;

function GetShortBuildInfoAsString: string;
var
  V1, V2, V3, V4              : word;
begin
  GetBuildInfo(V1, V2, V3, V4);
  Result := IntToStr(V1) + '.' + IntToStr(V2) + '.' + IntToStr(V3);
  //+ '.' + IntToStr(V4);
end;

function GetSpecialFolderPath(folder: integer): string;
const
  SHGFP_TYPE_CURRENT          = 0;
var
  path                        : array[0..MAX_PATH] of char;
begin
  if SUCCEEDED(SHGetFolderPath(0, folder, 0, SHGFP_TYPE_CURRENT, @path[0])) then
    Result := ExcludeTrailingPathDelimiter(path)
  else
    Result := '';

  //  [Current User]\My Documents
  //  0: specialFolder := CSIDL_PERSONAL;
  //
  //  All Users\Application Data
  //  1: specialFolder := CSIDL_COMMON_APPDATA;
  //
  //  [User Specific]\Application Data
  //  2: specialFolder := CSIDL_LOCAL_APPDATA;
  //
  //  Program Files
  //  3: specialFolder := CSIDL_PROGRAM_FILES;
  //
  //  All Users\Documents
  //  4: specialFolder := CSIDL_COMMON_DOCUMENTS;

end;

function MgGetWindowsFolder: string;
var
  path                        : PChar;
begin
  GetMem(path, MAX_PATH * SizeOf(char));
  try
    if GetWindowsDirectory(path, MAX_PATH * SizeOf(char)) <> 0 then
      Result := StrPas(path)
    else
      Result := '';
  finally FreeMem(path);
  end;
end; { DSiGetWindowsFolder }

function StartApp(const sCmdLine, CurDir: string; wait: boolean): Cardinal;
var
  StartupInfo                 :
{$IFDEF UNICODE}TStartupInfoW{$ELSE}TStartupInfoA{$ENDIF};
  ProcInfo                    : TProcessInformation;
  pEnv                        : Pointer;
  pCurDir, pCmdLine           : PChar;
begin
  ZeroMemory(@StartupInfo, sizeof(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.lpDesktop := 'winsta0\default';
  CreateEnvironmentBlock(pEnv, 0, true);

  try
    pCmdLine := PChar(sCmdLine);

    //    if Length(Parameters) > 0 then
    //      pCmdLine := PChar('"' + App + '" ' + Parameters)
    //    else
    //      pCmdLine := PChar('"' + App + '" ');

    pCurDir := nil;

    if Length(CurDir) > 0 then
      pCurDir := PChar(CurDir);

    //    if not CreateProcess(nil, PChar(commandLine), nil, nil, false,
    //      CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil,
    //      PChar(useWorkDir), startupInfo, processInfo) then

    if not
{$IFDEF UNICODE}CreateProcessW{$ELSE}CreateProcessA{$ENDIF}(
      nil, //PChar(App), //__in_opt     LPCTSTR lpApplicationName,
      pCmdLine, //__inout_opt  LPTSTR lpCommandLine,
      nil, //__in_opt     LPSECURITY_ATTRIBUTES lpProcessAttributes,
      nil, //__in_opt     LPSECURITY_ATTRIBUTES lpThreadAttributes,
      true, //__in         BOOL bInheritHandles,
      CREATE_NEW_CONSOLE or CREATE_UNICODE_ENVIRONMENT,
      //__in         DWORD dwCreationFlags,
      pEnv, //__in_opt     LPVOID lpEnvironment,
      pCurDir, //__in_opt     LPCTSTR lpCurrentDirectory,
      StartupInfo, //__in         LPSTARTUPINFO lpStartupInfo,
      ProcInfo //__out        LPPROCESS_INFORMATION lpProcessInformation
      ) then
    begin
      Result := MaxInt;
      raiseLastOsError;
    end
    else
    begin
      if wait then
      begin
        WaitForSingleObject(ProcInfo.hProcess, INFINITE);
        GetExitCodeProcess(ProcInfo.hProcess, Result);
      end
      else
        Result := 0;
    end;
  finally
    DestroyEnvironmentBlock(pEnv);
  end;
  CloseHandle(ProcInfo.hProcess);
  CloseHandle(ProcInfo.hThread);
end;

//function MgExecute(const commandLine: string; visibility: integer; const workDir: string;
//  wait: boolean)
//var
//  processInfo                 : TProcessInformation;
//  startupInfo                 : TStartupInfo;
//  useWorkDir                  : string;
//begin
//  if workDir = '' then
//    GetDir(0, useWorkDir)
//  else
//    useWorkDir := workDir;
//
//  FillChar(startupInfo, SizeOf(startupInfo), #0);
//  startupInfo.cb := SizeOf(startupInfo);
//  startupInfo.dwFlags := STARTF_USESHOWWINDOW;
//  startupInfo.wShowWindow := visibility;
//
//  //CreateEnvironmentBlock(@pEnv, 0, true);
//
//  if not CreateProcess(nil, PChar(commandLine), nil, nil, false,
//    CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil,
//    PChar(useWorkDir), startupInfo, processInfo) then
//    Result := MaxInt
//  else
//  begin
//    if wait then
//    begin
//      WaitForSingleObject(processInfo.hProcess, INFINITE);
//      GetExitCodeProcess(processInfo.hProcess, Result);
//    end
//    else
//      Result := 0;
//
//    CloseHandle(processInfo.hProcess);
//    CloseHandle(processInfo.hThread);
//  end;
//end; { DSiExecute }

function MgGetTempPath: string;
var
  bufSize                     : DWORD;
  tempPath                    : PChar;
begin
  bufSize := GetTempPath(0, nil);
  GetMem(tempPath, bufSize * SizeOf(char));
  try
    GetTempPath(bufSize, tempPath);
    Result := tempPath;
  finally FreeMem(tempPath);
  end;
end;

//Returns temporary file name, either in the specified path or in the default temp path

function MgGetTempFileName(const prefix, tempPath: string): string;
var
  tempFileName                : PChar;
  usePrefix                   : string;
  useTempPath                 : string;
begin
  Result := '';
  GetMem(tempFileName, MAX_PATH * SizeOf(char));
  try
    if tempPath = '' then
      useTempPath := MgGetTempPath
    else
    begin
      useTempPath := tempPath;
      UniqueString(useTempPath);
    end;
    usePrefix := prefix;
    UniqueString(usePrefix); //Ensures that a given string has a reference count of one.
    if GetTempFileName(PChar(useTempPath), PChar(usePrefix), 0, tempFileName) <> 0 then
      Result := tempFileName
    else
      Result := '';
  finally
    FreeMem(tempFileName);
  end;
end;

function GetInetFile(const fileURL, FileName: string): boolean; cdecl;
const
  BufferSize                  = 1024;
var
  hSession, hURL              : HInternet;
  Buffer                      : array[1..BufferSize] of Byte;
  BufferLen                   : DWORD;
  f                           : file;
  sAppName                    : string;
begin
  result := false;
  sAppName := ('PsExecSoftwareDeploy');

  hSession := InternetOpen(PChar(sAppName), INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  try
    hURL := InternetOpenURL(hSession, PChar(fileURL), nil, 0, 0, 0);
    try
      AssignFile(f, FileName);
      Rewrite(f, 1);
      repeat
        InternetReadFile(hURL, @Buffer, SizeOf(Buffer), BufferLen);
        BlockWrite(f, Buffer, BufferLen)
      until BufferLen = 0;
      CloseFile(f);
      result := True;
    finally
      InternetCloseHandle(hURL)
    end
  finally
    InternetCloseHandle(hSession)
  end
end;

function MgGetComputerName: string;
var
  buffer                      : PChar;
  bufferSize                  : DWORD;
begin
  bufferSize := MAX_COMPUTERNAME_LENGTH + 1;
  GetMem(buffer, bufferSize * SizeOf(char));
  try
    GetComputerName(buffer, bufferSize);
    SetLength(Result, StrLen(buffer));
    if Result <> '' then
      Move(buffer^, Result[1], Length(Result) * SizeOf(char));
  finally FreeMem(buffer);
  end;
end; { DSiGetComputerName }

function getCurrentUserAndDomain(): string;
var
  sDomain, sUser, sResult     : string;
  iDomain                     : integer;
begin
  //
  sDomain := Trim(GetEnvVarValue('USERDOMAIN'));

  sUser := Trim(GetEnvVarValue('USERNAME'));
  sResult := sDomain + '\' + sUser;

  Result := sResult;
end;
//
//var
//  hProcess, hAccessToken      : THandle;
//  InfoBuffer                  : array[0..1000] of Char;
//  szAccountName, szDomainName : array[0..200] of Char;
//  dwInfoBufferSize, dwAccountSize, dwDomainSize: DWORD;
//  pUser                       : PTokenUser;
//  snu                         : SID_NAME_USE;
//  User, Domain, Comp          : string;
//begin
//  dwAccountSize := 200;
//  dwDomainSize := 200;
//  hProcess := GetCurrentProcess;
//  OpenProcessToken(hProcess, TOKEN_READ, hAccessToken);
//  GetTokenInformation(hAccessToken, TokenUser, @InfoBuffer[0], 1000,
//    dwInfoBufferSize);
//  pUser := PTokenUser(@InfoBuffer[0]);
//  LookupAccountSid(nil, pUser.User.Sid, szAccountName, dwAccountSize, szDomainName,
//    dwDomainSize,
//    snu);
//  User := szAccountName;
//  Domain := szDomainName;
//
//  if Length(Trim(Domain)) < 1 then
//  begin
//    Result := User;
//  end
//  else
//  begin
//    Comp := UpperCase(MgGetComputerName);
//
//    if UpperCase(Domain) = Comp then
//      Result := User
//    else
//      Result := Domain + '\' + User;
//  end;
//
//  CloseHandle(hAccessToken);
//end;

function MgGetUserName: string;
var
  buffer                      : PChar;
  bufferSize                  : DWORD;
begin
  bufferSize := 256; //UNLEN from lmcons.h
  buffer := AllocMem(bufferSize * SizeOf(char));
  try
    GetUserName(buffer, bufferSize);
    Result := string(buffer);
  finally FreeMem(buffer, bufferSize);
  end;
end; { DSiGetUserName }

procedure AcceptLocalPsexecEula();
begin
  RegSetDWORD(HKEY_LOCAL_MACHINE, 'Software\Sysinternals\Psexec\EulaAccepted', 1);
end;

procedure UninstallPsexecService(MachineName: string);
var
  SCManager                   : SC_HANDLE;
  Service                     : SC_HANDLE;
  Status                      : TServiceStatus;
  ServiceName                 : string;
begin
  ServiceName := 'psexesvc';
  SCManager := OpenSCManager(PChar(MachineName), nil, SC_MANAGER_ALL_ACCESS);

  if SCManager = 0 then
    Exit;

  try
    Service := OpenService(SCManager, PChar(ServiceName), SERVICE_ALL_ACCESS);
    ControlService(Service, SERVICE_CONTROL_STOP, Status);
    DeleteService(Service);
    CloseServiceHandle(Service);
  finally
    CloseServiceHandle(SCManager);
  end;
end;

end.

