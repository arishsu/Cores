// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2016  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// C64 - 'C' derived language compiler
//  - 64 bit CPU
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#include "stdafx.h"

SYM *makeint(char *name);

/*
 *	68000 C compiler
 *
 *	Copyright 1984, 1985, 1986 Matthew Brandt.
 *  all commercial rights reserved.
 *
 *	This compiler is intended as an instructive tool for personal use. Any
 *	use for profit without the written consent of the author is prohibited.
 *
 *	This compiler may be distributed freely for non-commercial use as long
 *	as this notice stays intact. Please forward any enhancements or questions
 *	to:
 *
 *		Matthew Brandt
 *		Box 920337
 *		Norcross, Ga 30092
 */

extern int funcdecl;
extern int nparms;
extern char *stkname;

static Statement *ParseFunctionBody(SYM *sp);
void funcbottom(Statement *stmt);
void ListCompound(Statement *stmt);

static int round8(int n)
{
    while (n & 7) n++;
    return n;
}

// Return the stack offset where parameter storage begins.
int GetReturnBlockSize()
{
    if (isThor)
        return 40;
    else
        return 24;            /* size of return block */
}

static bool SameType(TYP *tp1, TYP *tp2)
{
	bool ret;

	printf("Enter SameType\r\n");
	while(false) {
		if (tp1->type == tp2->type) {
			if (!tp1->GetBtp() && !tp2->GetBtp()) {
				ret = true;
				break;
			}
			if (tp1->GetBtp() && !tp2->GetBtp()) {
				ret = false;
				break;
			}
			if (!tp1->GetBtp() && tp2->GetBtp()) {
				ret = false;
				break;
			}
			ret = SameType(tp1->GetBtp(),tp2->GetBtp());
			break;
		}
		else {
			ret = false;
			break;
		}
	}
xit:
	printf("Leave SameType\r\n");
	return ret;
}

void CheckParameterListMatch(SYM *s1, SYM *s2)
{
	s1 = s1->parms;
	s2 = s2->parms;
	if (!SameType(s1->tp,s2->tp))
		error(ERR_PARMLIST_MISMATCH);
}

/*      function compilation routines           */

/*
 *      funcbody starts with the current symbol being either
 *      the first parameter id or the begin for the local
 *      block. If begin is the current symbol then funcbody
 *      assumes that the function has no parameters.
 */
