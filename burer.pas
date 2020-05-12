unit burer;

interface

implementation

//в CStateBurerAttackGravi::execute в ACTION_GRAVI_CONTINUE проверяем расстояние до актора, и если мало - переходим в ACTION_COMPLETED
//в CStateBurerAttackTele<Object>::ExecuteTeleContinue - аналогично
//в CStateBurerShield<Object>::check_completion() - выход из защиты при приближении актора с выносливостью
//в CStateBurerAttack<Object>::execute (xrgame.dll+10ab20) меняем приоритеты, чтобы при приближении актора с наличием стамины эту стамину отнимало

end.
