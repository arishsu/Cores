	data
	align	8
	fill.b	1,0x00
	align	8
	fill.b	16,0x00
	align	8
	align	8
	fill.b	1984,0x00
	align	8
	align	8
	code
	align	16
public code GetScreenLocation_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_0
	      	mov  	bp,sp
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	lw   	r3,1616[r3]
	      	mov  	r1,r3
console_1:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_0:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_1
endpublic

public code GetCurrAttr_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_2
	      	mov  	bp,sp
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	lhu  	r3,1640[r3]
	      	mov  	r1,r3
console_3:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_2:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_3
endpublic

public code SetCurrAttr_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_4
	      	mov  	bp,sp
	      	lh   	r4,24[bp]
	      	and  	r3,r4,#4294966272
	      	push 	r3
	      	bsr  	GetJCBPtr_
	      	pop  	r3
	      	mov  	r4,r1
	      	sh   	r3,1640[r4]
console_5:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_4:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_5
endpublic

public code SetVideoReg_:
	      	subui	sp,sp,#16
	      	push 	bp
	      	mov  	bp,sp
	      	     	         lw   r1,24[bp]
         lw   r2,32[bp]
         asl  r1,r1,#2
         sh   r2,$FFDA0000[r1]
     
console_7:
	      	mov  	sp,bp
	      	pop  	bp
	      	rtl  	#16
endpublic

public code SetCursorPos_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_8
	      	mov  	bp,sp
	      	subui	sp,sp,#8
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lw   	r3,32[bp]
	      	sc   	r3,1638[r11]
	      	lw   	r3,24[bp]
	      	sc   	r3,1636[r11]
	      	bsr  	UpdateCursorPos_
console_9:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_8:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_9
endpublic

public code SetCursorCol_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_10
	      	mov  	bp,sp
	      	subui	sp,sp,#8
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lw   	r3,24[bp]
	      	sc   	r3,1638[r11]
	      	bsr  	UpdateCursorPos_
console_11:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_10:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_11
endpublic

public code GetCursorPos_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_12
	      	mov  	bp,sp
	      	subui	sp,sp,#8
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lcu  	r4,1638[r11]
	      	lcu  	r6,1636[r11]
	      	asli 	r5,r6,#8
	      	or   	r3,r4,r5
	      	mov  	r1,r3
console_13:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_12:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_13
endpublic

public code GetTextCols_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_14
	      	mov  	bp,sp
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	lcu  	r3,1634[r3]
	      	mov  	r1,r3
console_15:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_14:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_15
endpublic

public code GetTextRows_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_16
	      	mov  	bp,sp
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	lcu  	r3,1632[r3]
	      	mov  	r1,r3
console_17:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_16:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_17
endpublic

public code AsciiToScreen_:
	      	subui	sp,sp,#16
	      	push 	bp
	      	mov  	bp,sp
	      	lcu  	r3,24[bp]
	      	cmp  	r4,r3,#91
	      	bne  	r4,console_19
	      	ldi  	r1,#27
console_21:
	      	mov  	sp,bp
	      	pop  	bp
	      	rtl  	#16
console_19:
	      	lcu  	r3,24[bp]
	      	cmp  	r4,r3,#93
	      	bne  	r4,console_22
	      	ldi  	r1,#29
	      	bra  	console_21
console_22:
	      	lcu  	r3,24[bp]
	      	andi 	r3,r3,#255
	      	sc   	r3,24[bp]
	      	lcu  	r3,24[bp]
	      	ori  	r3,r3,#256
	      	sc   	r3,24[bp]
	      	lcu  	r4,24[bp]
	      	and  	r3,r4,#32
	      	bne  	r3,console_24
	      	lcu  	r3,24[bp]
	      	mov  	r1,r3
	      	bra  	console_21
console_24:
	      	lcu  	r4,24[bp]
	      	and  	r3,r4,#64
	      	bne  	r3,console_26
	      	lcu  	r3,24[bp]
	      	mov  	r1,r3
	      	bra  	console_21
console_26:
	      	lcu  	r4,24[bp]
	      	and  	r3,r4,#415
	      	sc   	r3,24[bp]
	      	lcu  	r3,24[bp]
	      	mov  	r1,r3
	      	bra  	console_21
endpublic

public code ScreenToAscii_:
	      	subui	sp,sp,#16
	      	push 	bp
	      	mov  	bp,sp
	      	lcu  	r3,24[bp]
	      	andi 	r3,r3,#255
	      	sc   	r3,24[bp]
	      	lcu  	r3,24[bp]
	      	cmp  	r4,r3,#27
	      	bne  	r4,console_29
	      	ldi  	r1,#91
