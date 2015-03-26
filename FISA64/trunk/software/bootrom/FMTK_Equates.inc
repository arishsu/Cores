; error codes
E_Ok		=		0x00
E_Arg		=		0x01
E_BadMbx	=		0x04
E_QueFull	=		0x05
E_NoThread	=		0x06
E_NotAlloc	=		0x09
E_NoMsg		=		0x0b
E_Timeout	=		0x10
E_BadAlarm	=		0x11
E_NotOwner	=		0x12
E_QueStrategy =		0x13
E_BadDevNum	=		0x18
E_DCBInUse	=		0x19
; Device driver errors
E_BadDevNum	=		0x20
E_NoDev		=		0x21
E_BadDevOp	=		0x22
E_ReadError	=		0x23
E_WriteError =		0x24
E_BadBlockNum	=	0x25
E_TooManyBlocks	=	0x26

; resource errors
E_NoMoreMbx	=		0x40
E_NoMoreMsgBlks	=	0x41
E_NoMoreAlarmBlks	=0x44
E_NoMoreTCBs	=	0x45
E_NoMem		= 12

; task status
TS_NONE     =0
TS_TIMEOUT	=1
TS_WAITMSG	=2
TS_PREEMPT	=4
TS_RUNNING	=8
TS_READY	=16
TS_SLEEP	=32

TS_TIMEOUT_BIT	=0
TS_WAITMSG_BIT	=1
TS_RUNNING_BIT	=3
TS_READY_BIT	=4

PRI_HIGHEST	=0
PRI_HIGH	=1
PRI_NORMAL	=3
PRI_LOW		=5
PRI_LOWEST	=7


NR_TCB		EQU		256
TCB_BackLink    EQU     0
TCB_r1          EQU     8
TCB_r2          EQU     $10
TCB_r3          EQU     $18
TCB_r4          EQU     $20
TCB_r5          EQU     $28
TCB_r6          EQU     $30
TCB_r7          EQU     $38
TCB_r8          EQU     $40
TCB_r9          EQU     $48
TCB_r10         EQU     $50
TCB_r11         EQU     $58
TCB_r12         EQU     $60
TCB_r13         EQU     $68
TCB_r14         EQU     $70
TCB_r15         EQU     $78
TCB_r16         EQU     $80
TCB_r17         EQU     $88
TCB_r18         EQU     $90
TCB_r19         EQU     $98
TCB_r20         EQU     $A0
TCB_r21         EQU     $A8
TCB_r22         EQU     $B0
TCB_r23         EQU     $B8
TCB_r24         EQU     $C0
TCB_r25         EQU     $C8
TCB_r26         EQU     $D0
TCB_r27         EQU     $D8
TCB_r28         EQU     $E0
TCB_r29         EQU     $E8
TCB_r30         EQU     $F0
TCB_r31         EQU     $F8

TCB_SP0Save		EQU		0x100
TCB_SP1Save		EQU		0x108
TCB_SP2Save		EQU		0x110
TCB_SP3Save		EQU		0x118
TCB_SP4Save		EQU		0x120
TCB_SP5Save		EQU		0x128
TCB_SP6Save		EQU		0x130
TCB_SP7Save		EQU		0x138
TCB_SP8Save		EQU		0x140
TCB_SP9Save		EQU		0x148
TCB_SP10Save	EQU		0x150
TCB_SP11Save	EQU		0x158
TCB_SP12Save	EQU		0x160
TCB_SP13Save	EQU		0x168
TCB_SP14Save	EQU		0x170
TCB_SP15Save	EQU		0x178

TCB_IPC         EQU     0x180
TCB_DPC         EQU     0x188
TCB_EPC         EQU     0x190

TCB_NextRdy     EQU     $200
TCB_PrevRdy     EQU     $208
TCB_Status      EQU     $210
TCB_Priority    EQU     $212
TCB_hJCB        EQU     $214
TCB_NextFree    EQU     $218
TCB_PrevFree    EQU     $220
TCB_NextTo      EQU     $228
TCB_PrevTo      EQU     $230
TCB_mbq_next    EQU     $238
TCB_mbq_prev    EQU     $240
TCB_MsgD1       EQU     $248
TCB_MsgD2       EQU     $250
TCB_hWaitMbx    EQU     $258
TCB_MbxList     EQU     $260
TCB_StackTop    EQU     $268
TCB_errno       EQU     $270
TCB_Size	    EQU	    $300

; Mailboxes, room for 2048
;			.bss
;			.org		0x07E40000
NR_MBX		EQU		2048
MBX_LINK		EQU     $00       ; link to next mailbox in list (free list)
MBX_TQ_HEAD		EQU     $08       ; head of task queue
MBX_TQ_TAIL		EQU     $18
MBX_MQ_HEAD		EQU     $20	      ; head of message queue
MBX_MQ_TAIL		EQU     $28
MBX_TQ_COUNT	EQU     $30	      ; count of queued threads
MBX_MQ_SIZE		EQU     $38       ; number of messages that may be queued
MBX_MQ_COUNT	EQU     $40       ; count of messages that are queued
MBX_MQ_MISSED	EQU     $48	      ; number of messages dropped from queue
MBX_OWNER		EQU     $50	      ; job handle of mailbox owner
MBX_MQ_STRATEGY	EQU     $58	      ; message queueing strategy
MBX_Size        EQU     $60

