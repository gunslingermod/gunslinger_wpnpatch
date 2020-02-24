unit CRT;

//тут создаем новые рендертаргеты
//править процедуры CreateNewRTs и RemoveNewRTs

interface
  type CRT_rec = packed record
    unknown1:cardinal;
    unknown2:cardinal;
    unknown3:cardinal;
    pSurface:pointer;
    pRT:pointer;
  end;
  type pCRT_rec = ^CRT_rec;

  function Init():boolean;
  function GetScoperender():pCRT_rec; stdcall;
  function GetScoperenderWithUI():pCRT_rec; stdcall;
  function GetUirender():pCRT_rec; stdcall;  

implementation
uses BaseGameData, Misc;

var
  scoperender_viewport:pCRT_rec;
  scoperenderwithui_viewport:pCRT_rec;
  uirender_viewport:pCRT_rec;

  resptrcode_crt___create:cardinal;
  resptrcode_crt___destroy:cardinal;

const
  RT_SCOPERENDER_VIEWPORT:PChar='$user$scope';
  RT_SCOPERENDERWITHUI_VIEWPORT:PChar='$user$scopeui';
  RT_UIRENDER_VIEWPORT:PChar='$user$ui';
  D3DFMT_R32F:cardinal=114;

//Common///////////////////////////////////////////////////////////////

function GetScoperender():pCRT_rec; stdcall;
begin
  result:=scoperender_viewport;
end;

function GetScoperenderWithUI():pCRT_rec; stdcall;
begin
  result:=scoperenderwithui_viewport;
end;

function GetUirender():pCRT_rec; stdcall;
begin
  result:=uirender_viewport;
end;

procedure NewRT(dest:pointer; name:PChar; w:cardinal; h:cardinal; format:cardinal ); stdcall;
asm
  pushad
    mov esi, dest   //куда будем писать
    mov eax, [esi]
    cmp eax, 0      //убеждаемс€, что место не зан€то
    jne @finish
      mov ecx, format
      mov edx, h
      push w
      push name
      call resptrcode_crt___create;
    @finish:
  popad
end;


procedure DelRT(addr:pointer); stdcall
asm
  pushad
    //провер€ем, есть ли что удал€ть
    mov esi, addr
    cmp esi, 0
    je @finish

    mov eax, [esi]
    cmp eax, 0
    je @finish

    //уменьшаем счетчик ссылок
    add dword ptr [eax], $FFFFFFFF

    //провер€ем, равен ли он 0
    cmp [eax], 0
    jne @finish
    //убиваем наш буфер
    call resptrcode_crt___destroy
    //освобождаем пам€ть

    mov esi, addr
    push [esi]
    call xrMemory__release

    mov esi, addr
    mov [esi], 0
    @finish:
  popad
end;

procedure CreateNewRTs (w:cardinal; h:cardinal; format:cardinal); stdcall;
begin
//*****************рендертаргеты добавл€ть здесь!!!***********************
  NewRT(@scoperender_viewport, RT_SCOPERENDER_VIEWPORT, w, h, format);
  NewRT(@scoperenderwithui_viewport, RT_SCOPERENDERWITHUI_VIEWPORT, w, h, format);
  NewRT(@uirender_viewport, RT_UIRENDER_VIEWPORT, w, h, format);
end;

procedure RemoveNewRTs(); stdcall;
begin
  DelRT(@scoperender_viewport);
  DelRT(@scoperenderwithui_viewport);
  DelRT(@uirender_viewport);
end;

//R1 specific///////////////////////////////////////////////////////////////
procedure R1_CRenderTarget__Constructor_Patch(); stdcall
asm
  pushad
    push $16
    // push [edi+$0c]  //rtHeight
    // push [edi+$08]  //rtWidth
    // Ќе используем rtWidth и rtHeight во избежание суперсэмплинга - будет сильно лагать
    call GetDeviceHeight
    push eax
    call GetDeviceWidth
    push eax
    call CreateNewRTs
  popad

  mov edx, [edi+$0c]
  lea ebx, [edi+$18]
end;

procedure R1_CRenderTarget__Destructor_Patch(); stdcall
asm
  pushad
    call RemoveNewRTs
  popad

  mov eax, [esi+$18]
  cmp eax, ebp
end;

//R2 specific///////////////////////////////////////////////////////////////
procedure R2_CRenderTarget__Constructor_Patch(); stdcall
asm
  pushad
    push $15
    push edx  //height
    push edi  //width
    call CreateNewRTs
  popad

  mov ecx, $15
end;

procedure R2_CRenderTarget__Destructor_Patch(); stdcall
asm
  pushad
    call RemoveNewRTs
  popad
  
  //original
  mov eax, [esi+$58]
  cmp eax, ebx
end;