console_31:
	      	mov  	sp,bp
	      	pop  	bp
	      	rtl  	#16
console_29:
	      	lcu  	r3,24[bp]
	      	cmp  	r4,r3,#29
	      	bne  	r4,console_32
	      	ldi  	r1,#93
	      	bra  	console_31
console_32:
	      	lcu  	r3,24[bp]
	      	cmpu 	r4,r3,#27
	      	bge  	r4,console_34
	      	lcu  	r3,24[bp]
	      	addui	r3,r3,#96
	      	sc   	r3,24[bp]
console_34:
	      	lcu  	r3,24[bp]
	      	mov  	r1,r3
	      	bra  	console_31
endpublic

public code UpdateCursorPos_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_36
	      	mov  	bp,sp
	      	subui	sp,sp,#16
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lcu  	r4,1636[r11]
	      	lcu  	r5,1634[r11]
	      	mulu 	r4,r4,r5
	      	lcu  	r5,1638[r11]
	      	addu 	r3,r4,r5
	      	sxc  	r3,r3
	      	sw   	r3,-16[bp]
	      	push 	-16[bp]
	      	push 	#11
	      	bsr  	SetVideoReg_
	      	addui	sp,sp,#16
console_37:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_36:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_37
endpublic

public code HomeCursor_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_38
	      	mov  	bp,sp
	      	subui	sp,sp,#8
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	sc   	r0,1638[r11]
	      	sc   	r0,1636[r11]
	      	bsr  	UpdateCursorPos_
console_39:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_38:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_39
endpublic

public code CalcScreenLocation_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_40
	      	mov  	bp,sp
	      	subui	sp,sp,#16
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lcu  	r4,1636[r11]
	      	lcu  	r5,1634[r11]
	      	mulu 	r4,r4,r5
	      	lcu  	r5,1638[r11]
	      	addu 	r3,r4,r5
	      	sxc  	r3,r3
	      	sw   	r3,-16[bp]
	      	push 	-16[bp]
	      	push 	#11
	      	bsr  	SetVideoReg_
	      	addui	sp,sp,#16
	      	push 	r3
	      	bsr  	GetScreenLocation_
	      	pop  	r3
	      	mov  	r4,r1
	      	lw   	r6,-16[bp]
	      	asli 	r5,r6,#2
	      	addu 	r3,r4,r5
	      	mov  	r1,r3
console_41:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_40:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_41
endpublic

public code ClearScreen_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_42
	      	mov  	bp,sp
	      	subui	sp,sp,#40
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	bsr  	GetScreenLocation_
	      	mov  	r3,r1
	      	sw   	r3,-8[bp]
	      	lcu  	r3,1632[r11]
	      	lcu  	r4,1634[r11]
	      	mul  	r3,r3,r4
	      	sw   	r3,-24[bp]
	      	push 	r3
	      	bsr  	GetCurrAttr_
	      	pop  	r3
	      	mov  	r4,r1
	      	push 	r3
	      	push 	r4
	      	push 	#32
	      	bsr  	AsciiToScreen_
	      	addui	sp,sp,#8
	      	pop  	r4
	      	pop  	r3
	      	mov  	r5,r1
	      	sxc  	r5,r5
	      	or   	r3,r4,r5
	      	sh   	r3,-36[bp]
	      	push 	-24[bp]
	      	lh   	r3,-36[bp]
	      	sxh  	r3,r3
	      	push 	r3
	      	push 	-8[bp]
	      	bsr  	memsetH_
	      	addui	sp,sp,#24
console_43:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_42:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_43
endpublic

public code ClearBmpScreen_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_44
	      	mov  	bp,sp
	      	push 	#524288
	      	push 	#0
	      	push 	#4194304
	      	bsr  	memsetW_
	      	addui	sp,sp,#24
console_45:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_44:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_45
endpublic

