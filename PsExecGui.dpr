program PsExecGui;

uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  Forms,
  main in 'src\main.pas' {Form1},
  uHelpers in 'src\uHelpers.pas',
  uMiniReg in 'src\uMiniReg.pas',
  ThreadUtilities in 'src\ThreadUtilities.pas',
  uThrdAbortThreads in 'src\uThrdAbortThreads.pas',
  uWorkerThread in 'src\uWorkerThread.pas',
  frmExamples in 'src\frmExamples.pas' {frmUsageExamples},
  AsyncCalls in 'src\AsyncCalls.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TfrmUsageExamples, frmUsageExamples);
  Application.Run;
end.
