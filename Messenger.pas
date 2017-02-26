unit Messenger;
//вывод инфы актору на экран через кастомстатик

interface
procedure SendMessage(msg:PChar);

implementation
uses UIUtils, GameWrappers;

procedure SendMessage(msg:PChar);
var data:pointer;
begin
  data := AddCustomStatic(CurrentGameUI(), 'gunsl_messenger', true);
  CustomStaticSetText(data, translate(msg));
end;
end.