public code BlankLine_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_46
	      	mov  	bp,sp
	      	subui	sp,sp,#40
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	bsr  	GetScreenLocation_
	      	mov  	r3,r1
	      	sw   	r3,-8[bp]
	      	lw   	r4,-8[bp]
	      	lcu  	r6,1634[r11]
	      	lw   	r7,24[bp]
	      	mul  	r6,r6,r7
	      	asli 	r5,r6,#2
	      	addu 	r3,r4,r5
	      	sw   	r3,-8[bp]
	      	push 	r3
	      	bsr  	GetCurrAttr_
	      	pop  	r3
	      	mov  	r4,r1
	      	push 	r3
	      	push 	r4
	      	push 	#32
	      	bsr  	AsciiToScreen_
	      	addui	sp,sp,#8
	      	pop  	r4
	      	pop  	r3
	      	mov  	r5,r1
	      	sxc  	r5,r5
	      	or   	r3,r4,r5
	      	sh   	r3,-36[bp]
	      	lcu  	r3,1634[r11]
	      	push 	r3
	      	lh   	r3,-36[bp]
	      	sxh  	r3,r3
	      	push 	r3
	      	push 	-8[bp]
	      	bsr  	memsetH_
	      	addui	sp,sp,#24
console_47:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_46:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_47
endpublic

public code ScrollUp_:
	      	     	         push  lr
         bsr   VBScrollUp
         rts
     
endpublic

public code IncrementCursorRow_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_50
	      	mov  	bp,sp
	      	subui	sp,sp,#8
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lcu  	r3,1636[r11]
	      	addui	r3,r3,#1
	      	sc   	r3,1636[r11]
	      	lcu  	r3,1636[r11]
	      	lcu  	r4,1632[r11]
	      	cmpu 	r5,r3,r4
	      	bge  	r5,console_51
	      	bsr  	UpdateCursorPos_
console_53:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_51:
	      	lcu  	r3,1636[r11]
	      	subui	r3,r3,#1
	      	sc   	r3,1636[r11]
	      	bsr  	UpdateCursorPos_
	      	bsr  	ScrollUp_
	      	bra  	console_53
console_50:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_53
endpublic

public code IncrementCursorPos_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_54
	      	mov  	bp,sp
	      	subui	sp,sp,#8
	      	push 	r11
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lcu  	r3,1638[r11]
	      	addui	r3,r3,#1
	      	sc   	r3,1638[r11]
	      	lcu  	r3,1638[r11]
	      	lcu  	r4,1634[r11]
	      	cmpu 	r5,r3,r4
	      	bge  	r5,console_55
	      	bsr  	UpdateCursorPos_
console_57:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_55:
	      	sc   	r0,1638[r11]
	      	bsr  	IncrementCursorRow_
	      	bra  	console_57
console_54:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_57
endpublic

public code DisplayChar_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_58
	      	mov  	bp,sp
	      	subui	sp,sp,#24
	      	push 	r11
	      	push 	r12
	      	bsr  	GetJCBPtr_
	      	mov  	r3,r1
	      	mov  	r11,r3
	      	lcu  	r3,24[bp]
	      	cmp  	r4,r3,#13
	      	beq  	r4,console_60
	      	cmp  	r4,r3,#10
	      	beq  	r4,console_61
	      	cmp  	r4,r3,#145
	      	beq  	r4,console_62
	      	cmp  	r4,r3,#144
	      	beq  	r4,console_63
	      	cmp  	r4,r3,#147
	      	beq  	r4,console_64
	      	cmp  	r4,r3,#146
	      	beq  	r4,console_65
	      	cmp  	r4,r3,#148
	      	beq  	r4,console_66
	      	cmp  	r4,r3,#153
	      	beq  	r4,console_67
	      	cmp  	r4,r3,#8
	      	beq  	r4,console_68
	      	cmp  	r4,r3,#12
	      	beq  	r4,console_69
	      	cmp  	r4,r3,#9
	      	beq  	r4,console_70
	      	bra  	console_71
console_60:
	      	sc   	r0,1638[r11]
	      	bsr  	UpdateCursorPos_
	      	bra  	console_59
console_61:
	      	bsr  	IncrementCursorRow_
	      	bra  	console_59
console_62:
	      	lcu  	r3,1638[r11]
	      	lcu  	r5,1634[r11]
	      	subu 	r4,r5,#1
	      	cmpu 	r5,r3,r4
	      	bge  	r5,console_72
	      	lcu  	r3,1638[r11]
	      	addui	r3,r3,#1
	      	sc   	r3,1638[r11]
	      	bsr  	UpdateCursorPos_
console_72:
	      	bra  	console_59
console_63:
	      	lcu  	r3,1636[r11]
	      	cmpu 	r4,r3,#0
	      	ble  	r4,console_74
	      	lcu  	r3,1636[r11]
	      	subui	r3,r3,#1
	      	sc   	r3,1636[r11]
	      	bsr  	UpdateCursorPos_
console_74:
	      	bra  	console_59
console_64:
	      	lcu  	r3,1638[r11]
	      	cmpu 	r4,r3,#0
	      	ble  	r4,console_76
	      	lcu  	r3,1638[r11]
	      	subui	r3,r3,#1
	      	sc   	r3,1638[r11]
	      	bsr  	UpdateCursorPos_
