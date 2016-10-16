/********************************************************************** 
 Freeciv - Copyright (C) 1996 - A Kjeldberg, L Gregersen, P Unold
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
***********************************************************************/

#pragma once

/* This is duplicated in shared.h to avoid extra includes: */
#define MAX_UINT32 0xFFFFFFFF

typedef unsigned int RANDOM_TYPE;

typedef struct {
  RANDOM_TYPE v[56];
  int j, k, x;
  bool is_init;			/* initially 0 for static storage */
} RANDOM_STATE;

namespace RTFClasses
{
class Random
{
private:
	static Random *head;
	Random *next;
	RANDOM_STATE rand_state;
	RANDOM_STATE *getRandState(void) {
		return &rand_state;
	}
	void setRandState(RANDOM_STATE *state) {;
		rand_state = *state;
	}
public:
	bool isInit(void) {
		return rand_state.is_init;
	}
	RANDOM_TYPE rand(RANDOM_TYPE size);
	double dbl();
	static Random * srand(RANDOM_TYPE seed);
	static void DeleteAll();
	void test(int n);
};
};
