(*
Implemented for Delphi3000.com Articles, 11/01/2004
        Chris Baldwin
        Director & Chief Architect
        Alive Technology Limited
        http://www.alivetechnology.com
*)
unit ThreadUtilities;

interface

uses
  Windows,
  SysUtils,
  Classes;

type
  EThreadStackFinalized = class(Exception);
  TSimpleThread = class;

  // Thread Safe Pointer Queue
  TThreadQueue = class
  private
    FFinalized: Boolean;
    FIOQueue: THandle;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Finalize;
    procedure Push(Data: Pointer);
    function Pop(var Data: Pointer): Boolean;
    property Finalized: Boolean read FFinalized;
  end;

  TThreadExecuteEvent = procedure(Thread: TThread) of object;

  TSimpleThread = class(TThread)
  private
    FExecuteEvent: TThreadExecuteEvent;
  protected
    procedure Execute(); override;
  public
    constructor Create(CreateSuspended: Boolean; ExecuteEvent: TThreadExecuteEvent; AFreeOnTerminate:
      Boolean);
  end;

  TThreadPoolEvent = procedure(Data: Pointer; AThread: TThread) of object;

  TThreadPool = class(TObject)
  private
    FThreads: TList;
    FThreadQueue: TThreadQueue;
    FHandlePoolEvent: TThreadPoolEvent;
    procedure DoHandleThreadExecute(Thread: TThread);
  public
    constructor Create(HandlePoolEvent: TThreadPoolEvent; MaxThreads: Integer = 1); virtual;
    destructor Destroy; override;
    procedure Add(const Data: Pointer);
  end;

implementation

{ TThreadQueue }

constructor TThreadQueue.Create;
begin
  //-- Create IO Completion Queue
  // http://msdn.microsoft.com/en-us/library/aa363862%28v=VS.85%29.aspx
  FIOQueue := CreateIOCompletionPort(
    INVALID_HANDLE_VALUE,
    0,
    0,
    0 //If zero, allows as many concurrently running threads as processors in the system.
    );
  FFinalized := False;
end;

destructor TThreadQueue.Destroy;
begin
  //-- Destroy Completion Queue
  if (FIOQueue <> 0) then
    CloseHandle(FIOQueue);
  inherited;
end;

procedure TThreadQueue.Finalize;
begin
  //-- Post a finialize pointer on to the queue
  // http://msdn.microsoft.com/en-us/library/aa365458%28v=VS.85%29.aspx
  PostQueuedCompletionStatus(
    FIOQueue,
    0,
    0,
    Pointer($FFFFFFFF)
    );

  FFinalized := True;
end;

(* Pop will return false if the queue is completed *)

function TThreadQueue.Pop(var Data: Pointer): Boolean;
var
  A                 : Cardinal;
  OL                : POverLapped;
begin
  Result := True;
  if (not FFinalized) then
    //-- Remove/Pop the first pointer from the queue or wait
    GetQueuedCompletionStatus(
      FIOQueue,
      A,
      NativeUInt(Data),//Cardinal(Data),
      OL,
      INFINITE
      );

  //-- Check if we have finalized the queue for completion
  if FFinalized or (OL = Pointer($FFFFFFFF)) then
  begin
    Data := nil;
    Result := False;
    Finalize;
  end;
end;

procedure TThreadQueue.Push(Data: Pointer);
begin
  if FFinalized then
    raise EThreadStackFinalized.Create('Stack is finalized');
  //-- Add/Push a pointer on to the end of the queue
  PostQueuedCompletionStatus(
    FIOQueue,
    0,
    Cardinal(Data),
    nil
    );
end;

{ TSimpleThread }

constructor TSimpleThread.Create(CreateSuspended: Boolean;
  ExecuteEvent: TThreadExecuteEvent; AFreeOnTerminate: Boolean);
begin
  FreeOnTerminate := AFreeOnTerminate;
  FExecuteEvent := ExecuteEvent;
  inherited Create(CreateSuspended);
end;

procedure TSimpleThread.Execute;
begin
  if Assigned(FExecuteEvent) then
    FExecuteEvent(Self);
end;

{ TThreadPool }

procedure TThreadPool.Add(const Data: Pointer);
begin
  FThreadQueue.Push(Data);
end;

constructor TThreadPool.Create(HandlePoolEvent: TThreadPoolEvent; MaxThreads: Integer);
begin
  FHandlePoolEvent := HandlePoolEvent;
  FThreadQueue := TThreadQueue.Create;
  FThreads := TList.Create;
  while FThreads.Count < MaxThreads do
    FThreads.Add(TSimpleThread.Create(False, DoHandleThreadExecute, False));
end;

destructor TThreadPool.Destroy;
var
  t                 : Integer;
begin
  FThreadQueue.Finalize;

  for t := 0 to FThreads.Count - 1 do
  begin
    TThread(FThreads[t]).Terminate;
    //TThread(FThreads[t]).WaitFor;
    //TThread(FThreads[t]).Free;
    //FThreads.Delete(t);
  end;

  while (FThreads.Count > 0) do
  begin
    TThread(FThreads[0]).WaitFor;
    TThread(FThreads[0]).Free;
    FThreads.Delete(0);
  end;
  FThreadQueue.Free;
  FThreads.Free;
  inherited;
end;

procedure TThreadPool.DoHandleThreadExecute(Thread: TThread);
var
  Data              : Pointer;
begin
  while FThreadQueue.Pop(Data) and (not TSimpleThread(Thread).Terminated) do
  begin
    try
      FHandlePoolEvent(Data, Thread);
    except
    end;
  end;
end;

end.