int ParseFunction(SYM *sp)
{
	int i;
	int oldglobal;
    SYM *sp1, *sp2, *pl, *osp;
	Statement *stmt;
	int nump;
	__int16 *ta;
	int nn;

	if (sp==NULL) {
		fatal("Compiler error: ParseFunction: SYM is NULL\r\n");
	}
	osp = sp;
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	if (sp->parent)
		dfs.printf("Parent: %s\n", (char *)sp->GetParentPtr()->name->c_str());
	dfs.printf("Parsing function: %s\n", (char *)sp->name->c_str());
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	sp->stkname = stkname;
	if (verbose) printf("Parsing function: %s\r\n", (char *)sp->name->c_str());
		oldglobal = global_flag;
        global_flag = 0;
//        nparms = 0;
    nump = nparms;
		iflevel = 0;
		// There could be unnamed parameters in a function prototype.
		printf("A");
      if(lastst == id || 1) {              /* declare parameters */
			sp->BuildParameterList(&nump);
		printf("B");
			// If the symbol has a parent then it must be a class
			// method. Search the parent table(s) for matching
			// signatures.
			if (sp->parent) {
				sp->GetParentPtr()->Find(*sp->name);
				if (sp->FindExactMatch(TABLE::matchno) > 0)
					sp = TABLE::match[TABLE::matchno-1];
				else
          error(ERR_METHOD_NOTFOUND);
				sp->PrintParameterTypes();
			}
			else {
				if (gsyms[0].Find(*sp->name)) {
					sp = TABLE::match[TABLE::matchno-1];
				}
			}
			printf("C");
    }
    if (sp != osp) {
      dfs.printf("ParseFunction: sp changed\n");
      osp->params.CopyTo(&sp->params);
      osp->proto.CopyTo(&sp->proto);
      // Should free osp here. It's not needed anymore
    }
		if (lastst == closepa) {
			NextToken();
		}
		printf("D");
		if (sp->tp->type == bt_pointer) {
			if (lastst==assign) {
				doinit(sp);
			}
			sp->IsNocall = isNocall;
			sp->IsPascal = isPascal;
			sp->IsKernel = isKernel;
			sp->IsInterrupt = isInterrupt;
			sp->IsTask = isTask;
			sp->NumParms = nump;
			isPascal = FALSE;
			isKernel = FALSE;
			isOscall = FALSE;
			isInterrupt = FALSE;
			isTask = FALSE;
			isNocall = FALSE;
//	    ReleaseLocalMemory();        /* release local symbols (parameters)*/
			global_flag = oldglobal;
			return 1;
		}
		printf("E");
		if (lastst == semicolon) {	// Function prototype
			printf("e");
			sp->IsPrototype = 1;
			sp->IsNocall = isNocall;
			sp->IsPascal = isPascal;
			sp->IsKernel = isKernel;
			sp->IsInterrupt = isInterrupt;
			sp->IsTask = isTask;
			sp->NumParms = nump;
  		sp->params.MoveTo(&sp->proto);
			isPascal = FALSE;
			isKernel = FALSE;
			isOscall = FALSE;
			isInterrupt = FALSE;
			isTask = FALSE;
			isNocall = FALSE;
//	    ReleaseLocalMemory();        /* release local symbols (parameters)*/
			goto j1;
		}
		else if(lastst != begin) {
			printf("F");
//			NextToken();
			ParameterDeclaration::Parse(2);
			// for old-style parameter list
			//needpunc(closepa);
			if (lastst==semicolon) {
				sp->IsPrototype = 1;
				sp->IsNocall = isNocall;
				sp->IsPascal = isPascal;
    			sp->IsKernel = isKernel;
				sp->IsInterrupt = isInterrupt;
    			sp->IsTask = isTask;
				sp->NumParms = nump;
				isPascal = FALSE;
    			isKernel = FALSE;
				isOscall = FALSE;
				isInterrupt = FALSE;
    			isTask = FALSE;
				isNocall = FALSE;
//				ReleaseLocalMemory();        /* release local symbols (parameters)*/
			}
			// Check for end of function parameter list.
			else if (funcdecl==2 && lastst==closepa) {
				;
			}
			else {
				sp->IsNocall = isNocall;
				sp->IsPascal = isPascal;
    			sp->IsKernel = isKernel;
				sp->IsInterrupt = isInterrupt;
    			sp->IsTask = isTask;
				isPascal = FALSE;
    			isKernel = FALSE;
				isOscall = FALSE;
				isInterrupt = FALSE;
    			isTask = FALSE;
				isNocall = FALSE;
				sp->NumParms = nump;
				stmt = ParseFunctionBody(sp);
				funcbottom(stmt);
			}
		}
//                error(ERR_BLOCK);
    else {
printf("G");
			sp->IsNocall = isNocall;
			sp->IsPascal = isPascal;
			sp->IsKernel = isKernel;
			sp->IsInterrupt = isInterrupt;
			sp->IsTask = isTask;
			isPascal = FALSE;
			isKernel = FALSE;
			isOscall = FALSE;
			isInterrupt = FALSE;
			isTask = FALSE;
			isNocall = FALSE;
			sp->NumParms = nump;
			stmt = ParseFunctionBody(sp);
			funcbottom(stmt);
    }
j1:
printf("F");
		global_flag = oldglobal;
		return 0;
}

SYM *makeint(char *name)
{  
     SYM     *sp;
        TYP     *tp;
        sp = allocSYM();
        tp = allocTYP();
        tp->type = bt_long;
        tp->size = 8;
        tp->btp = 0;
		tp->lst.Clear();
        tp->sname = new std::string("");
		tp->isUnsigned = FALSE;
		tp->isVolatile = FALSE;
        sp->SetName(name);
        sp->storage_class = sc_auto;
        sp->tp = tp;
		sp->IsPrototype = FALSE;
        currentFn->lsyms.insert(sp);
        return sp;
}

