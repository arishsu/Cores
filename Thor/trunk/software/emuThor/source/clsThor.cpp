#include "stdafx.h"
#include "clsThor.h"
#include "insn.h"

extern clsSystem system1;

void clsThor::Reset()
{
	pc = 0xFFFFFFFFFFFC0000LL;
	tick = 0;
	gp[0] = 0;
	ca[0] = 0;
	StatusHWI = true;
	StatusDBG = false;
	StatusEXL = 0;
	string_pc = 0;
}

bool clsThor::IsKM()
{
	return StatusHWI || (StatusEXL > 0) || StatusDBG;
}

int clsThor::GetMode()
{
	if (StatusHWI)
		return mode = 1;
	if (StatusDBG)
		return mode = 3;
	if (StatusEXL)
		return mode = 2;
	return mode = 0;
}

__int64 clsThor::GetGP(int rg)
{
	if (rg < 0 || rg > 63)
		return 0xDEADEADDEADDEAD;
	switch(rg) {
	case 0: return 0;	// ignore update to r0.
	case 27:
		rg = rg + GetMode();
		// Fall through
	default:
		return gp[rg];
	}
}


void clsThor::SetGP(int rg, __int64 val)
{
	if (rg < 0 || rg > 63)
		return;
	switch(rg) {
	case 0:	;	// ignore update to r0.
	case 27:
		rg = rg + GetMode();
		// Fall through
	default:
		gp[rg] = val;
	}
}

// Compute d[Rn] address info
void clsThor::dRn(int b1, int b2, int b3, int *Ra, int *Sg, __int64 *disp)
{
	if (Ra) *Ra = b1 & 0x3f;
	if (Sg) *Sg = (b3 >> 5) & 7;
	if (disp) *disp = ((b2 >> 4) & 0xF) | ((b3 & 0x1f) << 4);
	if (*disp & 0x100)
		*disp |= 0xFFFFFFFFFFFFFE00LL;
	if (imm_prefix) {
		*disp &= 0xFF;
		*disp |= imm;
	}
}

int clsThor::WriteMask(int ad, int sz)
{
	switch(sz) {
	case 0:	return 1 << (ad & 7);
	case 1:	return 3 << (ad & 6);
	case 2: return (ad & 4) ? 0xF0 : 0x0F;
	case 3:	return 0xFF;
	}
}

__int64 clsThor::GetSpr(int Sprn)
{
	__int64 tmp;
	int nn;

	if (Sprn < 16) {
		return pr[Sprn];
	}
	else if (Sprn < 32) {
		Sprn -= 16;
		return ca[Sprn];
	}
	else if (Sprn < 40) {
		return seg_base[Sprn-32];
	}
	else if (Sprn < 48) {
		return seg_limit[Sprn-32];
	}
	else {
		switch(Sprn) {
		case 50:	return tick; break;
		case 51:	return lc; break;
		case 52:
			tmp = 0;
			for (nn = 0; nn < 16; nn++) {
				tmp |= pr[nn] << (nn * 4);
			}
			return tmp;
		case 60:	return bir; break;
		case 61:
			switch(bir) {
			case 0: return dbad0; break;
			case 1: return dbad1; break;
			case 2: return dbad2; break;
			case 3: return dbad3; break;
			case 4: return dbctrl; break;
			case 5: return dbstat; break;
			}
		}
	}
	return 0xDEADDEADDEADDEAD;
}

void clsThor::SetSpr(int Sprn, __int64 val)
{
	int nn;

	if (Sprn < 16)
		pr[Sprn] = val;
	else if (Sprn < 32) {
		Sprn -= 16;
		ca[Sprn] = val;
		ca[0] = 0;
		ca[15] = pc;
	}
	else if (Sprn < 40) {
		seg_base[Sprn-32] = val & 0xFFFFFFFFFFFFF000LL;
	}
	else if (Sprn < 48) {
		seg_limit[Sprn-32] = val & 0xFFFFFFFFFFFFF000LL;
	}
	else {
		switch(Sprn) {
		case 51:	lc = val; break;
		case 52:
			for (nn = 0; nn < 16; nn++) {
				pr[nn] = (val >> (nn * 4)) & 0xF;
			}
			break;
		case 60:	bir = val & 0xFFLL; break;
		case 61:
			switch(bir) {
			case 0: dbad0 = val; break;
			case 1: dbad1 = val; break;
			case 2: dbad2 = val; break;
			case 3: dbad3 = val; break;
			case 4: dbctrl = val; break;
			case 5: dbstat = val; break;
			}
		}
	}
}

