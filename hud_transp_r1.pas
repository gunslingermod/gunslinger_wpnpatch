unit hud_transp_r1;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
function Init():boolean; stdcall;


implementation
uses BaseGameData;

type FixedMapR1 = packed record
  nodes:pointer;
  pool:cardinal;
  limit:cardinal;
end;

var
  g_map_hud_sorted_r1:FixedMapR1;
  g_map_hud_distort_r1:FixedMapR1;
  hud_render_phase:cardinal;


procedure hud_shader_fix_Patch_sorted(); stdcall;
asm
  mov eax, xrRender_R1_addr
  add eax, $A6FC8 //флаг того, что идет рендер худа
  cmp [eax], 00
  je @not_hud

  lea eax, g_map_hud_sorted_r1
  ret

  @not_hud:
  lea eax,[ebp+$194]
  ret
end;

procedure hud_shader_fix_Patch_distort(); stdcall;
asm
  mov eax, xrRender_R1_addr
  add eax, $A6FCC //флаг того, что рендерится мировая модель актора
  cmp [eax], 00
  jne @actor_world

  mov eax, xrRender_R1_addr
  add eax, $A6FC8 //флаг того, что идет рендер худа
  cmp [eax], 00
  je @not_hud

  lea eax, g_map_hud_distort_r1
  ret

  @not_hud:
  lea eax,[ebp+$1B8]
  ret

  @actor_world:
  //рендерится мировая модель актора, дисторты неприемлемы.
  //уходим отсюда
  add esp, 4//адрес возврата из патча
  pop edi
  pop ebp
  pop ebx
  pop esi
  add esp, $68
  ret 8
end;


procedure r_dsgraph_render_hud_Patch_select_pool(); stdcall;
asm
  cmp hud_render_phase, 0
  je @original_nosorted
  cmp hud_render_phase, 2
  je @distorted

  cmp g_map_hud_sorted_r1.pool, 0
  lea ecx, g_map_hud_sorted_r1.nodes
  ret

  @distorted:
  cmp g_map_hud_distort_r1.pool, 0
  lea ecx, g_map_hud_distort_r1.nodes
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

  mov g_map_hud_sorted_r1.pool, 0
  ret

  @distorted:
  mov g_map_hud_distort_r1.pool, 0
  ret

  @original_nosorted:
  mov [ebp+$1a4], 0
  ret
end;

procedure render_forward_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 1

    mov ebx, xrRender_R1_addr
    lea eax, [ebx+$A6EB8]
    push eax
    add ebx, $10770
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), в ней выставленный выше флаг заставит рендерить sorted
    mov hud_render_phase, 0

  popad

  mov eax, [edi+$41c]
  ret
end;

procedure render_distort_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 2

    mov ebx, xrRender_R1_addr
    lea eax, [ebx+$A6EB8]
    push eax
    add ebx, $10770
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), в ней выставленный выше флаг заставит рендерить sorted
    mov hud_render_phase, 0

  popad

  mov edx, xrRender_R1_addr
  mov edx, [edx+$90534]
  ret
end;



function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin

  result:=false;
  if xrRender_R1_addr=0 then exit;

  //все суть прямой рендер, просто отправляем sortedы в худовую очередь
//  nop_code(xrRender_R1_addr+$DEFF, 2);

  jmp_addr:=xrRender_R1_addr+$DF2E;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_sorted), 6, true) then exit;

  jmp_addr:=xrRender_R1_addr+$DE53;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_distort), 6, true) then exit;

  jmp_addr:=xrRender_R1_addr+$6204;
  if not WriteJump(jmp_addr, cardinal(@render_forward_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R1_addr+$cc13;
  if not WriteJump(jmp_addr, cardinal(@render_distort_fix_Patch), 6, true) then exit;


  jmp_addr:=xrRender_R1_addr+$10c49;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_select_pool), 13, true) then exit;

  jmp_addr:=xrRender_R1_addr+$10c6b;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_cleanup), 10, true) then exit;

  result:=true;
end;

end.
