unit HqGeometryFix;

interface

function Init():boolean; stdcall;

implementation
uses MatVectors;

type
vertHW_1W = packed record
  _P:array[0..3] of single;
  _N_I:cardinal;
  _T:cardinal;
  _B:cardinal;
  _tc:array [0..1] of single;
end;
pvertHW_1W = ^vertHW_1W;

procedure vertHW_1W_set(this:pvertHW_1W; P:pFvector3; N:Fvector3; T:Fvector3; B:Fvector3; tc:PFVector2; index:integer); stdcall;
begin
  
end;


function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
begin
  result:=false;

  result:=true;
end;

end.