void clsThor::Step()
{
	bool ex = true;	// execute instruction
	unsigned int opcode, func;
	__int64 disp;
	int Ra,Rb,Rc,Rt,Pn,Cr,Ct;
	int Sprn,Sg;
	int b1, b2, b3, b4;
	int nn;
	__int64 dat;

	if (IRQActive()) {
		StatusHWI = true;
		if (string_pc)
			ca[14] = string_pc;
		else
			ca[14] = pc;
		pc = ca[12] + (vecno << 4);
	}
	gp[0] = 0;
	ca[0] = 0;
	if (imcd > 0) {
		imcd--;
		if (imcd==1)
			im = 0;
	}
	tick = tick + 1;
	pred = ReadByte(pc);
	pc++;
	for (nn = 39; nn >= 0; nn--)
		pcs[nn] = pcs[nn-1];
	pcs[0] = pc;
	switch (pred) {
	case 0x00:	// BRK instruction
		return;
	case 0x10:	// NOP
		return;
	case 0x20:
		imm = ReadByte(pc) << 8;
		pc++;
		if (imm & 0x8000LL)
			imm |= 0xFFFFFFFFFFFF0000LL;
		imm_prefix = true;
		return;
	case 0x30:
		imm = ReadByte(pc) << 8;
		pc++;
		imm |= ReadByte(pc) << 16;
		pc++;
		if (imm & 0x800000LL)
			imm |= 0xFFFFFFFFFF000000LL;
		imm_prefix = true;
		return;
	case 0x40:
		imm = ReadByte(pc) << 8;
		pc++;
		imm |= ReadByte(pc) << 16;
		pc++;
		imm |= ReadByte(pc) << 24;
		pc++;
		if (imm & 0x80000000LL)
			imm |= 0xFFFFFFFF00000000LL;
		imm_prefix = true;
		return;
	case 0x50:
		imm = ReadByte(pc) << 8;
		pc++;
		imm |= ReadByte(pc) << 16;
		pc++;
		imm |= ReadByte(pc) << 24;
		pc++;
		imm |= ReadByte(pc) << 32;
		pc++;
		if (imm & 0x8000000000LL)
			imm |= 0xFFFFFF0000000000LL;
		imm_prefix = true;
		return;
	case 0x60:
		imm = ReadByte(pc) << 8;
		pc++;
		imm |= ReadByte(pc) << 16;
		pc++;
		imm |= ReadByte(pc) << 24;
		pc++;
		imm |= ReadByte(pc) << 32;
		pc++;
		imm |= ReadByte(pc) << 40;
		pc++;
		if (imm & 0x800000000000LL)
			imm |= 0xFFFF000000000000LL;
		imm_prefix = true;
		return;
	case 0x70:
		imm = ReadByte(pc) << 8;
		pc++;
		imm |= ReadByte(pc) << 16;
		pc++;
		imm |= ReadByte(pc) << 24;
		pc++;
		imm |= ReadByte(pc) << 32;
		pc++;
		imm |= ReadByte(pc) << 40;
		pc++;
		imm |= ReadByte(pc) << 48;
		pc++;
		if (imm & 0x80000000000000LL)
			imm |= 0xFF00000000000000LL;
		imm_prefix = true;
		return;
	case 0x80:
		imm = ReadByte(pc) << 8;
		pc++;
		imm |= ReadByte(pc) << 16;
		pc++;
		imm |= ReadByte(pc) << 24;
		pc++;
		imm |= ReadByte(pc) << 32;
		pc++;
		imm |= ReadByte(pc) << 40;
		pc++;
		imm |= ReadByte(pc) << 48;
		pc++;
		imm |= ReadByte(pc) << 56;
		pc++;
		imm_prefix = true;
		return;
	default: {
		int rv;

		rv = pr[pred>>4];
		switch(pred & 15) {
		case PF: ex = false; break;
		case PT: ex = true; break;
		case PEQ: ex = rv & 1; break;
		case PNE: ex = !(rv & 1); break;
		case PLE: ex = (rv & 1)||(rv & 2); break;
		case PGT: ex = !((rv & 1)||(rv & 2)); break;
		case PGE: ex = (rv & 2)==0; break;
		case PLT: ex = (rv & 2)!=0; break;
		case PLEU: ex = (rv & 1)||(rv & 4); break;
		case PGTU: ex = !((rv & 1)||(rv & 4)); break;
		case PGEU: ex = (rv & 4)==0; break;
		case PLTU: ex = (rv & 4)!=0; break;
		default:	ex = false;
		}
		}
	}
	opcode = ReadByte(pc);
	pc++;
	if ((opcode & 0xF0)==0x00) {	// TST
		b1 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Pn = opcode & 0x0f;
			pr[Pn] = 0;
			if (GetGP(Ra)==0)
				pr[Pn] |= 1;
			if ((signed)GetGP(Ra) < (signed)0)
				pr[Pn] |= 2;
		}
		imm_prefix = false;
		return;
	}
	if ((opcode & 0xF0)==0x10) {	// CMP
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rb = ((b1 & 0xC0) >> 6) | ((b2 & 0x0f)<<2);
			Pn = opcode & 0x0f;
			pr[Pn] = 0;
			if (GetGP(Ra)==GetGP(Rb))
				pr[Pn] |= 1;
			if (GetGP(Ra) < GetGP(Rb))
				pr[Pn] |= 2;
			if ((unsigned __int64)GetGP(Ra) < (unsigned __int64)GetGP(Rb))
				pr[Pn] |= 4;
		}
		imm_prefix = false;
		return;
	}
	if ((opcode & 0xF0)==0x20) {	// CMPI
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			if (imm_prefix) {
				imm |= ((b2 << 2) & 0xFF) | ((b1 >> 6) & 3);
			}
			else {
				imm = ((b2 << 2) & 0x3FF) | ((b1 >> 6) & 3);
				if (imm & 0x200)
					imm |= 0xFFFFFFFFFFFFFE00LL;
			}
			Pn = opcode & 0x0f;
			pr[Pn] = 0;
			if (GetGP(Ra)==imm)
				pr[Pn] |= 1;
			if (GetGP(Ra) < (signed)imm)
				pr[Pn] |= 2;
			if ((unsigned __int64)GetGP(Ra) < (unsigned __int64)imm)
				pr[Pn] |= 4;
		}
		imm_prefix = false;
		return;
	}
	if ((opcode & 0xF0)==0x30) {	// BR
		disp = ReadByte(pc);
		pc++;
		if (ex) {
			disp = disp | ((opcode & 0x0F) << 8);
			if (disp & 0x800)
				disp |= 0xFFFFFFFFFFFFF000LL;
			pc = pc + disp;
		}
		imm_prefix = false;
		return;
	}
	switch(opcode) {

	case _2ADDUI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,(GetGP(Ra)<<1) + imm);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case _4ADDUI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,(GetGP(Ra)<<2) + imm);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case _8ADDUI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,(GetGP(Ra)<<3) + imm);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case _16ADDUI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,(GetGP(Ra)<<4) + imm);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case ADDUI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,GetGP(Ra) + imm);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case ADDUIS:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = Ra;
			if (imm_prefix) {
				imm |= ((b2 << 2)&0xFC) | ((b1 >> 6) & 0x3);
			}
			else {
				imm = ((b2 << 2)&0x3FC) | ((b1 >> 6) & 0x3);
				if (imm & 0x200)
					imm |= 0xFFFFFFFFFFFFFE00LL;
			}
			SetGP(Rt,GetGP(Ra) + imm);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case ANDI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,GetGP(Ra) & imm);
			gp[0] = 0;
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case BITI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			unsigned __int64 res;
			Ra = b1 & 0x3f;
			Pn = ((b2 & 0x3) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			res = GetGP(Ra) & imm;
			pr[Pn] = 0;
			if (res == 0)
				pr[Pn] |= 1;
			if (res & 0x8000000000000000LL)
				pr[Pn] |= 2;
			if (res & 1)
				pr[Pn] |= 4;
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case CLI:
		if (ex) {
			im = 0;
		}
		ca[15] = pc;
		imm_prefix = false;
		break;

	case EORI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,GetGP(Ra) ^ imm);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case JSR:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		b4 = ReadByte(pc);
		pc++;
		if (ex) {
			Ct = b1 & 0x0F;
			Cr = (b1 & 0xF0) >> 4;
			if (Ct != 0)
				ca[Ct] = pc;
			disp = (b4 << 16) | (b3 << 8) | b2;
			if (disp & 0x800000)
				disp |= 0xFFFFFFFFFF000000LL;
			if (imm_prefix) {
				disp &= 0xFF;
				disp |= imm;
			}
			if (Cr==15)
				pc = disp + pc - 6;
			else
				pc = disp + ca[Cr];
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case JSRS:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ct = b1 & 0x0F;
			Cr = (b1 & 0xF0) >> 4;
			ca[Ct] = pc;
			ca[0] = 0;
			disp = (b3 << 8) | b2;
			if (disp & 0x8000)
				disp |= 0xFFFFFFFFFFFF0000LL;
			if (imm_prefix) {
				disp &= 0xFFLL;
				disp |= imm;
			}
			if (Cr==15)
				pc = disp + pc - 5;
			else
				pc = disp + ca[Cr];
			if (Ct != 0)
				sub_depth++;
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case JSRR:
		b1 = ReadByte(pc);
		pc++;
		if (ex) {
			Ct = b1 & 0x0F;
			Cr = (b1 & 0xF0) >> 4;
			if (Ct != 0)
				ca[Ct] = pc;
			disp = 0;
			if (imm_prefix) {
				disp &= 0xFF;
				disp |= imm;
			}
			pc = disp + ca[Cr];
			if (Ct != 0)
				sub_depth++;
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LB:
	case LVB:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			dat = system1->Read(ea);
			if (ea & 4)
				dat = (dat >> 32);
			if (ea & 2)
				dat = (dat >> 16);
			if (ea & 1)
				dat = (dat >> 8);
			dat &= 0xFFLL;
			if (dat & 0x80LL)
				dat |= 0xFFFFFFFFFFFFFF00LL;
			SetGP(Rt,dat);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LBU:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			dat = system1->Read(ea);
			if (ea & 4)
				dat = (dat >> 32);
			if (ea & 2)
				dat = (dat >> 16);
			if (ea & 1)
				dat = (dat >> 8);
			dat &= 0xFFLL;
			SetGP(Rt,dat);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LC:
	case LVC:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			dat = system1->Read(ea);
			if (ea & 4)
				dat = (dat >> 32);
			if (ea & 2)
				dat = (dat >> 16);
			dat &= 0xFFFF;
			if (dat & 0x8000LL)
				dat |= 0xFFFFFFFFFFFF0000LL;
			SetGP(Rt,dat);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LCU:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			dat = system1->Read(ea);
			if (ea & 4)
				dat = (dat >> 32);
			if (ea & 2)
				dat = (dat >> 16);
			dat &= 0xFFFFLL;
			SetGP(Rt,dat);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LDIS:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Sprn = b1 & 0x3f;
			if (imm_prefix) {
				imm |= ((b2 << 2) & 0xFF) | ((b1 >> 6) & 3);
			}
			else {
				imm = ((b2 << 2) & 0x3FF) | ((b1 >> 6) & 3);
				if (imm & 0x200)
					imm |= 0xFFFFFFFFFFFFFE00LL;
			}
			if (Sprn < 16) {
				pr[Sprn] = imm & 0xF;
			}
			else if (Sprn < 32) {
				ca[Sprn-16] = imm;
				ca[0] = 0;
				ca[15] = pc;
			}
			else if (Sprn < 40) {
				seg_base[Sprn-32] = imm & 0xFFFFFFFFFFFFF000LL;
			}
			else if (Sprn < 48) {
				seg_limit[Sprn-40] = imm & 0xFFFFFFFFFFFFF000LL;
			}
			else {
				switch(Sprn) {
				case 51:	lc = imm; break;
				case 52:
					for (nn = 0; nn < 16; nn++) {
						pr[nn] = (imm >> (nn * 4)) & 0xF;
					}
					break;
				case 60:	bir = imm & 0xFFLL; break;
				case 61:
					switch(bir) {
					case 0: dbad0 = imm; break;
					case 1: dbad1 = imm; break;
					case 2: dbad2 = imm; break;
					case 3: dbad3 = imm; break;
					case 4: dbctrl = imm; break;
					case 5: dbstat = imm; break;
					}
				}
			}
		}
		imm_prefix = false;
		ca[15] = pc;
		return;

	case LDI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = b1 & 0x3f;
			if (imm_prefix) {
				imm |= ((b2 << 2) & 0xFF) | ((b1 >> 6) & 3);
			}
			else {
				imm = ((b2 << 2) & 0x3FF) | ((b1 >> 6) & 3);
				if (imm & 0x200)
					imm |= 0xFFFFFFFFFFFFFE00LL;
			}
			SetGP(Rt,imm);
		}
		imm_prefix = false;
		ca[15] = pc;
		return;

	case LH:
	case LVH:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			dat = system1->Read(ea);
			if (ea & 4)
				dat = (dat >> 32);
			dat &= 0xFFFFFFFFLL;
			if (dat & 0x80000000LL)
				dat |= 0xFFFFFFFF00000000LL;
			SetGP(Rt,dat);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LHU:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			dat = system1->Read(ea);
			if (ea & 4)
				dat = (dat >> 32);
			dat &= 0xFFFFFFFFLL;
			SetGP(Rt,dat);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LLA:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			SetGP(Rt,ea);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LOGIC:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rb = ((b2 << 2) & 0x3c) | (b1 >> 6);
			Rt = (b2 >> 4) | ((b3 & 0x3) << 4);
			func = b3 >> 2;
			switch(func) {
			case AND:
				SetGP(Rt, GetGP(Ra) & GetGP(Rb));
				break;
			case OR:
				SetGP(Rt, GetGP(Ra) | GetGP(Rb));
				break;
			case EOR:
				SetGP(Rt, GetGP(Ra) ^ GetGP(Rb));
				break;
			case NAND:
				SetGP(Rt, ~(GetGP(Ra) & GetGP(Rb)));
				break;
			case NOR:
				SetGP(Rt, ~(GetGP(Ra) | GetGP(Rb)));
				break;
			case ENOR:
				SetGP(Rt, ~(GetGP(Ra) ^ GetGP(Rb)));
				break;
			}
		}
		ca[15] = pc;
		imm_prefix = 0;
		return;

	case LOOP:
		disp = ReadByte(pc);
		pc++;
		if (ex) {
			if (disp & 0x80LL)
				disp |= 0xFFFFFFFFFFFFFF00LL;
			if (lc > 0) {
				lc--;
				pc = pc + disp;
			}
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case LW:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + gp[Ra];
			dat = system1->Read(ea);
			/*
			if (ea & 4)
				dat = (dat >> 32);
			if (ea & 2)
				dat = (dat >> 16);
			*/
			SetGP(Rt,dat);
		}
		imm_prefix = false;
		ca[15] = pc;
		return;

	case LWS:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + GetGP(Ra);
			dat = system1->Read(ea);
			/*
			if (ea & 4)
				dat = (dat >> 32);
			if (ea & 2)
				dat = (dat >> 16);
			if (ea & 1)
				dat = (dat >> 8);
			*/
			SetSpr(Rt, dat);
		}
		imm_prefix = false;
		ca[15] = pc;
		return;

	case MFSPR:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Sprn = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | ((b1 >> 6) & 3);
			SetGP(Rt,GetSpr(Sprn));
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case GRPA7:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			switch(b2 >> 4) {
			case MOV:
				SetGP(Rt, GetGP(Ra));
				break;
			case SXB:
				dat = GetGP(Ra);
				if (dat & 0x80LL)
					dat |= 0xFFFFFFFFFFFFFF80LL;
				SetGP(Rt,dat);
				break;
			case SXC:
				dat = GetGP(Ra);
				if (dat & 0x8000LL)
					dat |= 0xFFFFFFFFFFFF8000LL;
				SetGP(Rt,dat);
				break;
			case SXH:
				dat = GetGP(Ra);
				if (dat & 0x80000000LL)
					dat |= 0xFFFFFFFF80000000LL;
				SetGP(Rt,dat);
				break;
			case ZXB:
				dat = GetGP(Ra);
				dat &= 0xFFLL;
				SetGP(Rt,dat);
				break;
			case ZXC:
				dat = GetGP(Ra);
				dat &= 0xFFFFLL;
				SetGP(Rt,dat);
				break;
			case ZXH:
				dat = GetGP(Ra);
				dat &= 0xFFFFFFFFLL;
				SetGP(Rt,dat);
				break;
			}
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case MTSPR:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Sprn = ((b2 & 0xF) << 2) | ((b1 >> 6) & 3);
			SetSpr(Sprn, GetGP(Ra));
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case ORI:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rt = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			if (imm_prefix) {
				imm |= ((b3 << 4)&0xF0) | ((b2 >> 4) & 0xF);
			}
			else {
				imm = (b3 << 4) | ((b2 >> 4) & 0xF);
				if (imm & 0x800)
					imm |= 0xFFFFFFFFFFFFF000LL;
			}
			SetGP(Rt,GetGP(Ra) | imm);
			gp[0] = 0;
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case RR:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Ra = b1 & 0x3f;
			Rb = ((b2 << 2) & 0x3c) | (b1 >> 6);
			Rt = (b2 >> 4) | ((b3 & 0x3) << 4);
			func = b3 >> 2;
			switch(func) {
			case MULU:
				SetGP(Rt,(unsigned __int64)GetGP(Ra) * (unsigned __int64)GetGP(Rb));
				break;
			case _2ADDU:
				SetGP(Rt,(GetGP(Ra) << 1) + GetGP(Rb));
				break;
			case _4ADDU:
				SetGP(Rt,(GetGP(Ra) << 2) + GetGP(Rb));
				break;
			case _8ADDU:
				SetGP(Rt,(GetGP(Ra) << 3) + GetGP(Rb));
				break;
			case _16ADDU:
				SetGP(Rt,(GetGP(Ra) << 4) + GetGP(Rb));
				break;
			}
		}
		ca[15] = pc;
		imm_prefix = 0;
		return;

	case RTE:
		if (ex) {
			if (StatusEXL > 0)
				StatusEXL--;
			pc = ca[13];
		}
		ca[15] = pc;
		imm_prefix = false;
		break;

	case RTI:
		if (ex) {
			im = 0;
			StatusHWI = false;
			pc = ca[14];
		}
		ca[15] = pc;
		imm_prefix = false;
		break;

	case RTS:
		b1 = ReadByte(pc);
		pc++;
		if (ex) {
			Cr = (b1 & 0xF0) >> 4;
			pc = ca[Cr] + (b1 & 0x0F);
			if (sub_depth > 0) sub_depth--;
		}
		ca[15] = pc;
		imm_prefix = 0;
		return;

	case RTSQ:
		if (ex) {
			pc = ca[1];
			if (sub_depth > 0) sub_depth--;
		}
		ca[15] = pc;
		imm_prefix = 0;
		return;

	case SB:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rb = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + GetGP(Ra);
			system1->Write(ea,GetGP(Rb),(0x1 << (ea & 7)) & 0xFF);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case SC:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rb = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + GetGP(Ra);
			system1->Write(ea,GetGP(Rb),(0x3 << (ea & 7)) & 0xFF);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case SH:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rb = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + GetGP(Ra);
			system1->Write(ea,GetGP(Rb),(0xF << (ea & 7)) & 0xFF);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case SHIFT:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			unsigned __int64 a,b;
			Ra = b1 & 0x3f;
			Rb = ((b2 << 2) & 0x3c) | (b1 >> 6);
			Rt = (b2 >> 4) | ((b3 & 0x3) << 4);
			func = b3 >> 2;
			switch(func) {
			case SHL:
				SetGP(Rt, GetGP(Ra) << (GetGP(Rb) & 0x3f));
				break;
			case SHLI:
				SetGP(Rt, GetGP(Ra) << Rb);
				break;
			case SHRUI:
				SetGP(Rt, (unsigned __int64)GetGP(Ra) >> Rb);
				break;
			case ROLI:
				a = (unsigned __int64)GetGP(Ra) << Rb;
				b = (unsigned __int64)GetGP(Ra) >> (64-Rb);
				SetGP(Rt, (unsigned __int64)a|b);
				break;
			case RORI:
				a = (unsigned __int64)GetGP(Ra) >> Rb;
				b = (unsigned __int64)GetGP(Ra) << (64-Rb);
				SetGP(Rt, (unsigned __int64)a|b);
				break;
			}
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	// The stop instruction controls the clock rate. It's just about useless
	// to try to emulate as the emulation rate is controlled by the user.
	// So for now, it's a NOP.
	case STP:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		ca[15] = pc;
		imm_prefix = false;
		return;

	case STSET:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			string_pc = pc - 5;	// address of the string instruction
			Ra = b1 & 0x3f;
			Rb = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			do {
				Sg = b3 >> 5;
				ea = GetGP(Ra) + seg_base[Sg];
				switch((b3 >> 2) & 3) {
				case 0:
					dat = GetGP(Rb) & 0xFFLL;
					dat = (dat << 56) | (dat << 48) | (dat << 40) | (dat << 32)
						| (dat << 24) | (dat << 16) | (dat << 8) | dat;
					SetGP(Ra,GetGP(Ra) + ((b3&16) ? -1 : 1));
					system1->Write(ea,dat,WriteMask(ea,0),0);
					break;
				case 1:
					dat = GetGP(Rb) & 0xFFFFLL;
					dat = (dat << 48) | (dat << 32)
						| (dat << 16) | dat;
					SetGP(Ra,GetGP(Ra) + ((b3&16) ? -2 : 2));
					system1->Write(ea,dat,WriteMask(ea,1),0);
					break;
				case 2:
					dat = GetGP(Rb) & 0xFFFFFFFFLL;
					dat = (dat << 32) | dat;
					SetGP(Ra,GetGP(Ra) + ((b3&16) ? -4 : 4));
					system1->Write(ea,dat,WriteMask(ea,2),0);
					break;
				case 3:
					dat = GetGP(Rb);
					SetGP(Ra,GetGP(Ra) + ((b3&16) ? -8 : 8));
					system1->Write(ea,dat,WriteMask(ea,3),0);
					break;
				}
				if (lc==0) {
					string_pc = 0;
					break;
				}
				lc--;
			} while (!IRQActive());
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case SW:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rb = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + GetGP(Ra);
			system1->Write(ea,GetGP(Rb),(0xFF << (ea & 7)) & 0xFF);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	case SWS:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		b3 = ReadByte(pc);
		pc++;
		if (ex) {
			Rb = ((b2 & 0xF) << 2) | (( b1 >> 6) & 3);
			dRn(b1,b2,b3,&Ra,&Sg,&disp);
			ea = (unsigned __int64) disp + seg_base[Sg] + GetGP(Ra);
			system1->Write(ea,GetSpr(Rb),(0xFF << (ea & 7)) & 0xFF);
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	// The SYNC instruction is a pipeline control. The pipeline is
	// not emulated by this emulator. So it's treated as a NOP.
	case SYNC:
		ca[15] = pc;
		imm_prefix = false;
		break;

	case SYS:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			Ct = b1 & 0xF;
			Cr = b1 >> 4;
			ca[Ct] = pc;
			ca[0] = 0;
			pc = (b2 << 4) + ca[Cr];
			if (StatusEXL < 255)
				StatusEXL++;
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	// The TLB isn't implemented yet. the boot rom currently just
	// sets up the TLB registers and then leaves it disabled.
	case TLB:
		b1 = ReadByte(pc);
		pc++;
		b2 = ReadByte(pc);
		pc++;
		if (ex) {
			;
		}
		ca[15] = pc;
		imm_prefix = false;
		return;

	}
}