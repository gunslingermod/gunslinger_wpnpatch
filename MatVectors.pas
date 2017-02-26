unit MatVectors;

interface

  type FVector3 = packed record
    x:single;
    y:single;
    z:single;
  end;

  type FVector4 = packed record
    x:single;
    y:single;
    z:single;
    w:single;
  end;

  type FMatrix4x4 = packed record
    i:FVector4;
    j:FVector4;
    k:FVector4;
    c:FVector4;
  end;

  type PFVector3 = ^FVector3;
  type PFVector4 = ^FVector4;
  type PFMatrix4x4 = ^FMatrix4x4;

  function FVector3_copyfromengine(v:pointer):FVector3;stdcall;
  function FVector4_copyfromengine(v:pointer):FVector4;stdcall;
  function FMatrix4x4_copyfromengine(v:pointer):FMatrix4x4;stdcall;
  function FVector4_make_from_FVector3(v:PFVector3):FVector4;stdcall;
  function FVector4_mul_FMatrix4x4(v:PFvector4; m:PFMatrix4x4):FVector4;stdcall;

implementation

function FVector3_copyfromengine(v:pointer):FVector3;stdcall;
var
  a,b,c:single;
begin
  //вот такая крякозябра, да... По-нормальному не хотит :)
  asm
    push eax
    push ebx
      mov eax, v

      mov ebx, [eax]
      mov a, ebx

      mov ebx, [eax+4]
      mov b, ebx

      mov ebx, [eax+8]
      mov c, ebx
    pop ebx
    pop eax
  end;
  result.x:=a;
  result.y:=b;
  result.z:=c;
end;

function FVector4_copyfromengine(v:pointer):FVector4;stdcall;
var
  a,b,c,d:single;
begin
  //вот такая крякозябра, да... По-нормальному не хотит :)
  asm
    push eax
    push ebx
      mov eax, v

      mov ebx, [eax]
      mov a, ebx

      mov ebx, [eax+4]
      mov b, ebx

      mov ebx, [eax+8]
      mov c, ebx

      mov ebx, [eax+$C]
      mov d, ebx
    pop ebx
    pop eax
  end;
  result.x:=a;
  result.y:=b;
  result.z:=c;
  result.w:=d;
end;


function FMatrix4x4_copyfromengine(v:pointer):FMatrix4x4;stdcall;
begin
  result.i:=FVector4_copyfromengine(v);
  v:=PChar(v)+4;
  result.j:=FVector4_copyfromengine(v);
  v:=PChar(v)+4;
  result.k:=FVector4_copyfromengine(v);
  v:=PChar(v)+4;
  result.c:=FVector4_copyfromengine(v);  
end;


function FVector4_make_from_FVector3(v:PFVector3):FVector4;stdcall;
begin
  result.x:=v^.x;
  result.y:=v^.y;
  result.z:=v^.z;
  result.w:=1;
end;


function FVector4_mul_FMatrix4x4(v:PFvector4; m:PFMatrix4x4):FVector4;stdcall;
begin
  result.x := (v.x*m.i.x) + (v.y*m.j.x) + (v.z * m.k.x) + (v.w*m.c.x);
  result.y := (v.x*m.i.y) + (v.y*m.j.y) + (v.z * m.k.y) + (v.w*m.c.y);
  result.z := (v.x*m.i.z) + (v.y*m.j.z) + (v.z * m.k.z) + (v.w*m.c.z);
  result.w := (v.x*m.i.w) + (v.y*m.j.w) + (v.z * m.k.w) + (v.w*m.c.w);
end;


end.