void check_table(SYM *head)
{   
	while( head != 0 ) {
		if( head->storage_class == sc_ulabel )
				lfs.printf("*** UNDEFINED LABEL - %s\n",(char *)head->name->c_str());
		head = head->GetNextPtr();
	}
}

void funcbottom(Statement *stmt)
{ 
	Statement *s, *s1;
	nl();
    check_table((SYM *)currentFn->lsyms.GetHead());
    lc_auto = 0;
    lfs.printf("\n\n*** local symbol table ***\n\n");
    ListTable(&currentFn->lsyms,0);
	// Should recurse into all the compound statements
	if (stmt==NULL)
		dfs.printf("DIAG: null statement in funcbottom.\r\n");
	else {
		if (stmt->stype==st_compound)
			ListCompound(stmt);
	}
    lfs.printf("\n\n\n");
//    ReleaseLocalMemory();        // release local symbols
	isPascal = FALSE;
	isKernel = FALSE;
	isOscall = FALSE;
	isInterrupt = FALSE;
	isNocall = FALSE;
}

std::string TraceName(SYM *sp)
{
  std::string namebuf;
  SYM *vector[64];
  int deep = 0;

  do {
    vector[deep] = sp;
    sp = sp->GetParentPtr();
    deep++;
    if (deep > 63) {
      break; // should be an error
    }
  } while (sp);
  deep--;
  namebuf = "";
  while(deep > 0) {
    namebuf += *vector[deep]->name;
    namebuf += "_";
    deep--;
  }
  namebuf += *vector[deep]->name;
  return namebuf;
}

static Statement *ParseFunctionBody(SYM *sp)
{    
	std::string lbl;
	char *p;
	Statement *stmt;
	Statement *plg;
	Statement *eplg;

	lbl[0] = 0;
	needpunc(begin,47);
     
  tmpReset();
  printf("Parse function body: %s\r\n", sp->name->c_str());
	TRACE( printf("Parse function body: %s\r\n", sp->name->c_str()); )
    //ParseAutoDeclarations();
	cseg();
	if (sp->storage_class == sc_static)
	{
		//strcpy(lbl,GetNamespace());
		//strcat(lbl,"_");
//		strcpy(lbl,sp->name);
    lbl = sp->BuildSignature(1);
		//gen_strlab(lbl);
	}
	//	put_label((unsigned int) sp->value.i);
	else {
		if (sp->storage_class == sc_global)
			lbl = "public code ";
//		strcat(lbl,sp->name);
		lbl += sp->BuildSignature(1);
		//gen_strlab(lbl);
	}
printf("B");
  p = my_strdup((char *)lbl.c_str());
printf("b");
	GenerateMonadic(op_fnname,0,make_string(p));
	currentFn = sp;
	currentFn->IsLeaf = TRUE;
	currentFn->DoesThrow = FALSE;
	currentFn->UsesPredicate = FALSE;
	regmask = 0;
	bregmask = 0;
	currentStmt = (Statement *)NULL;
printf("C");
	stmt = ParseCompoundStatement();
printf("D");
//	stmt->stype = st_funcbody;
	if (isThor)
		GenerateFunction(sp, stmt);
	else if (isTable888)
		GenerateTable888Function(sp, stmt);
	else if (isRaptor64)
		GenerateRaptor64Function(sp, stmt);
	else if (is816)
		Generate816Function(sp, stmt);
	else if (isFISA64)
		GenerateFISA64Function(sp, stmt);
printf("E");

	flush_peep();
	if (sp->storage_class == sc_global) {
		ofs.printf("endpublic\r\n\r\n");
	}
	ofs.printf("%sSTKSIZE_ EQU %d\r\n", (char *)sp->name->c_str(), tmpVarSpace() + lc_auto);
	return stmt;
}
