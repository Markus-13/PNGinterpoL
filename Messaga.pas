unit Messaga; // Messaga 1.0 by Markus_13 {http://markus13.name}

//{$DEFINE AppProject}
interface
uses
{$IFDEF AppProject}
  Forms,
{$ELSE}
  {$IFDEF LINUX}
    WinUtils,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
    Windows,
  {$ENDIF}
{$ENDIF}
strUtilzConst;

const //_CONSTS:_//////////////////////////////////////////////////////////////////////////////////////////////
  mYN=$24; mERR=$10; mWAR=$30; mINF=$40; //message codes
{$IFDEF AppProject}
{$ELSE}
var tit:string='';   // should be initialized before first call
{$ENDIF}

//----------------FUNCTION-LIST:-------------------------------------------------------------------------------

// Show Message (message, flags): result (for mYN: id_yes, id_no)
function mesaga(m:string;f:longint=0):integer; overload;
function mesaga(m:string;t:string;f:longint=0):integer; overload;

implementation//===============================================================================================

{$IFDEF AppProject}
function mesaga(m:string;f:longint=0):integer;
begin
  result:=application.MessageBox(pChar(m+_s),pChar(application.Title),f+$1000);
end;
function mesaga(m:string;t:string;f:longint=0):integer;
begin
  result:=application.MessageBox(pChar(m+_s),pChar(t),f+$1000);
end;
{$ELSE}
function mesaga(m:string;f:longint=0):integer;
begin
  result:=Windows.MessageBox(0,pChar(m+_s),pChar(tit),f+$1000);
end;
function mesaga(m:string;t:string;f:longint=0):integer; 
begin
  result:=Windows.MessageBox(0,pChar(m+_s),pChar(t),f+$1000);
end;
{$ENDIF}

//\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
end.