; Messages, room for 64kW (16,384) messages
;			.bss
;			.org		0x07E80000
NR_MSG		EQU		32768
MSG_LINK	EQU     $00	        ; link to next message in queue or free list
MSG_D1		EQU     $08         ; message data 1
MSG_D2		EQU     $10	        ; message data 2
MSG_TYPE	EQU     $18	        ; message type
MSG_SIZE    EQU     $20

MT_SEMA		EQU		-1
MT_IRQ		EQU		-16
MT_GETCHAR	EQU		-17


NR_JCB			EQU		51
JCB_Number		EQU		0
JCB_Name		EQU		4		; 32 bytes (1 len + 31)
JCB_MemGroup0	EQU		0x24	; memory map number associated with job
JCB_MemGroup1   EQU     0x26
JCB_MemGroup2   EQU     0x28
JCB_MemGroup3   EQU     0x2A
JCB_MemGroup4   EQU     0x2C
JCB_MemGroup5   EQU     0x2E
JCB_pCode		EQU		0x30
JCB_nCode		EQU		0x38	; size of code
JCB_pData		EQU		0x40
JCB_nData		EQU		0x48	; size of data
JCB_pStack		EQU		0x50
JCB_nStack		EQU		0x58
JCB_UserName	EQU		0x60	; 32 bytes
JCB_Path		EQU		0x80	; 256 bytes
JCB_ExitRF		EQU		0x180	; 256 bytes
JCB_CmdLine		EQU		0x280	; 256 bytes		
JCB_SysIn		EQU		0x380	; 48 chars
JCB_SysOut		EQU		0x3B0	; 48 chars
JCB_ExitError	EQU		0x3E0
JCB_pVidMem		EQU		0x3E8		; pointer to video memory
JCB_pVidMemAttr	EQU		0x3F0
JCB_pVirtVid	EQU		0x3F8		; pointer to virtual video buffer
JCB_pVirtVidAttr	EQU		0x400
JCB_VideoMode	EQU		0x408
JCB_VideoRows	EQU		0x40A
JCB_VideoCols	EQU		0x40B
JCB_CursorRow	EQU		0x40C
JCB_CursorCol	EQU		0x40D
JCB_CursorOn	EQU		0x40E
JCB_CursorFlash	EQU		0x40F
JCB_CursorType	EQU		0x410
JCB_NormAttr	EQU		0x414
JCB_CurrAttr	EQU		0x418
JCB_ScrlCnt		EQU		0x41C
JCB_fVidPause	EQU		0x41E
JCB_Next		EQU		0x420
JCB_iof_next	EQU		0x428		; I/O focus list
JCB_iof_prev	EQU		0x430
JCB_KeybdHead	EQU		0x438
JCB_KeybdTail	EQU		0x440
JCB_KeybdEcho	EQU		0x448
JCB_KeybdBad	EQU		0x449
JCB_KeybdAck	EQU		0x44A
JCB_KeybdLocks	EQU		0x44C
JCB_KeybdBuffer	EQU		0x450		; buffer is 16 words (chars = words)
JCB_esc			EQU		0x470		; escape flag for DisplayChar processing
JCB_Size		EQU		0x500
JCB_LogSize		EQU		10

BITMAP_SCREEN1  EQU     $400000     ; bitmap graphics screen area (4MB)
BITMAP_SCREEN2  EQU     $800000     ; bitmap graphics screen area (4MB)
VAR_Area        EQU     $C00000     ; 64k block for OS vars
TCB_Array       EQU     $C10000     ; room for 256 TCB's (192kB)
TCB_ArrayEnd    EQU     $C40000
JCB_Array       EQU     $C40000
JCB_ArrayEnd    EQU     $C50000     ; room for 51 JCB's  (64kB)
MBX_Array       EQU     $C60000     ; room for 2048 mailboxes (192kB)
MBX_ArrayEnd    EQU     $C90000
MSG_Array       EQU     $C90000     ; room for 32,768 messages (1MB)
MSG_ArrayEnd    EQU     $D90000
SCREEN_Array    EQU     $D90000     ; room for 51 16kB screens
SCREEN_ArrayEnd EQU     $E90000
STACKS_Array    EQU    $7F00000     ; room for 256 TCB stacks of 4kB each
STACKS_ArrayEnd EQU    $8000000
MEM_END         EQU    $8000000

    .bss
    org         VAR_Area
UserTick    dw      0
IOFocusTbl      fill.w   4,0        ; tasks requesting I/O focus
QNdx0		dw		0
QNdx1		dw		0
QNdx2		dw		0
QNdx3		dw		0
QNdx4		dw		0
QNdx5		dw		0
QNdx6		dw		0
QNdx7		dw		0
FreeTCB		dw		0
TimeoutList	dw		0
RunningTCB	dw		0
FreeMbxHandle		dw		0
nMailbox	dw		0
FreeMsg		dw		0
nMsgBlk		dw		0
missed_ticks	dw		0
keybdmsg_d1		dw		0
keybdmsg_d2		dw		0
keybd_mbx		dw		0
keybd_char		dw		0
keybdIsSetup	dw		0
keybdLock		dw		0
keybdInIRQ		dw		0
iof_switch		dw		0
clockmsg_d1		dw		0
clockmsg_d2		dw		0
tcbsema_d1		dw		0
tcbsema_d2		dw		0
mmu_acc_save	dw		0

freetcb_sema   dw   0
freembx_sema   dw   0
freemsg_sema   dw   0
tcb_sema       dw   0
readylist_sema dw   0
tolist_sema    dw   0
mbx_sema       dw   0
msg_sema       dw   0
jcb_sema       dw   0

