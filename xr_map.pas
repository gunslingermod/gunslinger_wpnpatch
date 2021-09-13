unit xr_map;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

type
  xr_integerindexed_map_base_item = packed record
    unknown:cardinal; //color?
    parent:pointer;
    left_child:pointer;
    right_child:pointer;

    key:cardinal;
    // Map item data here...
  end;
  pxr_integerindexed_map_base_item = ^xr_integerindexed_map_base_item;

  xr_integerindexed_map_base = packed record
    unknown1:cardinal;
    root:pxr_integerindexed_map_base_item;
    leaf1:pxr_integerindexed_map_base_item;
    leaf2:pxr_integerindexed_map_base_item;
    count:cardinal;
    unknown2:cardinal;
    unknown3:cardinal;
  end;
  pxr_integerindexed_map_base = ^xr_integerindexed_map_base;

  function FindItemInIntKeyMap(map:pxr_integerindexed_map_base; key:cardinal):pointer; stdcall;

implementation

function RecurseIntKeyMapItems(root:pxr_integerindexed_map_base_item; key:cardinal):pxr_integerindexed_map_base_item; stdcall;
var
  child1, child2:pxr_integerindexed_map_base_item;
begin
  result:=nil;
  if root = nil then begin
    exit;
  end;

  if root.key = key then begin
    result:=root;
  end else begin
    result:=RecurseIntKeyMapItems(root.left_child, key);
    if result = nil then begin
      result:=RecurseIntKeyMapItems(root.right_child, key);
    end;
  end;
end;

function FindItemInIntKeyMap(map:pxr_integerindexed_map_base; key:cardinal):pointer; stdcall;
var
  item:pxr_integerindexed_map_base_item;
begin
  result:=nil;
  if (map = nil) or (map.count = 0) then begin
    exit;
  end;

  item:=RecurseIntKeyMapItems(map.root, key);
  if item<>nil then begin
    result:=pointer(cardinal(@item.key)+sizeof(item.key));
  end;
end;

end.