//R3 specific///////////////////////////////////////////////////////////////
procedure R3_crt_create_reimpl; stdcall;
//адаптер дл€ R3; там height передаетс€ через стек, формат - в edx, а dest - через edi
asm
  //ret 8
  //@a:jmp @a
  push [esp]

  mov edi, [esp+8]  //name
  mov [esp+4], edi

  mov edi, [esp+$C]  //width
  mov [esp+8], edi

  mov [esp+$C], edx

  mov edx, ecx
  mov edi, esi

  mov ecx, xrrender_r3_addr
  add ecx, $84550
  push ecx
  mov ecx, 1
  ret
end;

procedure R3_CRenderTarget__Constructor_Patch(); stdcall
asm
  pushad
    push $15
    push edx  //height
    push esi  //width
    call CreateNewRTs
  popad

  mov eax, [ecx+$364]
end;

procedure R3_CRenderTarget__Destructor_Patch(); stdcall
asm
  pushad
    call RemoveNewRTs
  popad
  
  //original
  mov eax, [esi+$1AC]
end;

//R4 specific///////////////////////////////////////////////////////////////
procedure R4_crt_create_reimpl; stdcall;
//адаптер дл€ R4; height и формат передаютс€ через стек, dest - через edi
asm
  push [esp]
  push [esp]

  mov edi, [esp+$C]  //name
  mov [esp+4], edi

  mov edi, [esp+$10]  //width
  mov [esp+8], edi

  mov [esp+$C], edx
  mov [esp+$10], ecx

  mov edi, esi
  mov edx, 1

  mov ecx, xrrender_r4_addr
  add ecx, $8B530
  push ecx
  mov ecx, 0
  ret
end;


procedure R4_CRenderTarget__Constructor_Patch(); stdcall
asm
  pushad
    push $15
    push ecx  //height
    push edi  //width
    call CreateNewRTs
  popad

  mov eax, [eax+$364]
end;

procedure R4_CRenderTarget__Destructor_Patch(); stdcall
asm
  pushad
    call RemoveNewRTs
  popad
  
  //original
  mov eax, [esi+$1B4]
end;


////////////////////////////////////////////////////////////////////////////
function Init():boolean;
var
 jmp_addr:cardinal;
begin
  result:=false;
  if xrRender_R1_addr<>0 then begin
    resptrcode_crt___create:=xrRender_R1_addr+$51FE0;
    jmp_addr:=xrRender_R1_addr+$B4D9;
    if not WriteJump(jmp_addr, cardinal(@R1_CRenderTarget__Constructor_Patch), 6, true) then exit;

    resptrcode_crt___destroy:=xrRender_r1_addr+$51C90;
    jmp_addr:=xrRender_R1_addr+$B869;
    if not WriteJump(jmp_addr, cardinal(@R1_CRenderTarget__Destructor_Patch), 5, true) then exit;

  end else if xrRender_R2_addr<>0 then begin
    resptrcode_crt___create:=xrRender_r2_addr+$7A3C0;
    jmp_addr:=xrRender_R2_addr+$59B71;
    if not WriteJump(jmp_addr, cardinal(@R2_CRenderTarget__Constructor_Patch), 5, true) then exit;

    resptrcode_crt___destroy:=xrRender_r2_addr+$7A070;
    jmp_addr:=xrRender_R2_addr+$5C262;
    if not WriteJump(jmp_addr, cardinal(@R2_CRenderTarget__Destructor_Patch), 5, true) then exit;

  end else if xrRender_R3_addr<>0 then begin
    resptrcode_crt___create:=cardinal(@R3_crt_create_reimpl);
    jmp_addr:=xrRender_R3_addr+$5CEFC;
    if not WriteJump(jmp_addr, cardinal(@R3_CRenderTarget__Constructor_Patch), 6, true) then exit;

    resptrcode_crt___destroy:=xrRender_R3_addr+$841A0;
    jmp_addr:=xrRender_R3_addr+$6021A;
    if not WriteJump(jmp_addr, cardinal(@R3_CRenderTarget__Destructor_Patch), 6, true) then exit;

  end else if xrRender_R4_addr<>0 then begin
    resptrcode_crt___create:=cardinal(@R4_crt_create_reimpl);
    jmp_addr:=xrRender_R4_addr+$5F1C8;
    if not WriteJump(jmp_addr, cardinal(@R4_CRenderTarget__Constructor_Patch), 6, true) then exit;


    resptrcode_crt___destroy:=xrRender_R4_addr+$8b0e0;
    jmp_addr:=xrRender_R4_addr+$624ea;
    if not WriteJump(jmp_addr, cardinal(@R4_CRenderTarget__Destructor_Patch), 6, true) then exit;

  end else begin
    resptrcode_crt___create:=0;
    resptrcode_crt___destroy:=0;
  end;

  result:=true;
end;

end.
