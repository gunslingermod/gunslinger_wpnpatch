unit hud_transp_r3;

interface
function Init():boolean; stdcall;


implementation
uses BaseGameData;

type FixedMapR3 = packed record
  nodes:pointer;
  pool:cardinal;
  limit:cardinal;
end;

var
  g_map_hud_sorted_r3:FixedMapR3;
  g_map_hud_distort_r3:FixedMapR3;
  hud_render_phase:cardinal;

procedure hud_shader_fix_Patch_sorted(); stdcall;
asm
  lea eax, g_map_hud_sorted_r3 //и всё ;) Emissive работают и в оригинале
  ret
end;

procedure hud_shader_fix_Patch_distort(); stdcall;
asm
  //сначала посмотрим, в какой буфер запихивать: в оригинальный или в худовый.

  mov eax, xrRender_R3_addr
  add eax, $EB110 //флаг того, что идет рендер худа
  cmp [eax], 00
  je @not_hud

  lea eax, g_map_hud_distort_r3
  ret

  @not_hud:
  lea eax,[ebp+$1B8]
  ret
end;

procedure r_dsgraph_render_hud_Patch_select_pool(); stdcall;
asm
  //если сейчас рендерим sorted или distort - то выбираем нашу структурку выше
  //Иначе - используем оригинальный код.
  cmp hud_render_phase, 0
  je @original_nosorted
  cmp hud_render_phase, 2
  je @distorted

  cmp g_map_hud_sorted_r3.pool, 0
  lea ecx, g_map_hud_sorted_r3.nodes
  ret

  @distorted:
  cmp g_map_hud_distort_r3.pool, 0
  lea ecx, g_map_hud_distort_r3.nodes
  ret

  @original_nosorted:
  cmp [ebp+$1a4], 0
  lea ecx, [ebp+$1a0]
  ret
end;

procedure r_dsgraph_render_hud_Patch_cleanup(); stdcall;
asm
  cmp hud_render_phase, 0
  je @original_nosorted
  cmp hud_render_phase, 2
  je @distorted

  mov g_map_hud_sorted_r3.pool, 0
  ret

  @distorted:
  mov g_map_hud_distort_r3.pool, 0
  ret

  @original_nosorted:
  mov [ebp+$1a4], 0
  ret
end;

procedure render_distort_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 2
    mov ebx, xrRender_R3_addr
    lea eax, [ebx+$EB000]
    push eax
    add ebx, $24280
    call ebx
    mov hud_render_phase, 0
  popad

  mov edx, xrRender_R3_addr
  mov edx, [edx+$D05F0]
  ret
end;


procedure render_forward_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 1
    mov ebx, xrRender_R3_addr
    lea eax, [ebx+$EB000]
    push eax
    add ebx, $24280
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), в ней выставленный выше флаг заставит рендерить sorted
    mov hud_render_phase, 0
  popad

  mov ecx, xrRender_R3_addr
  mov ecx, [ecx+$D05F0]
  ret
end;

function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin

  result:=false;
  if xrRender_R3_addr=0 then exit;

  g_map_hud_sorted_r3.nodes:=nil;
  g_map_hud_sorted_r3.pool:=0;
  g_map_hud_sorted_r3.limit:=0;

  g_map_hud_distort_r3.nodes:=nil;
  g_map_hud_distort_r3.pool:=0;
  g_map_hud_distort_r3.limit:=0;
  hud_render_phase:=0;

  jmp_addr:=xrRender_R3_addr+$20f57;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_sorted), 6, true) then exit;

  jmp_addr:=xrRender_R3_addr+$20e9c;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_distort), 6, true) then exit;

  jmp_addr:=xrRender_R3_addr+$1FF22;
  if not WriteJump(jmp_addr, cardinal(@render_forward_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R3_addr+$783CA;
  if not WriteJump(jmp_addr, cardinal(@render_distort_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R3_addr+$24756;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_select_pool), 13, true) then exit;

  jmp_addr:=xrRender_R3_addr+$2477D;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_cleanup), 10, true) then exit;

  result:=true;
end;

end.
