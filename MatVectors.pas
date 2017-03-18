unit MatVectors;

interface

  type FVector2 = packed record
    x:single;
    y:single;
  end;

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

  type FMatrix3x3 = packed record
    i:FVector3;
    j:FVector3;
    k:FVector3;
  end;

  type FRect = packed record
    lt:FVector2;
    rb:FVector2;
  end;

  type PFVector2 = ^FVector2;
  type PFVector3 = ^FVector3;
  type PFVector4 = ^FVector4;
  type PFMatrix4x4 = ^FMatrix4x4;
  type PFMatrix3x3 = ^FMatrix3x3;  

  function FVector3_copyfromengine(v:pointer):FVector3;stdcall;
  function FVector4_copyfromengine(v:pointer):FVector4;stdcall;
  function FMatrix4x4_copyfromengine(v:pointer):FMatrix4x4;stdcall;

  function FVector4_make_from_FVector3(v:PFVector3):FVector4;stdcall;
  function FVector4_mul_FMatrix4x4(v:PFvector4; m:PFMatrix4x4):FVector4;stdcall;
  function FVector3_mul_FMatrix3x3(v:PFvector3; m:PFMatrix3x3):FVector3;stdcall;

  function GetAngleCos(v1:pFVector3; v2:pFVector3):single; stdcall;
  procedure v_sub(from:pFVector3; what:pFVector3); stdcall;
  procedure v_mul(v:pFVector3; n:single); stdcall;
  procedure v_normalize(v:pFVector3);stdcall;
  procedure v_add(from:pFVector3; what:pFVector3); stdcall;
  function PointToPlaneDist(plane:pFVector4; point:pFVector3):single;
  function v_length(v:pFVector3):single;
  procedure v_setlength(v:pFVector3; l:single);
  procedure transform_tiny(m:pFMatrix4x4; dest:pFVector3; v:pFVector3);
  function v_equal(v1, v2:pFVector3):boolean;
  procedure generate_orthonormal_basis_normalized(dir, up, right:pfVector3);
  procedure v_zero(v:pFVector3);
  function v_projection_to_v(from_v, to_v:pfVector3):single; stdcall;



  procedure build_projection(m:pFMatrix4x4; hat:single; aspect:single; near_plane:single; far_plane:single);

implementation
uses Math;

const EPS:single = 0.0001;

function GetAngleCos(v1:pFVector3; v2:pFVector3):single; stdcall;
begin
  result:= (v1.x*v2.x + v1.y*v2.y + v1.z *v2.z)/(sqrt(v1.x*v1.x + v1.y*v1.y + v1.z*v1.z)*sqrt(v2.x*v2.x + v2.y*v2.y + v2.z*v2.z));
end;

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

procedure v_sub(from:pFVector3; what:pFVector3); stdcall;
begin
  from^.x:=from^.x-what^.x;
  from^.y:=from^.y-what^.y;
  from^.z:=from^.z-what^.z;
end;

procedure v_add(from:pFVector3; what:pFVector3); stdcall;
begin
  from^.x:=from^.x+what^.x;
  from^.y:=from^.y+what^.y;
  from^.z:=from^.z+what^.z;
end;

procedure v_normalize(v:pFVector3);stdcall;
var
  l:single;
begin
  l:=sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
  v.x:=v.x/l;
  v.y:=v.y/l;
  v.z:=v.z/l;
end;

procedure v_mul(v:pFVector3; n:single); stdcall;
begin
  v.x:=v.x*n;
  v.y:=v.y*n;
  v.z:=v.z*n;
end;

function PointToPlaneDist(plane:pFVector4; point:pFVector3):single;
begin
  result:=abs((plane.x*point.x + plane.y*point.y + plane.z*point.z + plane.w)/sqrt(plane.x*plane.x + plane.y*plane.y + plane.z*plane.z));
end;

function v_length(v:pFVector3):single;
begin
  result:=sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
end;

procedure v_zero(v:pFVector3);
begin
  v.x:=0;
  v.y:=0;
  v.z:=0;
end;

procedure v_setlength(v:pFVector3; l:single);
begin
  v_normalize(v);
  v_mul(v, l);
end;


procedure transform_tiny(m:pFMatrix4x4; dest:pFVector3; v:pFVector3);
begin
  dest.x:=v.x*m.i.x + v.y*m.j.x + v.z*m.k.x + m.c.x;
  dest.y:=v.x*m.i.y + v.y*m.j.y + v.z*m.k.y + m.c.y;
  dest.z:=v.x*m.i.z + v.y*m.j.z + v.z*m.k.z + m.c.z;    
end;

function v_equal(v1, v2:pFVector3):boolean;
begin
  result:= (abs(v1.x - v2.x)<EPS) and (abs(v1.y - v2.y)<EPS) and (abs(v1.z - v2.z)<EPS);
end;

procedure generate_orthonormal_basis_normalized(dir, up, right:pfVector3);
var
  fInvLength:single;
begin
  v_normalize(dir);
  if abs(dir.y-1.0)<EPS then begin
    up.x:=0; up.y:=0; up.z:=1;
    fInvLength:=1.0/sqrt(dir.x*dir.x + dir.y*dir.y);

    right.x:= -dir.y *fInvLength;
    right.y:=dir.x*fInvLength;
    right.z:=0;

    up.x:=-dir.z*right.y;
    up.y:= dir.z*right.x;
    up.z:=dir.x*right.y - dir.y*right.x;
  end else begin
    up.x:=0; up.y:=1; up.z:=0;
    fInvLength:=1.0/sqrt(dir.x*dir.x + dir.z*dir.z);

    right.x :=dir.z*fInvLength;
    right.y:=0;
    right.z:=-dir.x*fInvLength;

    up.x:=dir.y*right.z;
    up.y:=dir.z*right.x - dir.x*right.z;
    up.z:= -dir.y*right.x;
  end;
end;





procedure build_projection(m:pFMatrix4x4; hat:single; aspect:single; near_plane:single; far_plane:single);
var
  cot, w, h, q:single;
begin
  cot := 1/hat;
  w := aspect*cot;
  h := cot;
  q := far_plane/(far_plane-near_plane);

  m.i.x :=w; m.i.y :=0; m.i.z :=0; m.i.w :=0;
  m.j.x :=0; m.j.y :=h; m.j.z :=0; m.j.w :=0;
  m.k.x :=0; m.k.y :=0; m.k.z :=q; m.k.w :=1;
  m.i.x :=0; m.i.y :=0; m.i.z :=-q*near_plane; m.i.w :=0;
end;

function v_projection_to_v(from_v, to_v:pfVector3):single; stdcall;
begin
  result:= (from_v^.x*to_v^.x + from_v^.y*to_v^.y + from_v^.z*to_v^.z)/v_length(to_v);
end;

function FVector3_mul_FMatrix3x3(v:PFvector3; m:PFMatrix3x3):FVector3;stdcall;
begin
  result.x := (v.x*m.i.x) + (v.y*m.j.x) + (v.z * m.k.x);
  result.y := (v.x*m.i.y) + (v.y*m.j.y) + (v.z * m.k.y);
  result.z := (v.x*m.i.z) + (v.y*m.j.z) + (v.z * m.k.z);
end;


end.
