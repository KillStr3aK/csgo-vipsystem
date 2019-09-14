#if defined _viprendszer_included_
  #endinput
#endif
#define _viprendszer_included_

#include <nexd>

enum Jog {
	Semmi = 0,
	VIP = 1,
	PREMIUM = 2
}

native Jog VR_Jogosultsag(Jatekos jatekos);
native Jog VR_Hozzaadas(Jatekos admin, Jatekos celpont, Jog jogosultsag, int honap);
native Jog VR_Elvetel(char[] steamid);