console_76:
	      	bra  	console_59
console_65:
	      	lcu  	r3,1636[r11]
	      	lcu  	r5,1632[r11]
	      	subu 	r4,r5,#1
	      	cmpu 	r5,r3,r4
	      	bge  	r5,console_78
	      	lcu  	r3,1636[r11]
	      	addui	r3,r3,#1
	      	sc   	r3,1636[r11]
	      	bsr  	UpdateCursorPos_
console_78:
	      	bra  	console_59
console_66:
	      	lcu  	r3,1638[r11]
	      	bne  	r3,console_80
	      	sc   	r0,1636[r11]
console_80:
	      	sc   	r0,1638[r11]
	      	bsr  	UpdateCursorPos_
	      	bra  	console_59
console_67:
	      	bsr  	CalcScreenLocation_
	      	mov  	r3,r1
	      	mov  	r12,r3
	      	lcu  	r3,1638[r11]
	      	sxc  	r3,r3
	      	sw   	r3,-16[bp]
console_82:
	      	lw   	r3,-16[bp]
	      	lcu  	r5,1634[r11]
	      	subu 	r4,r5,#1
	      	cmp  	r5,r3,r4
	      	bge  	r5,console_83
	      	lw   	r6,-16[bp]
	      	lcu  	r7,1638[r11]
	      	sxc  	r7,r7
	      	subu 	r5,r6,r7
	      	asli 	r4,r5,#2
	      	addu 	r3,r4,r12
	      	lw   	r6,-16[bp]
	      	lcu  	r7,1638[r11]
	      	sxc  	r7,r7
	      	subu 	r5,r6,r7
	      	asli 	r4,r5,#2
	      	lh   	r5,4[r3]
	      	sh   	r5,0[r12+r4]
console_84:
	      	inc  	-16[bp],#1
	      	bra  	console_82
console_83:
	      	push 	r3
	      	bsr  	GetCurrAttr_
	      	pop  	r3
	      	mov  	r4,r1
	      	push 	r3
	      	push 	r4
	      	push 	#32
	      	bsr  	AsciiToScreen_
	      	addui	sp,sp,#8
	      	pop  	r4
	      	pop  	r3
	      	mov  	r5,r1
	      	sxc  	r5,r5
	      	or   	r3,r4,r5
	      	lw   	r6,-16[bp]
	      	lcu  	r7,1638[r11]
	      	sxc  	r7,r7
	      	subu 	r5,r6,r7
	      	asli 	r4,r5,#2
	      	sh   	r3,0[r12+r4]
	      	bra  	console_59
console_68:
	      	lcu  	r3,1638[r11]
	      	cmpu 	r4,r3,#0
	      	ble  	r4,console_85
	      	lcu  	r3,1638[r11]
	      	subui	r3,r3,#1
	      	sc   	r3,1638[r11]
	      	bsr  	CalcScreenLocation_
	      	mov  	r3,r1
	      	mov  	r12,r3
	      	lcu  	r3,1638[r11]
	      	sxc  	r3,r3
	      	sw   	r3,-16[bp]
console_87:
	      	lw   	r3,-16[bp]
	      	lcu  	r5,1634[r11]
	      	subu 	r4,r5,#1
	      	cmp  	r5,r3,r4
	      	bge  	r5,console_88
	      	lw   	r6,-16[bp]
	      	lcu  	r7,1638[r11]
	      	sxc  	r7,r7
	      	subu 	r5,r6,r7
	      	asli 	r4,r5,#2
	      	addu 	r3,r4,r12
	      	lw   	r6,-16[bp]
	      	lcu  	r7,1638[r11]
	      	sxc  	r7,r7
	      	subu 	r5,r6,r7
	      	asli 	r4,r5,#2
	      	lh   	r5,4[r3]
	      	sh   	r5,0[r12+r4]
console_89:
	      	inc  	-16[bp],#1
	      	bra  	console_87
console_88:
	      	push 	r3
	      	bsr  	GetCurrAttr_
	      	pop  	r3
	      	mov  	r4,r1
	      	push 	r3
	      	push 	r4
	      	push 	#32
	      	bsr  	AsciiToScreen_
	      	addui	sp,sp,#8
	      	pop  	r4
	      	pop  	r3
	      	mov  	r5,r1
	      	sxc  	r5,r5
	      	or   	r3,r4,r5
	      	lw   	r6,-16[bp]
	      	lcu  	r7,1638[r11]
	      	sxc  	r7,r7
	      	subu 	r5,r6,r7
	      	asli 	r4,r5,#2
	      	sh   	r3,0[r12+r4]
