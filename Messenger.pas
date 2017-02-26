unit Messenger;
//вывод инфы актору на экран через кастомстатик

interface
procedure SendMessage(msg:PChar; max_difficulty:cardinal=$FFFFFFFF{all difficulties});

implementation
uses UIUtils, gunsl_config;

procedure SendMessage(msg:PChar; max_difficulty:cardinal);
var data:pointer;
begin
  if GetCurrentDifficulty()>max_difficulty then exit;
  data := AddCustomStatic(CurrentGameUI(), 'gunsl_messenger', true);
  CustomStaticSetText(data, translate(msg));
end;
end.
