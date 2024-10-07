unit Vector;

interface

type xr_set = packed record
  data:array [0..$17] of byte;
end;


type xr_vector = packed record
  start:pointer;
  last:pointer;
  memory_end:pointer;
end;
pxr_vector = ^xr_vector;

function items_count_in_vector(v:pxr_vector; itemsz:cardinal):integer; stdcall;
function get_item_from_vector(v:pxr_vector; index:integer; itemsz:cardinal):pointer; stdcall;


implementation
uses BaseGameData;

function items_count_in_vector(v:pxr_vector; itemsz:cardinal):integer;  stdcall;
begin
  R_ASSERT(v<>nil, 'Cannot get items count - vector is nil', 'items_count_in_vector');
  result:=(cardinal(v^.last) - cardinal(v^.start)) div itemsz;
end;

function get_item_from_vector(v:pxr_vector; index:integer; itemsz:cardinal):pointer; stdcall;
begin
  R_ASSERT(v<>nil, 'Cannot get item - vector is nil', 'get_item_from_vector');
  R_ASSERT((index>=0) and (index < items_count_in_vector(v, itemsz)), 'Cannot get item from vector - invalid index', 'get_item_from_vector');
  result:= pointer(cardinal(v^.start)+itemsz * cardinal(index));
end;   

end.
