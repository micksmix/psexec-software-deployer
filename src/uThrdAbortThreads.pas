unit uThrdAbortThreads;

interface

uses
  Classes,
  SysUtils;
//main;

type
  TAbortThreads = class(TThread)
  private
    { Private declarations }
    FThrd: ^TThread;
    procedure UpdateCaption;
  protected
    procedure Execute; override;
  public
    constructor Create(PThrd: Pointer);
  end;

implementation

{
  Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TAbortThreads.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end;

    or

    Synchronize(
      procedure
      begin
        Form1.Caption := 'Updated in thread via an anonymous method'
      end
      )
    );

  where an anonymous method is passed.

  Similarly, the developer can call the Queue method with similar parameters as
  above, instead passing another TThread class as the first parameter, putting
  the calling thread in a queue with the other thread.

}

{ thrdAbortThreads }

constructor TAbortThreads.Create(PThrd: Pointer);
begin
  //
  FThrd := PThrd;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TAbortThreads.UpdateCaption;
begin
  //main.bThreadsKilled := True;
end;

procedure TAbortThreads.Execute;
begin
  { Place thread code here }
    //
  if Assigned(FThrd^) then
    FreeAndNil(FThrd^);

  //Synchronize(UpdateCaption);
end;

end.

