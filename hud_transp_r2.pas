unit hud_transp_r2;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
function Init():boolean; stdcall;


implementation
uses BaseGameData;

type FixedMapR2 = packed record
  nodes:pointer;
  pool:cardinal;
  limit:cardinal;
end;

var
  g_map_hud_sorted_r2:FixedMapR2;
  g_map_hud_distort_r2:FixedMapR2;
  hud_render_phase:cardinal;  //0 - стандартно, 1 - sorted, 2 - distort

procedure hud_shader_fix_Patch_sorted(); stdcall;
asm
  lea eax, g_map_hud_sorted_r2
  ret
end;

procedure hud_shader_fix_Patch_distort(); stdcall;
asm
  //сначала посмотрим, в какой буфер запихивать: в оригинальный или в худовый.

  mov eax, xrRender_R2_addr
  add eax, $CE380 //флаг того, что идет рендер худа
  cmp [eax], 00
  je @not_hud

  lea eax, g_map_hud_distort_r2
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

  cmp g_map_hud_sorted_r2.pool, 0
  lea ecx, g_map_hud_sorted_r2.nodes
  ret

  @distorted:
  cmp g_map_hud_distort_r2.pool, 0
  lea ecx, g_map_hud_distort_r2.nodes
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

  mov g_map_hud_sorted_r2.pool, 0
  ret

  @distorted:
  mov g_map_hud_distort_r2.pool, 0
  ret

  @original_nosorted:
  mov [ebp+$1a4], 0
  ret
end;

procedure render_distort_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 2

    mov ebx, xrRender_R2_addr
    lea eax, [ebx+$CE270]
    push eax
    add ebx, $20730
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), в ней выставленный выше флаг заставит рендерить sorted
    mov hud_render_phase, 0

  popad

  //оригинальное
  mov ecx, xrRender_R2_addr
  mov ecx, [ecx+$B57B8]
  ret
end;


procedure render_forward_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 1

    mov ebx, xrRender_R2_addr

    lea eax, [ebx+$CE270]
    push eax
    add ebx, $20730
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), в ней выставленный выше флаг заставит рендерить sorted
    mov hud_render_phase, 0

    mov ebx, xrRender_R2_addr

  popad

  mov ecx, xrRender_R2_addr
  mov ecx, [ecx+$B57B8]
  ret
end;

function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin

  result:=false;
  if xrRender_R2_addr=0 then exit;

  g_map_hud_sorted_r2.nodes:=nil;
  g_map_hud_sorted_r2.pool:=0;
  g_map_hud_sorted_r2.limit:=0;
  g_map_hud_distort_r2.nodes:=nil;
  g_map_hud_distort_r2.pool:=0;
  g_map_hud_distort_r2.limit:=0;
  hud_render_phase:=0;

  jmp_addr:=xrRender_R2_addr+$1D777;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_sorted), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$1D6BC;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_distort), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$F5C2;
  if not WriteJump(jmp_addr, cardinal(@render_forward_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$6E52E;
  if not WriteJump(jmp_addr, cardinal(@render_distort_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$20C09;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_select_pool), 13, true) then exit;

  jmp_addr:=xrRender_R2_addr+$20C30;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_cleanup), 10, true) then exit;
    
  result:=true;
end;

end.
