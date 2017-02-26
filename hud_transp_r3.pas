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
  is_rendering_sorted_hud:cardinal;

procedure hud_shader_fix_Patch(); stdcall;
asm
  lea eax, g_map_hud_sorted_r3 //и всё ;) Emissive работают и в оригинале
  ret
end;


procedure r_dsgraph_render_hud_Patch_select_pool(); stdcall;
asm
  //если сейчас рендерим sorted - то выбираем нашу структурку выше
  //Иначе - используем оригинальный код.
  cmp is_rendering_sorted_hud, 0
  je @original_nosorted
  cmp g_map_hud_sorted_r3.pool, 0
  lea ecx, g_map_hud_sorted_r3.nodes
  ret

  @original_nosorted:
  cmp [ebp+$1a4], 0
  lea ecx, [ebp+$1a0]
  ret
end;

procedure r_dsgraph_render_hud_Patch_cleanup(); stdcall;
asm
  cmp is_rendering_sorted_hud, 0
  je @original_nosorted
  mov g_map_hud_sorted_r3.pool, 0
  ret
  @original_nosorted:
  mov [ebp+$1a4], 0
  ret
end;


procedure render_forward_fix_Patch(); stdcall;
asm
  //немного переделанный оригинальный код игры
  je @mov
  mov eax, xrRender_R3_addr
  add eax, $22FE0
  push eax

  mov eax, [ecx]
  push eax

  mov eax, xrRender_R3_addr
  add eax, $25630

  call eax
  @mov:

  //теперь новое
  pushad
    mov is_rendering_sorted_hud, 1

    mov ebx, xrRender_R3_addr
    lea eax, [ebx+$EB000]
    push eax
    add ebx, $24280
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), в ней выставленный выше флаг заставит рендерить sorted
    mov is_rendering_sorted_hud, 0

  popad
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
  is_rendering_sorted_hud:=0;

  jmp_addr:=xrRender_R3_addr+$20f57;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R3_addr+$1FF13;
  if not WriteJump(jmp_addr, cardinal(@render_forward_fix_Patch), 15, true) then exit;

  jmp_addr:=xrRender_R3_addr+$24756;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_select_pool), 13, true) then exit;

  jmp_addr:=xrRender_R3_addr+$2477D;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_cleanup), 10, true) then exit;

  result:=true;
end;

end.
