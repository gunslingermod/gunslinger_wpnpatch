unit LensDoubleRender;

interface
function Init():boolean; stdcall;


implementation
uses BaseGameData;



//отрендерим второй кадр для линзы, если требуется
{procedure IGameLevel__OnRender_Patch(); stdcall;
asm
  mov eax, [edx+$BC]; //делаем вырезанное - получаем адрес void IRenderInterface Render->Render()
  pushad
    mov ebx, xrEngine_addr
    and byte ptr [ebx+$90904], $FB      // hud_weapon off
    call eax
    mov ebx, xrEngine_addr
    or byte ptr [ebx+$90904], $4        // hud_weapon on
  popad

  //recalc
  pushad
    mov eax, [edx+$B8]
    call eax
  popad
end; }


procedure IGameLevel__OnRender_Patch(); stdcall;
asm
  mov ecx, [eax]
  push ecx



  mov ecx, [esp]
  mov edx, [ecx]
  mov eax, [edx+$B8]
  call eax            //Render->Calculate()


  //--------------------------------------------------------
  mov eax, xrEngine_addr
  and byte ptr [eax+$90904], $FB      // hud_weapon off

  mov ecx, [esp]
  mov edx, [ecx]
  mov eax, [edx+$BC]
  call eax            //Render->Render()

  mov eax, xrEngine_addr
  or byte ptr [eax+$90904], $4        // hud_weapon on

  //--------------------------------------------------------


  mov ecx, [esp]
  mov edx, [ecx]
  mov eax, [edx+$BC]
  add esp, 4
  jmp eax            //Render->Render()
end;



function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin

  result:=false;

  {jmp_addr:=xrEngine_addr+$17154;
  if not WriteJump(jmp_addr, cardinal(@IGameLevel__OnRender_Patch), 6, true) then exit;}

  jmp_addr:=xrEngine_addr+$1713E;
  if not WriteJump(jmp_addr, cardinal(@IGameLevel__OnRender_Patch), 30, false) then exit;

  result:=true;
end;

end.