console_85:
	      	bra  	console_59
console_69:
	      	bsr  	ClearScreen_
	      	bsr  	HomeCursor_
	      	bra  	console_59
console_70:
	      	push 	#32
	      	bsr  	DisplayChar_
	      	addui	sp,sp,#8
	      	push 	#32
	      	bsr  	DisplayChar_
	      	addui	sp,sp,#8
	      	push 	#32
	      	bsr  	DisplayChar_
	      	addui	sp,sp,#8
	      	push 	#32
	      	bsr  	DisplayChar_
	      	addui	sp,sp,#8
	      	bra  	console_59
console_71:
	      	bsr  	CalcScreenLocation_
	      	mov  	r3,r1
	      	mov  	r12,r3
	      	push 	r3
	      	bsr  	GetCurrAttr_
	      	pop  	r3
	      	mov  	r4,r1
	      	push 	r3
	      	push 	r4
	      	lcu  	r5,24[bp]
	      	push 	r5
	      	bsr  	AsciiToScreen_
	      	addui	sp,sp,#8
	      	pop  	r4
	      	pop  	r3
	      	mov  	r5,r1
	      	sxc  	r5,r5
	      	or   	r3,r4,r5
	      	sh   	r3,[r12]
	      	bsr  	IncrementCursorPos_
	      	bra  	console_59
console_59:
console_90:
	      	pop  	r12
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_58:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_90
endpublic

public code CRLF_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_91
	      	mov  	bp,sp
	      	push 	#13
	      	bsr  	DisplayChar_
	      	addui	sp,sp,#8
	      	push 	#10
	      	bsr  	DisplayChar_
	      	addui	sp,sp,#8
console_92:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_91:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_92
endpublic

public code DisplayString_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_93
	      	mov  	bp,sp
	      	push 	r11
	      	lw   	r11,24[bp]
console_94:
	      	lcu  	r3,[r11]
	      	beq  	r3,console_95
	      	lcu  	r3,[r11]
	      	push 	r3
	      	bsr  	DisplayChar_
	      	addui	sp,sp,#8
	      	addui	r11,r11,#2
	      	bra  	console_94
console_95:
console_96:
	      	pop  	r11
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_93:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_96
endpublic

public code DisplayStringCRLF_:
	      	push 	lr
	      	push 	xlr
	      	push 	bp
	      	ldi  	xlr,#console_97
	      	mov  	bp,sp
	      	push 	24[bp]
	      	bsr  	DisplayString_
	      	addui	sp,sp,#8
	      	bsr  	CRLF_
console_98:
	      	mov  	sp,bp
	      	pop  	bp
	      	pop  	xlr
	      	pop  	lr
	      	rtl  	#0
console_97:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	console_98
endpublic

	rodata
	align	16
	align	8
;	global	GetScreenLocation_
;	global	outb_
;	global	outc_
;	global	outh_
	extern	IOFocusNdx_
	extern	DumpTaskList_
;	global	SetCursorCol_
;	global	outw_
;	global	GetCursorPos_
	extern	memsetH_
	extern	GetRunningTCB_
;	global	SetCursorPos_
	extern	memsetW_
;	global	SetRunningTCB_
;	global	HomeCursor_
;	global	AsciiToScreen_
;	global	ScreenToAscii_
;	global	CalcScreenLocation_
;	global	chkTCB_
	extern	GetRunningTCBPtr_
;	global	UnlockSemaphore_
;	global	UpdateCursorPos_
	extern	GetVecno_
	extern	GetJCBPtr_
;	global	CRLF_
	extern	getCPU_
;	global	LockSemaphore_
;	global	ScrollUp_
;	global	set_vector_
;	global	SetVideoReg_
;	global	ClearScreen_
;	global	DisplayString_
;	global	DisplayChar_
;	global	IncrementCursorPos_
;	global	GetTextCols_
;	global	GetCurrAttr_
;	global	IncrementCursorRow_
;	global	SetCurrAttr_
;	global	ClearBmpScreen_
;	global	GetTextRows_
;	global	BlankLine_
;	global	DisplayStringCRLF_
;	global	RemoveFromTimeoutList_
;	global	SetBound50_
;	global	SetBound51_
;	global	SetBound48_
;	global	SetBound49_
;	global	InsertIntoTimeoutList_
;	global	RemoveFromReadyList_
;	global	InsertIntoReadyList_
