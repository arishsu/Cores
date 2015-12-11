//
//	COPYRIGHT 2000 by Bruce L. Jacob
//	(contact info: http://www.ece.umd.edu/~blj/)
//
//	You are welcome to use, modify, copy, and/or redistribute this implementation, provided:
//	  1. you share with the author (Bruce Jacob) any changes you make;
//	  2. you properly credit the author (Bruce Jacob) if used within a larger work; and
//	  3. you do not modify, delete, or in any way obscure the implementation's copyright 
//	     notice or following comments (i.e. the first 3-4 dozen lines of this file).
//
//	RiSC-16
//
//	This is an out-of-order implementation of the RiSC-16, a teaching instruction-set used by
//	the author at the University of Maryland, and which is a blatant (but sanctioned) rip-off
//	of the Little Computer (LC-896) developed by Peter Chen at the University of Michigan.
//	The primary differences include the following:
//	  1. a move from 17-bit to 16-bit instructions; and
//	  2. the replacement of the NOP and HALT opcodes by ADDI and LUI ... HALT and NOP are
//	     now simply special instances of other instructions: NOP is a do-nothing ADD, and
//	     HALT is a subset of JALR.
//
//	RiSC stands for Ridiculously Simple Computer, which makes sense in the context in which
//	the instruction-set is normally used -- to teach simple organization and architecture to
//	undergraduates who do not yet know how computers work.  This implementation was targetted
//	towards more advanced undergraduates doing design & implementation and was intended to 
//	demonstrate some high-performance concepts on a small scale -- an 8-entry reorder buffer,
//	eight opcodes, two ALUs, two-way issue, two-way commit, etc.  However, the out-of-order 
//	core is much more complex than I anticipated, and I hope that its complexity does not 
//	obscure its underlying structure.  We'll see how well it flies in class ...
//
//	CAVEAT FREELOADER: This Verilog implementation was developed and debugged in a (somewhat
//	frantic) 2-week period before the start of the Fall 2000 semester.  Not surprisingly, it
//	still contains many bugs and some horrible, horrible logic.  The logic is also written so
//	as to be debuggable and/or explain its function, rather than to be efficient -- e.g. in
//	several places, signals are over-constrained so that they are easy to read in the debug
//	output ... also, you will see statements like
//
//	    if (xyz[`INSTRUCTION_OP] == `BEQ || xyz[`INSTRUCTION_OP] == `SW)
//
//	instead of and/nand combinations of bits ... sorry; can't be helped.  Use at your own risk.
//
//	DOCUMENTATION: Documents describing the RiSC-16 in all its forms (sequential, pipelined,
//	as well as out-of-order) can be found on the author's website at the following URL:
//
//	    http://www.ece.umd.edu/~blj/RiSC/
//
//	If you do not find what you are looking for, please feel free to email me with suggestions
//	for more/different/modified documents.  Same goes for bug fixes.
//
//
//	KNOWN PROBLEMS (i.e., bugs I haven't got around to fixing yet)
//
//	- If the target of a backwards branch is a backwards branch, the fetchbuf steering logic
//	  will get confused.  This can be fixed by having a separate did_branchback status register
//	  for each of the fetch buffers.
//
// ============================================================================
//        __
//   \\__/ o\    (C) 2013,2015  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
//
// Thor Superscaler
//
// This work is starting with the RiSC-16 as noted in the copyright statement
// above. Hopefully it will be possible to run this processor in real hardware
// (FPGA) as opposed to just simulation. To the RiSC-16 are added:
//
//	64/32 bit datapath rather than 16 bit
//   64 general purpose registers
//   16 code address registers
//   16 predicate registers / predicated instruction execution
//    8 segment registers
//      A branch history table, and a (2,2) correlating branch predictor added
//      variable length instruction encodings (code density)
//      support for interrupts
//      The instruction set is changed completely with many new instructions.
//      An instruction and data cache were added.
//      A WISHBONE bus interface was added,
//
// 48226 (78,000 LC's)
// (42360 - no FP)
// ============================================================================
//
`include "Thor_defines.v"

module Thor(rst_i, clk_i, clk_o, km, nmi_i, irq_i, vec_i, bte_o, cti_o, bl_o, lock_o, resv_o, resv_i, cres_o,
    cyc_o, stb_o, ack_i, err_i, we_o, sel_o, adr_o, dat_i, dat_o);
parameter DBW = 32;         // databus width
parameter ABW = 32;         // address bus width
parameter QENTRIES = 8;
parameter ALU1BIG = 0;
parameter RESET1 = 4'd0;
parameter RESET2 = 4'd1;
parameter IDLE = 4'd2;
parameter ICACHE1 = 4'd3;
parameter DCACHE1 = 4'd4;
parameter IBUF1 = 4'd5;
parameter IBUF2 = 4'd6;
parameter IBUF3 = 4'd7;
parameter IBUF4 = 4'd8;
parameter IBUF5 = 4'd9;
parameter NREGS = 127;
parameter PF = 4'd0;
parameter PT = 4'd1;
parameter PEQ = 4'd2;
parameter PNE = 4'd3;
parameter PLE = 4'd4;
parameter PGT = 4'd5;
parameter PGE = 4'd6;
parameter PLT = 4'd7;
parameter PLEU = 4'd8;
parameter PGTU = 4'd9;
parameter PGEU = 4'd10;
parameter PLTU = 4'd11;
input rst_i;
input clk_i;
output clk_o;
output km;
input nmi_i;
input irq_i;
input [7:0] vec_i;
output reg [1:0] bte_o;
output reg [2:0] cti_o;
output reg [4:0] bl_o;
output reg lock_o;
output reg resv_o;
input resv_i;
output reg cres_o;
output reg cyc_o;
output reg stb_o;
input ack_i;
input err_i;
output reg we_o;
output reg [DBW/8-1:0] sel_o;
output reg [ABW-1:0] adr_o;
input [DBW-1:0] dat_i;
output reg [DBW-1:0] dat_o;

integer n,i;
reg [DBW/8-1:0] rsel;
reg [3:0] cstate;
reg [DBW-1:0] pc;				// program counter (virtual)
wire [DBW-1:0] ppc;				// physical pc address
reg [DBW-1:0] vadr;				// data virtual address
reg [3:0] panic;		// indexes the message structure
reg [128:0] message [0:15];	// indexed by panic
reg [DBW-1:0] cregs [0:15];		// code address registers
reg [ 3:0] pregs [0:15];		// predicate registers
`ifdef SEGMENTATION
reg [DBW-1:12] sregs [0:7];		// segment registers
`endif
reg [2:0] rrmapno;				// register rename map number
wire ITLBMiss;
wire DTLBMiss;
wire uncached;
wire [DBW-1:0] cdat;
reg pwe;
wire [DBW-1:0] pea;
reg [DBW-1:0] tick;
reg [DBW-1:0] lc;				// loop counter
reg [DBW-1:0] rfoa0,rfoa1;
reg [DBW-1:0] rfob0,rfob1;
reg [DBW-1:0] rfoc0,rfoc1;
reg ic_invalidate,dc_invalidate;
reg ic_invalidate_line,dc_invalidate_line;
reg [ABW-1:0] ic_lineno,dc_lineno;
reg ierr,derr;					// err_i during icache load
wire insnerr;					// err_i during icache load
wire [127:0] insn;
reg [DBW-1:0] ibufadr;
reg [127:0] ibuf;
wire ibufhit = ibufadr==pc;
wire iuncached;
reg [NREGS:0] rf_v;
//reg [15:0] pf_v;
reg im,imb;
reg fxe;
reg nmi1,nmi_edge;
reg StatusHWI;
reg [7:0] StatusEXL;
assign km = StatusHWI | |StatusEXL;
reg [7:0] GM;		// register group mask
reg [7:0] GMB;
wire [63:0] sr = {32'd0,imb,7'b0,GMB,im,1'b0,km,fxe,4'b0,GM};
wire int_commit;
wire int_pending;
wire sys_commit;
`ifdef SEGMENTATION
wire [DBW-1:0] spc = (pc[DBW-1:DBW-4]==4'hF) ? pc : {sregs[7],12'h000} + pc;
`else
wire [DBW-1:0] spc = pc;
`endif
wire [DBW-1:0] ppcp16 = ppc + 64'd16;
reg [DBW-1:0] string_pc;
reg stmv_flag;
reg [7:0] asid;

wire clk;

// Operand registers
wire take_branch;
wire take_branch0;
wire take_branch1;

reg [3:0] rf_source [0:NREGS];
//reg [3:0] pf_source [15:0];

// instruction queue (ROB)
reg iq_cmt[0:7];
reg [7:0]  iqentry_v;			// entry valid?  -- this should be the first bit
reg        iqentry_out	[0:7];	// instruction has been issued to an ALU ... 
reg        iqentry_done	[0:7];	// instruction result valid
reg [7:0]  iqentry_cmt;  		// commit result to machine state
reg        iqentry_bt  	[0:7];	// branch-taken (used only for branches)
reg        iqentry_agen [0:7];  // memory address is generated
reg        iqentry_mem	[0:7];	// touches memory: 1 if LW/SW
reg        iqentry_jmp	[0:7];	// changes control flow: 1 if BEQ/JALR
reg        iqentry_fp   [0:7];  // is an floating point operation
reg        iqentry_rfw	[0:7];	// writes to register file
reg [DBW-1:0] iqentry_res	[0:7];	// instruction result
reg  [3:0] iqentry_insnsz [0:7];	// the size of the instruction
reg  [3:0] iqentry_cond [0:7];	// predicating condition
reg  [3:0] iqentry_pred [0:7];	// predicate value
reg        iqentry_p_v  [0:7];	// predicate is valid
reg  [3:0] iqentry_p_s  [0:7];	// predicate source
reg  [7:0] iqentry_op	[0:7];	// instruction opcode
reg  [5:0] iqentry_fn   [0:7];  // instruction function
reg  [2:0] iqentry_renmapno [0:7];	// register rename map number
reg  [6:0] iqentry_tgt	[0:7];	// Rt field or ZERO -- this is the instruction's target (if any)
reg [DBW-1:0] iqentry_a0	[0:7];	// argument 0 (immediate)
reg [DBW-1:0] iqentry_a1	[0:7];	// argument 1
reg        iqentry_a1_v	[0:7];	// arg1 valid
reg  [3:0] iqentry_a1_s	[0:7];	// arg1 source (iq entry # with top bit representing ALU/DRAM bus)
reg [DBW-1:0] iqentry_a2	[0:7];	// argument 2
reg        iqentry_a2_v	[0:7];	// arg2 valid
reg  [3:0] iqentry_a2_s	[0:7];	// arg2 source (iq entry # with top bit representing ALU/DRAM bus)
reg [DBW-1:0] iqentry_a3	[0:7];	// argument 3
reg        iqentry_a3_v	[0:7];	// arg3 valid
reg  [3:0] iqentry_a3_s	[0:7];	// arg3 source (iq entry # with top bit representing ALU/DRAM bus)
reg [DBW-1:0] iqentry_pc	[0:7];	// program counter for this instruction

wire  iqentry_source [0:7];
wire  iqentry_imm [0:7];
wire  iqentry_memready [0:7];
wire  iqentry_memopsvalid [0:7];
reg qstomp;

wire stomp_all;
reg  [7:0] iqentry_fpissue;
reg  [7:0] iqentry_memissue;
wire iqentry_memissue_head0;
wire iqentry_memissue_head1;
wire iqentry_memissue_head2;
wire iqentry_memissue_head3;
wire iqentry_memissue_head4;
wire iqentry_memissue_head5;
wire iqentry_memissue_head6;
wire iqentry_memissue_head7;
wire  [7:0] iqentry_stomp;
reg  [7:0] iqentry_issue;
wire  [1:0] iqentry_0_islot;
wire  [1:0] iqentry_1_islot;
wire  [1:0] iqentry_2_islot;
wire  [1:0] iqentry_3_islot;
wire  [1:0] iqentry_4_islot;
wire  [1:0] iqentry_5_islot;
wire  [1:0] iqentry_6_islot;
wire  [1:0] iqentry_7_islot;
reg  [1:0] iqentry_islot[0:7];
reg [1:0] iqentry_fpislot[0:7];

reg queued1,queued2;
reg queued3;    // for three-way config

wire  [NREGS:1] livetarget;
wire  [NREGS:1] iqentry_0_livetarget;
wire  [NREGS:1] iqentry_1_livetarget;
wire  [NREGS:1] iqentry_2_livetarget;
wire  [NREGS:1] iqentry_3_livetarget;
wire  [NREGS:1] iqentry_4_livetarget;
wire  [NREGS:1] iqentry_5_livetarget;
wire  [NREGS:1] iqentry_6_livetarget;
wire  [NREGS:1] iqentry_7_livetarget;
wire  [NREGS:1] iqentry_0_latestID;
wire  [NREGS:1] iqentry_1_latestID;
wire  [NREGS:1] iqentry_2_latestID;
wire  [NREGS:1] iqentry_3_latestID;
wire  [NREGS:1] iqentry_4_latestID;
wire  [NREGS:1] iqentry_5_latestID;
wire  [NREGS:1] iqentry_6_latestID;
wire  [NREGS:1] iqentry_7_latestID;
wire  [NREGS:1] iqentry_0_cumulative;
wire  [NREGS:1] iqentry_1_cumulative;
wire  [NREGS:1] iqentry_2_cumulative;
wire  [NREGS:1] iqentry_3_cumulative;
wire  [NREGS:1] iqentry_4_cumulative;
wire  [NREGS:1] iqentry_5_cumulative;
wire  [NREGS:1] iqentry_6_cumulative;
wire  [NREGS:1] iqentry_7_cumulative;


reg  [2:0] tail0;
reg  [2:0] tail1;
reg  [2:0] tail2;   // used only for three-way config
reg  [2:0] head0;
reg  [2:0] head1;
reg  [2:0] head2;	// used only to determine memory-access ordering
reg  [2:0] head3;	// used only to determine memory-access ordering
reg  [2:0] head4;	// used only to determine memory-access ordering
reg  [2:0] head5;	// used only to determine memory-access ordering
reg  [2:0] head6;	// used only to determine memory-access ordering
reg  [2:0] head7;	// used only to determine memory-access ordering
reg  [2:0] headinc;

wire  [2:0] missid;
reg   fetchbuf;		// determines which pair to read from & write to

reg  [63:0] fetchbuf0_instr;
reg  [DBW-1:0] fetchbuf0_pc;
reg         fetchbuf0_v;
wire        fetchbuf0_mem;
wire        fetchbuf0_jmp;
wire 		fetchbuf0_fp;
wire        fetchbuf0_rfw;
wire        fetchbuf0_pfw;
reg  [63:0] fetchbuf1_instr;
reg  [DBW-1:0] fetchbuf1_pc;
reg        fetchbuf1_v;
wire        fetchbuf1_mem;
wire        fetchbuf1_jmp;
wire 		fetchbuf1_fp;
wire        fetchbuf1_rfw;
wire        fetchbuf1_pfw;
wire        fetchbuf1_bfw;
reg  [63:0] fetchbuf2_instr;
reg  [DBW-1:0] fetchbuf2_pc;
reg        fetchbuf2_v;
wire        fetchbuf2_mem;
wire        fetchbuf2_jmp;
wire 		fetchbuf2_fp;
wire        fetchbuf2_rfw;
wire        fetchbuf2_pfw;
wire        fetchbuf2_bfw;

reg [63:0] fetchbufA_instr;	
reg [DBW-1:0] fetchbufA_pc;
reg        fetchbufA_v;
reg [63:0] fetchbufB_instr;
reg [DBW-1:0] fetchbufB_pc;
reg        fetchbufB_v;
reg [63:0] fetchbufC_instr;
reg [DBW-1:0] fetchbufC_pc;
reg        fetchbufC_v;
reg [63:0] fetchbufD_instr;
reg [DBW-1:0] fetchbufD_pc;
reg        fetchbufD_v;

reg        did_branchback;
reg 		did_branchback0;
reg			did_branchback1;

reg        alu0_ld;
reg        alu0_available;
reg        alu0_dataready;
reg  [3:0] alu0_sourceid;
reg  [3:0] alu0_insnsz;
reg  [7:0] alu0_op;
reg  [5:0] alu0_fn;
reg  [3:0] alu0_cond;
reg        alu0_bt;
reg        alu0_cmt;
reg [DBW-1:0] alu0_argA;
reg [DBW-1:0] alu0_argB;
reg [DBW-1:0] alu0_argC;
reg [DBW-1:0] alu0_argI;
reg  [3:0] alu0_pred;
reg [DBW-1:0] alu0_pc;
reg [DBW-1:0] alu0_bus;
reg  [3:0] alu0_id;
wire  [3:0] alu0_exc;
reg        alu0_v;
wire        alu0_branchmiss;
reg [DBW-1:0] alu0_misspc;

reg        alu1_ld;
reg        alu1_available;
reg        alu1_dataready;
reg  [3:0] alu1_sourceid;
reg  [3:0] alu1_insnsz;
reg  [7:0] alu1_op;
reg  [5:0] alu1_fn;
reg  [3:0] alu1_cond;
reg        alu1_bt;
reg        alu1_cmt;
reg [DBW-1:0] alu1_argA;
reg [DBW-1:0] alu1_argB;
reg [DBW-1:0] alu1_argC;
reg [DBW-1:0] alu1_argI;
reg  [3:0] alu1_pred;
reg [DBW-1:0] alu1_pc;
reg [DBW-1:0] alu1_bus;
reg  [3:0] alu1_id;
wire  [3:0] alu1_exc;
reg        alu1_v;
wire        alu1_branchmiss;
reg [DBW-1:0] alu1_misspc;

wire mem_stringmiss;
wire        branchmiss;
wire [DBW-1:0] misspc;

`ifdef FLOATING_POINT
reg        fp0_ld;
reg        fp0_available;
reg        fp0_dataready;
reg  [3:0] fp0_sourceid;
reg  [7:0] fp0_op;
reg  [5:0] fp0_fn;
reg  [3:0] fp0_cond;
wire        fp0_cmt;
reg 		fp0_done;
reg [DBW-1:0] fp0_argA;
reg [DBW-1:0] fp0_argB;
reg [DBW-1:0] fp0_argC;
reg [DBW-1:0] fp0_argI;
reg  [3:0] fp0_pred;
reg [DBW-1:0] fp0_pc;
wire [DBW-1:0] fp0_bus;
wire  [3:0] fp0_id;
wire  [7:0] fp0_exc;
wire        fp0_v;
`endif

wire        dram_avail;
reg	 [2:0] dram0;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	 [2:0] dram1;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	 [2:0] dram2;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg  [2:0] tlb_state;
reg [3:0] tlb_id;
reg [3:0] tlb_op;
reg [3:0] tlb_regno;
reg [8:0] tlb_tgt;
reg [DBW-1:0] tlb_data;

wire [DBW-1:0] tlb_dato;
reg dram0_owns_bus;
reg [DBW-1:0] dram0_data;
reg [DBW-1:0] dram0_datacmp;
reg [DBW-1:0] dram0_addr;
reg  [7:0] dram0_op;
reg  [5:0] dram0_fn;
reg  [8:0] dram0_tgt;
reg  [3:0] dram0_id;
reg  [3:0] dram0_exc;
reg dram1_owns_bus;
reg [DBW-1:0] dram1_data;
reg [DBW-1:0] dram1_datacmp;
reg [DBW-1:0] dram1_addr;
reg  [7:0] dram1_op;
reg  [5:0] dram1_fn;
reg  [6:0] dram1_tgt;
reg  [3:0] dram1_id;
reg  [3:0] dram1_exc;
reg [DBW-1:0] dram2_data;
reg [DBW-1:0] dram2_datacmp;
reg [DBW-1:0] dram2_addr;
reg  [7:0] dram2_op;
reg  [5:0] dram2_fn;
reg  [6:0] dram2_tgt;
reg  [3:0] dram2_id;
reg  [3:0] dram2_exc;

reg [DBW-1:0] dram_bus;
reg  [6:0] dram_tgt;
reg  [3:0] dram_id;
reg  [3:0] dram_exc;
reg        dram_v;

reg [DBW-1:0] index;
reg [DBW-1:0] src_addr,dst_addr;
wire mem_issue;

wire        outstanding_stores;
reg [DBW-1:0] I;	// instruction count

wire        commit0_v;
wire  [3:0] commit0_id;
wire  [6:0] commit0_tgt;
wire [DBW-1:0] commit0_bus;
wire        commit1_v;
wire  [3:0] commit1_id;
wire  [6:0] commit1_tgt;
wire [DBW-1:0] commit1_bus;
wire limit_cmt;
wire committing2;
reg cmt_miss;
reg [2:0] cmt_miss_id;
 
wire [63:0] alu0_divq;
wire [63:0] alu0_rem;
wire alu0_div_done;

wire [63:0] alu1_divq;
wire [63:0] alu1_rem;
wire alu1_div_done;

wire [127:0] alu0_prod;
wire alu0_mult_done;
wire [127:0] alu1_prod;
wire alu1_mult_done;

//
// BRANCH-MISS LOGIC: livetarget
//
// livetarget implies that there is a not-to-be-stomped instruction that targets the register in question
// therefore, if it is zero it implies the rf_v value should become VALID on a branchmiss
// 

Thor_livetarget #(NREGS) ultgt1 
(
	iqentry_v,
	iqentry_stomp,
	iqentry_cmt,
	iqentry_tgt[0],
	iqentry_tgt[1],
	iqentry_tgt[2],
	iqentry_tgt[3],
	iqentry_tgt[4],
	iqentry_tgt[5],
	iqentry_tgt[6],
	iqentry_tgt[7],
	livetarget,
	iqentry_0_livetarget,
	iqentry_1_livetarget,
	iqentry_2_livetarget,
	iqentry_3_livetarget,
	iqentry_4_livetarget,
	iqentry_5_livetarget,
	iqentry_6_livetarget,
	iqentry_7_livetarget
);

//
// BRANCH-MISS LOGIC: latestID
//
// latestID is the instruction queue ID of the newest instruction (latest) that targets
// a particular register.  looks a lot like scheduling logic, but in reverse.
// 

assign iqentry_0_latestID = ((branchmiss ? missid == 3'd0 : cmt_miss_id==3'd0 )|| ((iqentry_0_livetarget & iqentry_1_cumulative) == {NREGS{1'b0}}))
				? iqentry_0_livetarget
				: {NREGS{1'b0}};
assign iqentry_0_cumulative = (branchmiss ? missid == 3'd0 : cmt_miss_id==3'd0)
				? iqentry_0_livetarget
				: iqentry_0_livetarget | iqentry_1_cumulative;

assign iqentry_1_latestID = ((branchmiss ? missid == 3'd1 : cmt_miss_id==3'd1 )|| ((iqentry_1_livetarget & iqentry_2_cumulative) == {NREGS{1'b0}}))
				? iqentry_1_livetarget
				: {NREGS{1'b0}};
assign iqentry_1_cumulative = (branchmiss ? missid == 3'd1 : cmt_miss_id==3'd1)
				? iqentry_1_livetarget
				: iqentry_1_livetarget | iqentry_2_cumulative;

assign iqentry_2_latestID = ((branchmiss ? missid == 3'd2 : cmt_miss_id==3'd2) || ((iqentry_2_livetarget & iqentry_3_cumulative) == {NREGS{1'b0}}))
				? iqentry_2_livetarget
				: {NREGS{1'b0}};
assign iqentry_2_cumulative = (branchmiss ? missid == 3'd2 : cmt_miss_id==3'd2)
				? iqentry_2_livetarget
				: iqentry_2_livetarget | iqentry_3_cumulative;

assign iqentry_3_latestID = ((branchmiss ? missid == 3'd3: cmt_miss_id==3'd3 )|| ((iqentry_3_livetarget & iqentry_4_cumulative) == {NREGS{1'b0}}))
				? iqentry_3_livetarget
				: {NREGS{1'b0}};
assign iqentry_3_cumulative = (branchmiss ? missid == 3'd3 : cmt_miss_id==3'd3)
				? iqentry_3_livetarget
				: iqentry_3_livetarget | iqentry_4_cumulative;

assign iqentry_4_latestID = ((branchmiss ? missid == 3'd4 : cmt_miss_id==3'd4) || ((iqentry_4_livetarget & iqentry_5_cumulative) == {NREGS{1'b0}}))
				? iqentry_4_livetarget
				: {NREGS{1'b0}};
assign iqentry_4_cumulative = (branchmiss ? missid == 3'd4 : cmt_miss_id==3'd4)
				? iqentry_4_livetarget
				: iqentry_4_livetarget | iqentry_5_cumulative;

assign iqentry_5_latestID = ((branchmiss ? missid == 3'd5 : cmt_miss_id==3'd5 )|| ((iqentry_5_livetarget & iqentry_6_cumulative) == {NREGS{1'b0}}))
				? iqentry_5_livetarget
				: 287'd0;
assign iqentry_5_cumulative = (branchmiss ? missid == 3'd5 : cmt_miss_id==3'd5)
				? iqentry_5_livetarget
				: iqentry_5_livetarget | iqentry_6_cumulative;

assign iqentry_6_latestID = ((branchmiss ? missid == 3'd6 : cmt_miss_id==3'd6) || ((iqentry_6_livetarget & iqentry_7_cumulative) == {NREGS{1'b0}}))
				? iqentry_6_livetarget
				: {NREGS{1'b0}};
assign iqentry_6_cumulative = (branchmiss ? missid == 3'd6 : cmt_miss_id==3'd6)
				? iqentry_6_livetarget
				: iqentry_6_livetarget | iqentry_7_cumulative;

assign iqentry_7_latestID = ((branchmiss ? missid == 3'd7 : cmt_miss_id==3'd7) || ((iqentry_7_livetarget & iqentry_0_cumulative) == {NREGS{1'b0}}))
				? iqentry_7_livetarget
				: {NREGS{1'b0}};
assign iqentry_7_cumulative = (branchmiss ? missid==3'd7 : cmt_miss_id== 3'd7)
				? iqentry_7_livetarget
				: iqentry_7_livetarget | iqentry_0_cumulative;

assign
	iqentry_source[0] = | iqentry_0_latestID,
	iqentry_source[1] = | iqentry_1_latestID,
	iqentry_source[2] = | iqentry_2_latestID,
	iqentry_source[3] = | iqentry_3_latestID,
	iqentry_source[4] = | iqentry_4_latestID,
	iqentry_source[5] = | iqentry_5_latestID,
	iqentry_source[6] = | iqentry_6_latestID,
	iqentry_source[7] = | iqentry_7_latestID;


//assign iqentry_0_islot = iqentry_islot[0];
//assign iqentry_1_islot = iqentry_islot[1];
//assign iqentry_2_islot = iqentry_islot[2];
//assign iqentry_3_islot = iqentry_islot[3];
//assign iqentry_4_islot = iqentry_islot[4];
//assign iqentry_5_islot = iqentry_islot[5];
//assign iqentry_6_islot = iqentry_islot[6];
//assign iqentry_7_islot = iqentry_islot[7];

// A single instruction can require 3 read ports. Only a total of four read
// ports are supported because most of the time that's enough.
// If there aren't enough read ports available then the second instruction
// isn't enqueued (it'll be enqueued in the next cycle).
reg [1:0] ports_avail;  // available read ports for instruction #3.
reg [6:0] pRa0,pRb0,pRa1,pRb1;
wire [DBW:0] prfoa0,prfob0,prfoa1,prfob1;
`ifdef THREEWAY
wire [6:0] Ra0 = fnRa(fetchbuf0_instr);
wire [6:0] Rb0 = fnRb(fetchbuf0_instr);
wire [6:0] Rc0 = fnRc(fetchbuf0_instr);
wire [6:0] Ra1 = fnRa(fetchbuf1_instr);
wire [6:0] Rb1 = fnRb(fetchbuf1_instr);
wire [6:0] Rc1 = fnRc(fetchbuf1_instr);
wire [6:0] Ra2 = fnRa(fetchbuf2_instr);
wire [6:0] Rb2 = fnRb(fetchbuf2_instr);
wire [6:0] Rc2 = fnRc(fetchbuf2_instr);
wire [6:0] Rt0 = fnTargetReg(fetchbuf0_instr);
wire [6:0] Rt1 = fnTargetReg(fetchbuf1_instr);
wire [6:0] Rt2 = fnTargetReg(fetchbuf2_instr);

case (fnNumReadPorts(fetchbuf0_instr))
2'd0:
       begin
       pRa0 = Ra2; pRb0 = Rb2; pRc0 = Rc2;
       pRa1 = Ra1; pRb1 = Rb1; pRc1 = Rc1;
       ports_avail = 2'd3;
       rfoa0 = 64'd0;
       rfob0 = 64'd0;
       rfoc0 = 64'd0;
       rfoa1 = prfoa1;
       rfob1 = prfob1;
       rfoc1 = prfoc1;
       rfoa2 = prfoa0;
       rfob2 = prfob0;
       rfoc3 = prfoc0;
       end
2'd1:  begin
       pRa0 = Ra0; pRb0 = Ra2; pRc0 = Rb2;
       if (fnNumReadPorts(fetchbuf1_instr))< 3'd3)
           pRc1 = Rc2;
           ports_avail = 2'd3;
       end       
       else
           ports_avail = 2'd2;
2'd2:
       begin
       pRa0 = Ra0; pRb0 = Rb0; pRc0 = Ra2;
       if (fnNumReadPorts(fetchbuf1_instr))< 3'd2) begin
           pRb1 = Rb2; pRc1 = Rc2;
           ports_avail = 2'd3;
       end
       else if (fnNumReadPorts(fetchbuf1_instr))< 3'd3) begin
           pRc1 = Rb2;
           ports_avail = 2'd2;
       end
       else
           ports_avail = 2'd1;
       end
2'd3:  begin
           pRa0 = Ra0; pRb0 = Rb0; pRc0 = Rc0;
           if (fnNumReadPorts(fetchbuf1_instr))< 3'd2) begin
               pRb1 = Ra2; pRc1 = Rb2;
               ports_avail = 3'd2;
           end
           else if (fnNumReadPorts(fetchbuf1_instr))< 3'd3) begin
               pRc1 = Rc2;
               ports_avail = 3'd1;
           end
           else
               ports_avail = 3'd0;
       end
endcase
`else
wire [6:0] Ra0 = fnRa(fetchbuf0_instr);
wire [6:0] Rb0 = fnRb(fetchbuf0_instr);
wire [6:0] Rc0 = fnRc(fetchbuf0_instr);
wire [6:0] Ra1 = fnRa(fetchbuf1_instr);
wire [6:0] Rb1 = fnRb(fetchbuf1_instr);
wire [6:0] Rc1 = fnRc(fetchbuf1_instr);
wire [6:0] Rt0 = fnTargetReg(fetchbuf0_instr);
wire [6:0] Rt1 = fnTargetReg(fetchbuf1_instr);
always @*
    case(fetchbuf0_v ? fnNumReadPorts(fetchbuf0_instr) : 2'd0)
    2'd0:   begin
            pRa0 = 7'd0;
            pRb0 = Rc1;
            pRa1 = Ra1;
            pRb1 = Rb1;
            rfoa0 = 64'd0;
            rfob0 = 64'd0;
            rfoc0 = 64'd0;
            rfoa1 = prfoa1;
            rfob1 = prfob1;
            rfoc1 = prfob0;
            ports_avail = 2'd3;
            end
    2'd1:   begin
            pRa0 = Ra0;
            pRb0 = Rc1;
            pRa1 = Ra1;
            pRb1 = Rb1;
            rfoa0 = prfoa0;
            rfob0 = 64'd0;
            rfoc0 = 64'd0;
            rfoa1 = prfoa1;
            rfob1 = prfob1;
            rfoc1 = prfob0;
            ports_avail = 2'd3;
            end
    2'd2:   begin
            pRa0 = Ra0;
            pRb0 = Rb0;
            pRa1 = Ra1;
            pRb1 = Rb1;
            rfoa0 = prfoa0;
            rfob0 = prfob0;
            rfoc0 = 64'd0;
            rfoa1 = prfoa1;
            rfob1 = prfob1;
            rfoc1 = 64'd0; 
            ports_avail = 2'd2;
            end   
    2'd3:   begin
            pRa0 = Ra0;
            pRb0 = Rb0;
            pRa1 = Rc0;
            pRb1 = Ra1;
            rfoa0 = prfoa0;
            rfob0 = prfob0;
            rfoc0 = prfoa1;
            rfoa1 = prfob1;
            rfob1 = 64'd0;
            rfoc1 = 64'd0;
            ports_avail = 2'd1;
            end
    endcase
`endif

/*
wire [8:0] Rb0 = ((fnNumReadPorts(fetchbuf0_instr) < 3'd2) || !fetchbuf0_v) ? {1'b0,fetchbuf1_instr[`INSTRUCTION_RC]} :
				fnRb(fetchbuf0_instr);
wire [8:0] Ra1 = (!fetchbuf0_v || fnNumReadPorts(fetchbuf0_instr) < 3'd3) ? fnRa(fetchbuf1_instr) :
					fetchbuf0_instr[`INSTRUCTION_RC];
wire [8:0] Rb1 = (fnNumReadPorts(fetchbuf1_instr) < 3'd2 && fetchbuf0_v) ? fnRa(fetchbuf1_instr):fnRb(fetchbuf1_instr);
*/
function [7:0] fnOpcode;
input [63:0] ins;
fnOpcode = (ins[3:0]==4'h0 && ins[7:4] > 4'h1 && ins[7:4] < 4'h9) ? `IMM : 
						ins[7:0]==8'h10 ? `NOP :
						ins[7:0]==8'h11 ? `RTS : ins[15:8];
endfunction

wire [7:0] opcode0 = fnOpcode(fetchbuf0_instr);
wire [7:0] opcode1 = fnOpcode(fetchbuf1_instr);
wire [3:0] cond0 = fetchbuf0_instr[3:0];
wire [3:0] cond1 = fetchbuf1_instr[3:0];
wire [3:0] Pn0 = fetchbuf0_instr[7:4];
wire [3:0] Pt0 = fetchbuf0_instr[11:8];
wire [3:0] Pn1 = fetchbuf1_instr[7:4];
wire [3:0] Pt1 = fetchbuf1_instr[11:8];
`ifdef THREEWAY
wire [3:0] Pn2 = fetchbuf2_instr[7:4];
wire [3:0] Pt2 = fetchbuf2_instr[11:8];
`endif

function [6:0] fnRa;
input [63:0] insn;
case(insn[7:0])
8'h11:	fnRa = 7'h51;    // RTS short form
default:
	case(insn[15:8])
	`RTI:	fnRa = 7'h5E;
	`RTE:	fnRa = 7'h5D;
	`JSR,`JSRS,`JSRZ,`SYS,`INT,`RTS,`RTS2:
		fnRa = {3'h5,insn[23:20]};
	`TLB:  fnRa = {1'b0,insn[29:24]};
	default:	fnRa = {1'b0,insn[`INSTRUCTION_RA]};
	endcase
endcase
endfunction

function [6:0] fnRb;
input [63:0] insn;
if (insn[7:0]==8'h11)	// RTS short form
	fnRb = 7'h51;
else
	case(insn[15:8])
	`RTI:	fnRb = 7'h5E;
	`RTE:	fnRb = 7'h5D;
	`RTS2:  fnRb = 7'd27;
	`RTS,`STP,`TLB:   fnRb = 7'd0;
	`LOOP:  fnRb = 7'h73;
	`JSR,`JSRS,`JSRZ,`SYS,`INT:
		fnRb = {3'h5,insn[23:20]};
	`SWS:   fnRb = {1'b1,insn[27:22]};
	default:	fnRb = {1'b0,insn[`INSTRUCTION_RB]};
	endcase
endfunction

function [6:0] fnRc;
input [63:0] insn;
fnRc = {1'b0,insn[`INSTRUCTION_RC]};
endfunction

function [3:0] fnCar;
input [63:0] insn;
if (insn[7:0]==8'h11)	// RTS short form
	fnCar = 4'h1;
else
	case(insn[15:8])
	`RTI:	fnCar = 4'hE;
	`RTE:	fnCar = 4'hD;
	`JSR,`JSRS,`JSRZ,`SYS,`INT,`RTS,`RTS2:
		fnCar = {insn[23:20]};
	default:	fnCar = 4'h0;
	endcase
endfunction

function [5:0] fnFunc;
input [63:0] insn;
if (insn[7:0]==8'h11)   // RTS short form
    fnFunc = 6'h00;     // func is used as a small immediate
else
casex(insn[15:8])
`BITFIELD:	fnFunc = insn[43:40];
`CMP:	fnFunc = insn[31:28];
`TST:	fnFunc = insn[23:22];
`INC:   fnFunc = insn[24:22];
`RTS,`RTS2: fnFunc = insn[19:16];   // used to pass a small immediate
`CACHE: fnFunc = insn[31:26];
default:
	fnFunc = insn[39:34];
endcase
endfunction

// Returns true if the operation is limited to ALU #0
function fnIsAlu0Op;
input [7:0] opcode;
input [5:0] func;
case(opcode)
`R:
    case(func)
    `CNTLZ,`CNTLO,`CNTPOP:  fnIsAlu0Op = `TRUE;
    `ABS,`SGN,`ZXB,`ZXC,`ZXH,`SXB,`SXC,`SXH:  fnIsAlu0Op = `TRUE;
    default:    fnIsAlu0Op = `FALSE;
    endcase
`RR:
    case(func)
    `DIV,`DIVU: fnIsAlu0Op = `TRUE;
    `MIN,`MAX:  fnIsAlu0Op = `TRUE;
    default:    fnIsAlu0Op = `FALSE;
    endcase
`BCD:       fnIsAlu0Op = `TRUE;
`DIVI,`DIVUI:   fnIsAlu0Op = `TRUE;
//`DOUBLE:    fnIsAlu0Op = `TRUE;
`SHIFT:     fnIsAlu0Op = `TRUE;
`BITFIELD:  fnIsAlu0Op = `TRUE;
default:    fnIsAlu0Op = `FALSE;
endcase
endfunction

`ifdef THREEWAY
Thor_regfile2w9r #(DBW) urf1
(
	.clk(clk),
	.rclk(~clk),
	.wr0(commit0_v && ~commit0_tgt[6] && iqentry_op[head0]!=`MTSPR),
	.wr1(commit1_v && ~commit1_tgt[6] && iqentry_op[head1]!=`MTSPR),
	.wa0(commit0_tgt[5:0]),
	.wa1(commit1_tgt[5:0]),
	.ra0(Ra0[5:0]),
	.ra1(Rb0[5:0]),
	.ra2(Rc0[5:0]),
	.ra3(Ra1[5:0]),
	.ra4(Rb1[5:0]),
	.ra5(Rc1[5:0]),
	.ra6(Ra2[5:0]),
	.ra7(Rb2[5:0]),
	.ra8(Rc2[5:0]),
	.i0(commit0_bus),
	.i1(commit1_bus),
	.o0(rfoa0),
	.o1(rfob0),
	.o2(rfoc0),
	.o3(rfoa1),
	.o4(rfob1),
	.o5(rfoc1),
	.o6(rfoa2),
    .o7(rfob2),
    .o8(rfoc2)
);
`else
Thor_regfile2w4r #(DBW) urf1
(
	.clk(clk),
	.rclk(~clk),
	.wr0(commit0_v && ~commit0_tgt[6] && iqentry_op[head0]!=`MTSPR),
	.wr1(commit1_v && ~commit1_tgt[6] && iqentry_op[head1]!=`MTSPR),
	.wa0(commit0_tgt[5:0]),
	.wa1(commit1_tgt[5:0]),
	.ra0(pRa0[5:0]),
	.ra1(pRb0[5:0]),
	.ra2(pRa1[5:0]),
	.ra3(pRb1[5:0]),
	.i0(commit0_bus),
	.i1(commit1_bus),
	.o0(prfoa0),
	.o1(prfob0),
	.o2(prfoa1),
	.o3(prfob1)
);
`endif

wire [63:0] cregs0 = fnCar(fetchbuf0_instr)==4'd0 ? 64'd0 : fnCar(fetchbuf0_instr)==4'hF ? fetchbuf0_pc : cregs[fnCar(fetchbuf0_instr)];
wire [63:0] cregs1 = fnCar(fetchbuf1_instr)==4'd0 ? 64'd0 : fnCar(fetchbuf1_instr)==4'hF ? fetchbuf1_pc : cregs[fnCar(fetchbuf1_instr)];
`ifdef THREEWAY
wire [63:0] cregs2 = fnCar(fetchbuf2_instr)==4'd0 ? 64'd0 : fnCar(fetchbuf2_instr)==4'hF ? fetchbuf2_pc : cregs[fnCar(fetchbuf2_instr)];
`endif
//
// 1 if the the operand is automatically valid, 
// 0 if we need a RF value
function fnSource1_v;
input [7:0] opcode;
	casex(opcode)
	`SEI,`CLI,`MEMSB,`MEMDB,`SYNC,`NOP,`STP:
					fnSource1_v = 1'b1;
	`BR,`LOOP:		fnSource1_v = 1'b1;
	`LDI,`LDIS,`IMM:	fnSource1_v = 1'b1;
	default:		fnSource1_v = 1'b0;
	endcase
endfunction

//
// 1 if the the operand is automatically valid, 
// 0 if we need a RF value
function fnSource2_v;
input [7:0] opcode;
input [5:0] func;
	casex(opcode)
	`R:		fnSource2_v = 1'b1;
	`LDI,`STI,`LDIS,`IMM,`NOP,`STP:		fnSource2_v = 1'b1;
	`SEI,`CLI,`MEMSB,`MEMDB,`SYNC:
					fnSource2_v = 1'b1;
	`RTI,`RTE:		fnSource2_v = 1'b1;
	`TST:			fnSource2_v = 1'b1;
	`ADDI,`ADDUI,`ADDUIS:
	                fnSource2_v = 1'b1;
	`_2ADDUI,`_4ADDUI,`_8ADDUI,`_16ADDUI:
					fnSource2_v = 1'b1;
	`SUBI,`SUBUI:	fnSource2_v = 1'b1;
	`CMPI:			fnSource2_v = 1'b1;
	`MULI,`MULUI,`DIVI,`DIVUI:
					fnSource2_v = 1'b1;
	`ANDI,`BITI:	fnSource2_v = 1'b1;
	`ORI:			fnSource2_v = 1'b1;
	`EORI:			fnSource2_v = 1'b1;
	`SHIFT:
	           if (func>=6'h10)
	               fnSource2_v = `TRUE;
	           else
	               fnSource2_v = `FALSE;
	`CACHE,`LCL,`TLB,
	`LVB,`LVC,`LVH,`LVW,`LVWAR,
	`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`LWS,`LEA,`STI,`INC:
			fnSource2_v = 1'b1;
	`JSR,`JSRS,`JSRZ,`SYS,`INT,`RTS,`BR:
			fnSource2_v = 1'b1;
	`MTSPR,`MFSPR:
				fnSource2_v = 1'b1;
//	`BFSET,`BFCLR,`BFCHG,`BFEXT,`BFEXTU:	// but not BFINS
//				fnSource2_v = 1'b1;
	default:	fnSource2_v = 1'b0;
	endcase
endfunction


// Source #3 valid
// Since most instructions don't use a third source the default it to return 
// a valid status.
// 1 if the the operand is automatically valid, 
// 0 if we need a RF value
function fnSource3_v;
input [7:0] opcode;
	casex(opcode)
	`SBX,`SCX,`SHX,`SWX,`CAS,`STMV,`STCMP,`STFND:	fnSource3_v = 1'b0;
	`MUX:	fnSource3_v = 1'b0;
	default:	fnSource3_v = 1'b1;
	endcase
endfunction

// Return the number of register read ports required for an instruction.
function [2:0] fnNumReadPorts;
input [63:0] ins;
casex(fnOpcode(ins))
`SEI,`CLI,`MEMSB,`MEMDB,`SYNC,`NOP,`MOVS,`STP:
					fnNumReadPorts = 3'd0;
`BR:                fnNumReadPorts = 3'd0;
`LOOP:				fnNumReadPorts = 3'd0;
`LDI,`LDIS,`IMM:		fnNumReadPorts = 3'd0;
`R,`STI:	        fnNumReadPorts = 3'd1;
`RTI,`RTE:			fnNumReadPorts = 3'd1;
`TST:				fnNumReadPorts = 3'd1;
`ADDI,`ADDUI,`ADDUIS:
                    fnNumReadPorts = 3'd1;
`_2ADDUI,`_4ADDUI,`_8ADDUI,`_16ADDUI:
					fnNumReadPorts = 3'd1;
`SUBI,`SUBUI:		fnNumReadPorts = 3'd1;
`CMPI:				fnNumReadPorts = 3'd1;
`MULI,`MULUI,`DIVI,`DIVUI:
					fnNumReadPorts = 3'd1;
`BITI,
`ANDI,`ORI,`EORI:	fnNumReadPorts = 3'd1;
`SHIFT:
                    if (ins[39:38]==2'h1)   // shift immediate
					   fnNumReadPorts = 3'd1;
					else
					   fnNumReadPorts = 3'd2;
`RTS2,`CACHE,`LCL,`TLB,					 
`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`LVB,`LVC,`LVH,`LVW,`LVWAR,`LWS,`LEA,`INC:
					fnNumReadPorts = 3'd1;
`JSR,`JSRS,`JSRZ,`SYS,`INT,`RTS,`BR,`LOOP:
					fnNumReadPorts = 3'd1;
`SBX,`SCX,`SHX,`SWX,
`MUX,`CAS,`STMV,`STCMP:
					fnNumReadPorts = 3'd3;
`MTSPR,`MFSPR:		fnNumReadPorts = 3'd1;
`STFND:	   fnNumReadPorts = 3'd2;	// *** TLB reads on Rb we say 2 for simplicity
`BITFIELD:
    case(ins[43:40])
    `BFSET,`BFCLR,`BFCHG,`BFEXT,`BFEXTU:
					fnNumReadPorts = 3'd1;
    `BFINS:         fnNumReadPorts = 3'd2;
    default:        fnNumReadPorts = 3'd0;
    endcase
default:			fnNumReadPorts = 3'd2;
endcase
endfunction

function fnIsBranch;
input [7:0] opcode;
casex(opcode)
`BR:	fnIsBranch = `TRUE;
default:	fnIsBranch = `FALSE;
endcase
endfunction

function fnIsStoreString;
input [7:0] opcode;
fnIsStoreString =
	opcode==`STS;
endfunction

wire xbr = (iqentry_op[head0]==`BR) || (iqentry_op[head1]==`BR);
wire takb = (iqentry_op[head0]==`BR) ? commit0_v : commit1_v;
wire [DBW-1:0] xbrpc = (iqentry_op[head0]==`BR) ? iqentry_pc[head0] : iqentry_pc[head1];

wire predict_takenA,predict_takenB,predict_takenC,predict_takenD;

// There are really only two branch tables required one for fetchbuf0 and one
// for fetchbuf1. Synthesis removes the extra tables.
//
Thor_BranchHistory #(DBW) ubhtA
(
	.rst(rst_i),
	.clk(clk),
	.advanceX(xbr),
	.xisBranch(xbr),
	.pc(pc),
	.xpc(xbrpc),
	.takb(takb),
	.predict_taken(predict_takenA)
);

Thor_BranchHistory #(DBW) ubhtB
(
	.rst(rst_i),
	.clk(clk),
	.advanceX(xbr),
	.xisBranch(xbr),
	.pc(pc+fnInsnLength(insn)),
	.xpc(xbrpc),
	.takb(takb),
	.predict_taken(predict_takenB)
);

Thor_BranchHistory #(DBW) ubhtC
(
	.rst(rst_i),
	.clk(clk),
	.advanceX(xbr),
	.xisBranch(xbr),
	.pc(pc),
	.xpc(xbrpc),
	.takb(takb),
	.predict_taken(predict_takenC)
);

Thor_BranchHistory #(DBW) ubhtD
(
	.rst(rst_i),
	.clk(clk),
	.advanceX(xbr),
	.xisBranch(xbr),
	.pc(pc+fnInsnLength(insn)),
	.xpc(xbrpc),
	.takb(takb),
	.predict_taken(predict_takenD)
);

`ifdef THREEWAY
Thor_BranchHistory #(DBW) ubhtE
(
	.rst(rst_i),
	.clk(clk),
	.advanceX(xbr),
	.xisBranch(xbr),
	.pc(pc+fnInsnLength(insn)+fnInsnLength1(insn)),
	.xpc(xbrpc),
	.takb(takb),
	.predict_taken(predict_takenE)
);
Thor_BranchHistory #(DBW) ubhtF
(
	.rst(rst_i),
	.clk(clk),
	.advanceX(xbr),
	.xisBranch(xbr),
	.pc(pc+fnInsnLength(insn)+fnInsnLength1(insn)),
	.xpc(xbrpc),
	.takb(takb),
	.predict_taken(predict_takenF)
);
`endif

Thor_icachemem #(DBW) uicm1
(
	.wclk(clk),
	.wce(cstate==ICACHE1),
	.wr(ack_i|err_i),
	.wa(adr_o),
	.wd({err_i,dat_i}),
	.rclk(~clk),
	.pc(ppc),
	.insn(insn)
);

wire hit0,hit1;
reg ic_ld;
reg [31:0] ic_ld_cntr;
Thor_itagmem #(DBW-1) uitm1
(
	.wclk(clk),
	.wce((cstate==ICACHE1 && cti_o==3'b111)|ic_ld),
	.wr(ack_i|err_i|ic_ld),
	.wa(adr_o|ic_ld_cntr),
	.err_i(err_i|ierr),
	.invalidate(ic_invalidate),
	.invalidate_line(ic_invalidate_line),
	.invalidate_lineno(ic_lineno),
	.rclk(~clk),
	.rce(1'b1),
	.pc(ppc),
	.hit0(hit0),
	.hit1(hit1),
	.err_o(insnerr)
);

wire ihit = hit0 & hit1;
wire do_pcinc = ihit;
wire ld_fetchbuf = ihit || (nmi_edge & !StatusHWI)||(irq_i & ~im & !StatusHWI);

wire whit;

Thor_dcachemem_1w1r #(DBW) udcm1
(
	.wclk(clk),
	.wce(whit || cstate==DCACHE1),
	.wr(ack_i|err_i),
	.sel(whit ? sel_o : 8'hFF),
	.wa(adr_o),
	.wd(whit ? dat_o : dat_i),
	.rclk(~clk),
	.rce(1'b1),
	.ra(pea),
	.o(cdat)
);

Thor_dtagmem #(DBW-1) udtm1
(
	.wclk(clk),
	.wce(cstate==DCACHE1 && cti_o==3'b111),
	.wr(ack_i|err_i),
	.wa(adr_o),
	.err_i(err_i|derr),
	.invalidate(dc_invalidate),
	.invalidate_line(dc_invalidate_line),
    .invalidate_lineno(dc_lineno),
	.rclk(~clk),
	.rce(1'b1),
	.ra(pea),
	.whit(whit),
	.rhit(rhit),
	.err_o()
);

wire [DBW-1:0] shfto0,shfto1;

function fnIsShiftiop;
input [63:0] insn;
fnIsShiftiop =  insn[15:8]==`SHIFT && (
                insn[39:34]==`SHLI || insn[39:34]==`SHLUI ||
				insn[39:34]==`SHRI || insn[39:34]==`SHRUI ||
				insn[39:34]==`ROLI || insn[39:34]==`RORI
				)
				;
endfunction

function fnIsShiftop;
input [7:0] opcode;
fnIsShiftop = opcode==`SHL || opcode==`SHLI || opcode==`SHLU || opcode==`SHLUI ||
				opcode==`SHR || opcode==`SHRI || opcode==`SHRU || opcode==`SHRUI ||
				opcode==`ROL || opcode==`ROLI || opcode==`ROR || opcode==`RORI
				;
endfunction

function fnIsFP;
input [7:0] opcode;
fnIsFP = 	opcode==`DOUBLE_R||opcode==`FLOAT||opcode==`SINGLE_R;
//            opcode==`ITOF || opcode==`FTOI || opcode==`FNEG || opcode==`FSIGN || /*opcode==`FCMP || */ opcode==`FABS ||
//			opcode==`FADD || opcode==`FSUB || opcode==`FMUL || opcode==`FDIV
//			;
endfunction

function fnIsFPCtrl;
input [63:0] insn;
fnIsFPCtrl = (insn[15:8]==`SINGLE_R && (insn[31:28]==`FTX||insn[31:28]==`FCX||insn[31:28]==`FDX||insn[31:28]==`FEX)) ||
             (insn[15:8]==`DOUBLE_R && (insn[31:28]==`FRM))
             ;
endfunction

function fnIsBitfield;
input [7:0] opcode;
fnIsBitfield = opcode==`BFSET || opcode==`BFCLR || opcode==`BFCHG || opcode==`BFINS || opcode==`BFEXT || opcode==`BFEXTU;
endfunction

//wire [3:0] Pn = ir[7:4];

// Set the target register
// 00-3F = general register file
// 40-4F = predicate register
// 50-5F = code address register
// 60-67 = segment base register
// 70 = predicate register horizontal
// 73 = loop counter
function [6:0] fnTargetReg;
input [63:0] ir;
begin
	if (ir[3:0]==4'h0)	// Process special predicates
		fnTargetReg = 7'h000;
	else
		casex(fnOpcode(ir))
		`LDI,`ADDUIS,`STS:
			fnTargetReg = {1'b0,ir[21:16]};
		`LDIS:
			fnTargetReg = {1'b1,ir[21:16]};
		`RR:
			fnTargetReg = {1'b0,ir[33:28]};
		`BCD,
		`LOGIC,`FLOAT,
		`LWX,`LBX,`LBUX,`LCX,`LCUX,`LHX,`LHUX,`STMV,`STCMP,`STFND:
			fnTargetReg = {1'b0,ir[33:28]};
		`SHIFT:
			fnTargetReg = {1'b0,ir[33:28]};
		`R,`DOUBLE_R,`SINGLE_R,
		`ADDI,`ADDUI,`SUBI,`SUBUI,`MULI,`MULUI,`DIVI,`DIVUI,
		`_2ADDUI,`_4ADDUI,`_8ADDUI,`_16ADDUI,
		`ANDI,`ORI,`EORI,
		`LVB,`LVC,`LVH,`LVW,`LVWAR,
		`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`LEA:
			fnTargetReg = {1'b0,ir[27:22]};
		`CAS:
			fnTargetReg = {1'b0,ir[39:34]};
		`BITFIELD:
			fnTargetReg = {1'b0,ir[27:22]};
		`TLB:
			if (ir[19:16]==`TLB_RDREG)
				fnTargetReg = {1'b0,ir[29:24]};
			else
				fnTargetReg = 7'h00;
		`MFSPR:
			fnTargetReg = {1'b0,ir[27:22]};
		`BITI:
		      fnTargetReg = {3'h4,ir[25:22]};
		`CMP,`CMPI,`TST:
		    begin
			fnTargetReg = {3'h4,ir[11:8]};
			end
		`SWCR:    fnTargetReg = {3'h4,4'h0};
		`JSR,`JSRZ,`JSRS,`SYS,`INT:
			fnTargetReg = {3'h5,ir[19:16]};
		`MTSPR,`MOVS,`LWS:
		    fnTargetReg = {1'b1,ir[27:22]};
/*
			if (ir[27:26]==2'h1)		// Move to code address register
				fnTargetReg = {3'h5,ir[25:22]};
			else if (ir[27:26]==2'h2)	// Move to seg. reg.
				fnTargetReg = {3'h6,ir[25:22]};
			else if (ir[27:22]==6'h04)
				fnTargetReg = 7'h70;
			else
				fnTargetReg = 7'h00;
*/      
        `RTS2:    fnTargetReg = 7'd27;
        `LOOP:      fnTargetReg = 7'h73;
        `STP:       fnTargetReg = 7'h7F;
		default:	fnTargetReg = 7'h00;
		endcase
end
endfunction
/*
function fnAllowedReg;
input [8:0] regno;
fnAllowedReg = allowedRegs[regno] ? regno : 9'h000;
endfunction
*/
function fnTargetsCa;
input [63:0] ir;
begin
if (ir[3:0]==4'h0)
	fnTargetsCa = `FALSE;
else begin
	case(fnOpcode(ir))
	`JSR,`JSRZ,`JSRS,`SYS,`INT:
	       fnTargetsCa = `TRUE;
	`LWS:
		if (ir[27:26]==2'h1)
			fnTargetsCa = `TRUE;
		else
			fnTargetsCa = `FALSE;
	`LDIS:
		if (ir[21:20]==2'h1)
			fnTargetsCa = `TRUE;
		else
			fnTargetsCa = `FALSE;
	`MTSPR,`MOVS:
		begin
			if (ir[27:26]==2'h1)
				fnTargetsCa = `TRUE;
			else
				fnTargetsCa = `FALSE;
		end
	default:	fnTargetsCa = `FALSE;
	endcase
end
end
endfunction

function fnTargetsSegreg;
input [63:0] ir;
if (ir[3:0]==4'h0)
	fnTargetsSegreg = `FALSE;
else
	case(fnOpcode(ir))
	`LWS:
		if (ir[27:26]==2'h2)
			fnTargetsSegreg = `TRUE;
		else
			fnTargetsSegreg = `FALSE;
	`LDIS:
		if (ir[21:20]==2'h2)
			fnTargetsSegreg = `TRUE;
		else
			fnTargetsSegreg = `FALSE;
	`MTSPR,`MOVS:
		if (ir[27:26]==2'h2)
			fnTargetsSegreg = `TRUE;
		else
			fnTargetsSegreg = `FALSE;
	default:	fnTargetsSegreg = `FALSE;
	endcase
endfunction

function fnHasConst;
input [7:0] opcode;
	casex(opcode)
	`BFCLR,`BFSET,`BFCHG,`BFEXT,`BFEXTU,`BFINS,
	`LDI,`LDIS,`ADDUIS,
	`ADDI,`SUBI,`ADDUI,`SUBUI,`MULI,`MULUI,`DIVI,`DIVUI,
	`_2ADDUI,`_4ADDUI,`_8ADDUI,`_16ADDUI,
	`CMPI,
	`ANDI,`ORI,`EORI,`BITI,
//	`SHLI,`SHLUI,`SHRI,`SHRUI,`ROLI,`RORI,
	`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`LWS,`LEA,`INC,
	`LVB,`LVC,`LVH,`LVW,`LVWAR,`STI,
	`SB,`SC,`SH,`SW,`SWCR,`CAS,`SWS,
	`JSR,`JSRS,`SYS,`INT,`BR,`RTS2,`LOOP:
		fnHasConst = 1'b1;
	default:
		fnHasConst = 1'b0;
	endcase
endfunction

function fnIsFlowCtrl;
input [7:0] opcode;
begin
casex(opcode)
`JSR,`JSRS,`JSRZ,`SYS,`INT,`LOOP,`BR,`RTS,`RTS2,`RTI,`RTE:
	fnIsFlowCtrl = 1'b1;
default:	fnIsFlowCtrl = 1'b0;
endcase
end
endfunction

function fnCanException;
input [7:0] op;
input [5:0] func;
case(op)
`FLOAT:
    case(func)
    `FDIVS,`FMULS,`FADDS,`FSUBS,
    `FDIV,`FMUL,`FADD,`FSUB:
        fnCanException = `TRUE;
    endcase
`SINGLE_R:
    if (func==`FTX) fnCanException = `TRUE;
`ADD,`ADDI,`SUB,`SUBI,`DIV,`DIVI,`MUL,`MULI:
    fnCanException = `TRUE;
default:
    fnCanException = fnIsMem(op);
endcase
endfunction

// Return the length of an instruction.
function [3:0] fnInsnLength;
input [127:0] insn;
casex(insn[15:0])
16'bxxxxxxxx00000000:	fnInsnLength = 4'd1;	// BRK
16'bxxxxxxxx00010000:	fnInsnLength = 4'd1;	// NOP
16'bxxxxxxxx00100000:	fnInsnLength = 4'd2;
16'bxxxxxxxx00110000:	fnInsnLength = 4'd3;
16'bxxxxxxxx01000000:	fnInsnLength = 4'd4;
16'bxxxxxxxx01010000:	fnInsnLength = 4'd5;
16'bxxxxxxxx01100000:	fnInsnLength = 4'd6;
16'bxxxxxxxx01110000:	fnInsnLength = 4'd7;
16'bxxxxxxxx10000000:	fnInsnLength = 4'd8;
16'bxxxxxxxx00010001:	fnInsnLength = 4'd1;	// RTS short form
default:
	casex(insn[15:8])
	`NOP,`SEI,`CLI,`RTI,`RTE,`MEMSB,`MEMDB,`SYNC:
		fnInsnLength = 4'd2;
	`TST,`BR,`JSRZ,`RTS,`CACHE,`LOOP:
		fnInsnLength = 4'd3;
	`SYS,`CMP,`CMPI,`MTSPR,`MFSPR,`LDI,`LDIS,`ADDUIS,`R,`TLB,`MOVS,`RTS2,`STP:
		fnInsnLength = 4'd4;
	`BITFIELD,`JSR,`MUX,`BCD,`INC:
		fnInsnLength = 4'd6;
	`CAS:
		fnInsnLength = 4'd6;
	default:
		fnInsnLength = 4'd5;
	endcase
endcase
endfunction

function [3:0] fnInsnLength1;
input [127:0] insn;
case(fnInsnLength(insn))
4'd1:	fnInsnLength1 = fnInsnLength(insn[127: 8]);
4'd2:	fnInsnLength1 = fnInsnLength(insn[127:16]);
4'd3:	fnInsnLength1 = fnInsnLength(insn[127:24]);
4'd4:	fnInsnLength1 = fnInsnLength(insn[127:32]);
4'd5:	fnInsnLength1 = fnInsnLength(insn[127:40]);
4'd6:	fnInsnLength1 = fnInsnLength(insn[127:48]);
4'd7:	fnInsnLength1 = fnInsnLength(insn[127:56]);
4'd8:	fnInsnLength1 = fnInsnLength(insn[127:64]);
default:	fnInsnLength1 = 4'd0;
endcase
endfunction

function [3:0] fnInsnLength2;
input [127:0] insn;
case(fnInsnLength(insn)+fnInsnLength1(insn))
4'd2:	fnInsnLength2 = fnInsnLength(insn[127:16]);
4'd3:	fnInsnLength2 = fnInsnLength(insn[127:24]);
4'd4:	fnInsnLength2 = fnInsnLength(insn[127:32]);
4'd5:	fnInsnLength2 = fnInsnLength(insn[127:40]);
4'd6:	fnInsnLength2 = fnInsnLength(insn[127:48]);
4'd7:	fnInsnLength2 = fnInsnLength(insn[127:56]);
4'd8:	fnInsnLength2 = fnInsnLength(insn[127:64]);
4'd9:	fnInsnLength2 = fnInsnLength(insn[127:72]);
4'd10:	fnInsnLength2 = fnInsnLength(insn[127:80]);
4'd11:	fnInsnLength2 = fnInsnLength(insn[127:88]);
4'd12:	fnInsnLength2 = fnInsnLength(insn[127:96]);
4'd13:	fnInsnLength2 = fnInsnLength(insn[127:104]);
4'd14:	fnInsnLength2 = fnInsnLength(insn[127:112]);
4'd15:	fnInsnLength2 = fnInsnLength(insn[127:120]);
default:	fnInsnLength2 = 4'd0;
endcase
endfunction

wire [5:0] total_insn_length = fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
wire [5:0] insn_length12 = fnInsnLength(insn) + fnInsnLength1(insn);
wire insn3_will_fit = total_insn_length < 6'd16;

always @(fetchbuf or fetchbufA_instr or fetchbufA_v or fetchbufA_pc
 or fetchbufB_instr or fetchbufB_v or fetchbufB_pc
 or fetchbufC_instr or fetchbufC_v or fetchbufC_pc
 or fetchbufD_instr or fetchbufD_v or fetchbufD_pc
`ifdef THREEWAY
 or fetchbufE_instr or fetchbufE_v or fetchbufE_pc
 or fetchbufF_instr or fetchbufF_v or fetchbufF_pc
`endif
)
begin
	fetchbuf0_instr <= (fetchbuf == 1'b0) ? fetchbufA_instr : fetchbufC_instr;
	fetchbuf0_v     <= (fetchbuf == 1'b0) ? fetchbufA_v     : fetchbufC_v    ;
	
	if (int_pending && string_pc!=64'd0)
		fetchbuf0_pc <= string_pc;
	else
	fetchbuf0_pc    <= (fetchbuf == 1'b0) ? fetchbufA_pc    : fetchbufC_pc   ;

	fetchbuf1_instr <= (fetchbuf == 1'b0) ? fetchbufB_instr : fetchbufD_instr;
	fetchbuf1_v     <= (fetchbuf == 1'b0) ? fetchbufB_v     : fetchbufD_v    ;

	if (int_pending && string_pc != 64'd0)
		fetchbuf1_pc <= string_pc;
	else
	fetchbuf1_pc    <= (fetchbuf == 1'b0) ? fetchbufB_pc    : fetchbufD_pc   ;
`ifdef THREEWAY
	fetchbuf2_instr <= (fetchbuf == 1'b0) ? fetchbufE_instr : fetchbufF_instr;
	fetchbuf2_v     <= (fetchbuf == 1'b0) ? fetchbufE_v     : fetchbufF_v    ;

	if (int_pending && string_pc != 64'd0)
		fetchbuf2_pc <= string_pc;
	else
	fetchbuf2_pc    <= (fetchbuf == 1'b0) ? fetchbufE_pc    : fetchbufF_pc   ;
`endif
end

wire [7:0] opcodeA = fetchbufA_instr[`OPCODE];
wire [7:0] opcodeB = fetchbufB_instr[`OPCODE];
wire [7:0] opcodeC = fetchbufC_instr[`OPCODE];
wire [7:0] opcodeD = fetchbufD_instr[`OPCODE];
`ifdef THREEWAY
wire [7:0] opcodeE = fetchbufE_instr[`OPCODE];
wire [7:0] opcodeF = fetchbufF_instr[`OPCODE];
`endif

function fnIsMem;
input [7:0] opcode;
fnIsMem = 	opcode==`LB || opcode==`LBU || opcode==`LC || opcode==`LCU || opcode==`LH || opcode==`LHU || opcode==`LW || 
			opcode==`LBX || opcode==`LWX || opcode==`LBUX || opcode==`LHX || opcode==`LHUX || opcode==`LCX || opcode==`LCUX ||
			opcode==`SB || opcode==`SC || opcode==`SH || opcode==`SW ||
			opcode==`SBX || opcode==`SCX || opcode==`SHX || opcode==`SWX ||
			opcode==`STS || opcode==`LCL ||
			opcode==`LVB || opcode==`LVC || opcode==`LVH || opcode==`LVW || opcode==`LVWAR || opcode==`SWCR ||
			opcode==`TLB || opcode==`CAS || opcode==`STMV || opcode==`STCMP || opcode==`STFND ||
			opcode==`LWS || opcode==`SWS || opcode==`STI ||
			opcode==`INC
			;
endfunction

function fnIsNdxd;
input [7:0] opcode;
fnIsNdxd = opcode==`LBX || opcode==`LWX || opcode==`LBUX || opcode==`LHX || opcode==`LHUX || opcode==`LCX || opcode==`LCUX ||
           opcode==`SBX || opcode==`SCX || opcode==`SHX || opcode==`SWX
           ;
endfunction

// Determines which instruction write to the register file
function fnIsRFW;
input [7:0] opcode;
input [63:0] ir;
begin
fnIsRFW =	// General registers
			opcode==`LB || opcode==`LBU || opcode==`LC || opcode==`LCU || opcode==`LH || opcode==`LHU || opcode==`LW ||
			opcode==`LBX || opcode==`LBUX || opcode==`LCX || opcode==`LCUX || opcode==`LHX || opcode==`LHUX || opcode==`LWX ||
			opcode==`LVB || opcode==`LVH || opcode==`LVC || opcode==`LVW || opcode==`LVWAR || opcode==`SWCR ||
			opcode==`RTS2 || opcode==`STP ||
			opcode==`CAS || opcode==`LWS || opcode==`STMV || opcode==`STCMP || opcode==`STFND ||
			opcode==`STS ||
			opcode==`ADDI || opcode==`SUBI || opcode==`ADDUI || opcode==`SUBUI || opcode==`MULI || opcode==`MULUI || opcode==`DIVI || opcode==`DIVUI ||
			opcode==`ANDI || opcode==`ORI || opcode==`EORI ||
			opcode==`ADD || opcode==`SUB || opcode==`ADDU || opcode==`SUBU || opcode==`MUL || opcode==`MULU || opcode==`DIV || opcode==`DIVU ||
			opcode==`AND || opcode==`OR || opcode==`EOR || opcode==`NAND || opcode==`NOR || opcode==`ENOR || opcode==`ANDC || opcode==`ORC ||
			opcode==`SHL || opcode==`SHLU || opcode==`SHR || opcode==`SHRU || opcode==`ROL || opcode==`ROR ||
			opcode==`SHLI || opcode==`SHLUI || opcode==`SHRI || opcode==`SHRUI || opcode==`ROLI || opcode==`RORI ||
			opcode==`R || opcode==`LEA ||
			opcode==`LDI || opcode==`LDIS || opcode==`ADDUIS || opcode==`MFSPR ||
			// Branch registers / Segment registers
			((opcode==`MTSPR || opcode==`MOVS) && (fnTargetsCa(ir) || fnTargetsSegreg(ir))) ||
			opcode==`JSR || opcode==`JSRS || opcode==`JSRZ || opcode==`SYS || opcode==`INT ||
			// predicate registers
			(opcode[7:4] < 4'h3) ||
			(opcode==`TLB && ir[19:16]==`TLB_RDREG) ||
			opcode==`BCD 
			;
end
endfunction

function fnIsStore;
input [7:0] opcode;
fnIsStore = 	opcode==`SB || opcode==`SC || opcode==`SH || opcode==`SW ||
				opcode==`SBX || opcode==`SCX || opcode==`SHX || opcode==`SWX ||
				opcode==`STS || opcode==`SWCR ||
				opcode==`SWS || opcode==`STI; 
endfunction

function fnIsLoad;
input [7:0] opcode;
fnIsLoad =	opcode==`LB || opcode==`LBU || opcode==`LC || opcode==`LCU || opcode==`LH || opcode==`LHU || opcode==`LW || 
			opcode==`LBX || opcode==`LBUX || opcode==`LCX || opcode==`LCUX || opcode==`LHX || opcode==`LHUX || opcode==`LWX ||
			opcode==`LVB || opcode==`LVC || opcode==`LVH || opcode==`LVW || opcode==`LVWAR || opcode==`LCL ||
			opcode==`LWS;
endfunction

function fnIsLoadV;
input [7:0] opcode;
fnIsLoadV = opcode==`LVB || opcode==`LVC || opcode==`LVH || opcode==`LVW || opcode==`LVWAR || opcode==`LCL;
endfunction

function fnIsIndexed;
input [7:0] opcode;
fnIsIndexed = opcode==`LBX || opcode==`LBUX || opcode==`LCX || opcode==`LCUX || opcode==`LHX || opcode==`LHUX || opcode==`LWX ||
				opcode==`SBX || opcode==`SCX || opcode==`SHX || opcode==`SWX;
endfunction

// *** check these
function fnIsPFW;
input [7:0] opcode;
fnIsPFW =	opcode[7:4]<4'h3 || opcode==`BITI;//opcode==`CMP || opcode==`CMPI || opcode==`TST;
endfunction

function [7:0] fnSelect;
input [7:0] opcode;
input [5:0] fn;
input [DBW-1:0] adr;
begin
if (DBW==32)
	case(opcode)
	`STS,`STMV,`STCMP,`STFND,`INC:
	   case(fn[2:0])
	   3'd0:
           case(adr[1:0])
           3'd0:    fnSelect = 8'h11;
           3'd1:    fnSelect = 8'h22;
           3'd2:    fnSelect = 8'h44;
           3'd3:    fnSelect = 8'h88;
           endcase
       3'd1:
		   case(adr[1])
           1'd0:    fnSelect = 8'h33;
           1'd1:    fnSelect = 8'hCC;
           endcase
       3'd2:
    		fnSelect = 8'hFF;
       default: fnSelect = 8'h00;
       endcase
	`LB,`LBU,`LBX,`LBUX,`SB,`SBX,`LVB:
		case(adr[1:0])
		3'd0:	fnSelect = 8'h11;
		3'd1:	fnSelect = 8'h22;
		3'd2:	fnSelect = 8'h44;
		3'd3:	fnSelect = 8'h88;
		endcase
	`LC,`LCU,`SC,`LVC,`LCX,`LCUX,`SCX:
		case(adr[1])
		1'd0:	fnSelect = 8'h33;
		1'd1:	fnSelect = 8'hCC;
		endcase
	`LH,`LHU,`SH,`LVH,`LHX,`LHUX,`SHX:
		fnSelect = 8'hFF;
	`LW,`LWX,`SW,`SWCR,`LVW,`LVWAR,`SWX,`CAS,`LWS,`SWS,`STI,`LCL:
		fnSelect = 8'hFF;
	default:	fnSelect = 8'h00;
	endcase
else
	case(opcode)
	`STS,`STMV,`STCMP,`STFND,`INC:
       case(fn[2:0])
       3'd0:
           case(adr[2:0])
           3'd0:    fnSelect = 8'h01;
           3'd1:    fnSelect = 8'h02;
           3'd2:    fnSelect = 8'h04;
           3'd3:    fnSelect = 8'h08;
           3'd4:    fnSelect = 8'h10;
           3'd5:    fnSelect = 8'h20;
           3'd6:    fnSelect = 8'h40;
           3'd7:    fnSelect = 8'h80;
           endcase
       3'd1:
           case(adr[2:1])
           2'd0:    fnSelect = 8'h03;
           2'd1:    fnSelect = 8'h0C;
           2'd2:    fnSelect = 8'h30;
           2'd3:    fnSelect = 8'hC0;
           endcase
       3'd2:
           case(adr[2])
           1'b0:    fnSelect = 8'h0F;
           1'b1:    fnSelect = 8'hF0;
           endcase
       3'd3:
           fnSelect = 8'hFF;
       default: fnSelect = 8'h00;
       endcase
	`LB,`LBU,`LBX,`SB,`LVB,`LBUX,`SBX:
		case(adr[2:0])
		3'd0:	fnSelect = 8'h01;
		3'd1:	fnSelect = 8'h02;
		3'd2:	fnSelect = 8'h04;
		3'd3:	fnSelect = 8'h08;
		3'd4:	fnSelect = 8'h10;
		3'd5:	fnSelect = 8'h20;
		3'd6:	fnSelect = 8'h40;
		3'd7:	fnSelect = 8'h80;
		endcase
	`LC,`LCU,`SC,`LVC,`LCX,`LCUX,`SCX:
		case(adr[2:1])
		2'd0:	fnSelect = 8'h03;
		2'd1:	fnSelect = 8'h0C;
		2'd2:	fnSelect = 8'h30;
		2'd3:	fnSelect = 8'hC0;
		endcase
	`LH,`LHU,`SH,`LVH,`LHX,`LHUX,`SHX:
		case(adr[2])
		1'b0:	fnSelect = 8'h0F;
		1'b1:	fnSelect = 8'hF0;
		endcase
	`LW,`LWX,`SW,`SWCR,`LVW,`LVWAR,`SWX,`CAS,`LWS,`SWS,`STI,`LCL:
		fnSelect = 8'hFF;
	default:	fnSelect = 8'h00;
	endcase
end
endfunction

function [DBW-1:0] fnDatai;
input [7:0] opcode;
input [5:0] func;
input [DBW-1:0] dat;
input [7:0] sel;
begin
if (DBW==32)
	case(opcode)
	`STMV,`STCMP,`STFND,`INC:
	   case(func[2:0])
	   3'd0,3'd4:
		case(sel[3:0])
        4'h1:    fnDatai = dat[7:0];
        4'h2:    fnDatai = dat[15:8];
        4'h4:    fnDatai = dat[23:16];
        4'h8:    fnDatai = dat[31:24];
        default:    fnDatai = {DBW{1'b1}};
        endcase
       3'd1,3'd5:
		case(sel[3:0])
        4'h3:    fnDatai = dat[15:0];
        4'hC:    fnDatai = dat[31:16];
        default:    fnDatai = {DBW{1'b1}};
        endcase
       default:    
		fnDatai = dat[31:0];
	   endcase
	`LB,`LBX,`LVB:
		case(sel[3:0])
		8'h1:	fnDatai = {{24{dat[7]}},dat[7:0]};
		8'h2:	fnDatai = {{24{dat[15]}},dat[15:8]};
		8'h4:	fnDatai = {{24{dat[23]}},dat[23:16]};
		8'h8:	fnDatai = {{24{dat[31]}},dat[31:24]};
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LBU,`LBUX:
		case(sel[3:0])
		4'h1:	fnDatai = dat[7:0];
		4'h2:	fnDatai = dat[15:8];
		4'h4:	fnDatai = dat[23:16];
		4'h8:	fnDatai = dat[31:24];
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LC,`LVC,`LCX:
		case(sel[3:0])
		4'h3:	fnDatai = {{16{dat[15]}},dat[15:0]};
		4'hC:	fnDatai = {{16{dat[31]}},dat[31:16]};
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LCU,`LCUX:
		case(sel[3:0])
		4'h3:	fnDatai = dat[15:0];
		4'hC:	fnDatai = dat[31:16];
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LH,`LHU,`LW,`LWX,`LVH,`LVW,`LVWAR,`LHX,`LHUX,`CAS,`LWS,`LCL:
		fnDatai = dat[31:0];
	default:	fnDatai = {DBW{1'b1}};
	endcase
else
	case(opcode)
	`STMV,`STCMP,`STFND,`INC:
	   case(func[2:0])
	   3'd0,3'd4:
		case(sel)
        8'h01:    fnDatai = dat[DBW*1/8-1:0];
        8'h02:    fnDatai = dat[DBW*2/8-1:DBW*1/8];
        8'h04:    fnDatai = dat[DBW*3/8-1:DBW*2/8];
        8'h08:    fnDatai = dat[DBW*4/8-1:DBW*3/8];
        8'h10:    fnDatai = dat[DBW*5/8-1:DBW*4/8];
        8'h20:    fnDatai = dat[DBW*6/8-1:DBW*5/8];
        8'h40:    fnDatai = dat[DBW*7/8-1:DBW*6/8];
        8'h80:    fnDatai = dat[DBW-1:DBW*7/8];
        default:    fnDatai = {DBW{1'b1}};
        endcase
       3'd1,3'd5:
		case(sel)
        8'h03:    fnDatai = dat[DBW/4-1:0];
        8'h0C:    fnDatai = dat[DBW/2-1:DBW/4];
        8'h30:    fnDatai = dat[DBW*3/4-1:DBW/2];
        8'hC0:    fnDatai = dat[DBW-1:DBW*3/4];
        default:    fnDatai = {DBW{1'b1}};
        endcase
       3'd2,3'd6:
		case(sel)
        8'h0F:    fnDatai = dat[DBW/2-1:0];
        8'hF0:    fnDatai = dat[DBW-1:DBW/2];
        default:    fnDatai = {DBW{1'b1}};
        endcase
       3'd3,3'd7:   fnDatai = dat;
	   endcase
	`LB,`LBX,`LVB:
		case(sel)
		8'h01:	fnDatai = {{DBW*7/8{dat[DBW*1/8-1]}},dat[DBW*1/8-1:0]};
		8'h02:	fnDatai = {{DBW*7/8{dat[DBW*2/8-1]}},dat[DBW*2/8-1:DBW*1/8]};
		8'h04:	fnDatai = {{DBW*7/8{dat[DBW*3/8-1]}},dat[DBW*3/8-1:DBW*2/8]};
		8'h08:	fnDatai = {{DBW*7/8{dat[DBW*4/8-1]}},dat[DBW*4/8-1:DBW*3/8]};
		8'h10:	fnDatai = {{DBW*7/8{dat[DBW*5/8-1]}},dat[DBW*5/8-1:DBW*4/8]};
		8'h20:	fnDatai = {{DBW*7/8{dat[DBW*6/8-1]}},dat[DBW*6/8-1:DBW*5/8]};
		8'h40:	fnDatai = {{DBW*7/8{dat[DBW*7/8-1]}},dat[DBW*7/8-1:DBW*6/8]};
		8'h80:	fnDatai = {{DBW*7/8{dat[DBW-1]}},dat[DBW-1:DBW*7/8]};
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LBU,`LBUX:
		case(sel)
		8'h01:	fnDatai = dat[DBW*1/8-1:0];
		8'h02:	fnDatai = dat[DBW*2/8-1:DBW*1/8];
		8'h04:	fnDatai = dat[DBW*3/8-1:DBW*2/8];
		8'h08:	fnDatai = dat[DBW*4/8-1:DBW*3/8];
		8'h10:	fnDatai = dat[DBW*5/8-1:DBW*4/8];
		8'h20:	fnDatai = dat[DBW*6/8-1:DBW*5/8];
		8'h40:	fnDatai = dat[DBW*7/8-1:DBW*6/8];
		8'h80:	fnDatai = dat[DBW-1:DBW*7/8];
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LC,`LVC,`LCX:
		case(sel)
		8'h03:	fnDatai = {{DBW*3/4{dat[DBW/4-1]}},dat[DBW/4-1:0]};
		8'h0C:	fnDatai = {{DBW*3/4{dat[DBW/2-1]}},dat[DBW/2-1:DBW/4]};
		8'h30:	fnDatai = {{DBW*3/4{dat[DBW*3/4-1]}},dat[DBW*3/4-1:DBW/2]};
		8'hC0:	fnDatai = {{DBW*3/4{dat[DBW-1]}},dat[DBW-1:DBW*3/4]};
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LCU,`LCUX:
		case(sel)
		8'h03:	fnDatai = dat[DBW/4-1:0];
		8'h0C:	fnDatai = dat[DBW/2-1:DBW/4];
		8'h30:	fnDatai = dat[DBW*3/4-1:DBW/2];
		8'hC0:	fnDatai = dat[DBW-1:DBW*3/4];
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LH,`LVH,`LHX:
		case(sel)
		8'h0F:	fnDatai = {{DBW/2{dat[DBW/2-1]}},dat[DBW/2-1:0]};
		8'hF0:	fnDatai = {{DBW/2{dat[DBW-1]}},dat[DBW-1:DBW/2]};
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LHU,`LHUX:
		case(sel)
		8'h0F:	fnDatai = dat[DBW/2-1:0];
		8'hF0:	fnDatai = dat[DBW-1:DBW/2];
		default:	fnDatai = {DBW{1'b1}};
		endcase
	`LW,`LWX,`LVW,`LVWAR,`CAS,`LWS,`LCL:
		case(sel)
		8'hFF:	fnDatai = dat;
		default:	fnDatai = {DBW{1'b1}};
		endcase
	default:	fnDatai = {DBW{1'b1}};
	endcase
end
endfunction

function [DBW-1:0] fnDatao;
input [7:0] opcode;
input [5:0] func;
input [DBW-1:0] dat;
if (DBW==32)
	case(opcode)
	`STMV,`INC:
	   case(func[2:0])
	   3'd0,3'd4:  fnDatao = {4{dat[7:0]}};
	   3'd1,3'd5:  fnDatao = {2{dat[15:8]}};
	   default:    fnDatao = dat;
	   endcase
	`SW,`SWCR,`SWX,`CAS,`SWS,`STI:	fnDatao = dat;
	`SH,`SHX:	fnDatao = dat;
	`SC,`SCX:	fnDatao = {2{dat[15:0]}};
	`SB,`SBX:	fnDatao = {4{dat[7:0]}};
	default:	fnDatao = dat;
	endcase
else
	case(opcode)
	`STMV,`INC:
	   case(func[2:0])
	   3'd0,3'd4:  fnDatao = {8{dat[DBW/8-1:0]}};
	   3'd1,3'd5:  fnDatao = {4{dat[DBW/4-1:0]}};
	   3'd2,3'd6:  fnDatao = {2{dat[DBW/2-1:0]}};
	   3'd3,3'd7:  fnDatao = dat;
	   endcase
	`SW,`SWCR,`SWX,`CAS,`SWS,`STI:	fnDatao = dat;
	`SH,`SHX:	fnDatao = {2{dat[DBW/2-1:0]}};
	`SC,`SCX:	fnDatao = {4{dat[DBW/4-1:0]}};
	`SB,`SBX:	fnDatao = {8{dat[DBW/8-1:0]}};
	default:	fnDatao = dat;
	endcase
endfunction

assign fetchbuf0_mem	= fetchbuf ? fnIsMem(opcodeC) : fnIsMem(opcodeA);
assign fetchbuf0_jmp   = fnIsFlowCtrl(opcode0);
assign fetchbuf0_fp		= fnIsFP(opcode0);
assign fetchbuf0_rfw	= fetchbuf ? fnIsRFW(opcodeC,fetchbufC_instr) : fnIsRFW(opcodeA,fetchbufA_instr);
assign fetchbuf0_pfw	= fetchbuf ? fnIsPFW(opcodeC) : fnIsPFW(opcodeA);
assign fetchbuf1_mem	= fetchbuf ? fnIsMem(opcodeD) : fnIsMem(opcodeB);
assign fetchbuf1_jmp   = fnIsFlowCtrl(opcode1);
assign fetchbuf1_fp		= fnIsFP(opcode1);
assign fetchbuf1_rfw	= fetchbuf ? fnIsRFW(opcodeD,fetchbufD_instr) : fnIsRFW(opcodeB,fetchbufB_instr);
assign fetchbuf1_pfw    = fetchbuf ? fnIsPFW(opcodeD) : fnIsPFW(opcodeB);
`ifdef THREEWAY
assign fetchbuf2_mem	= fetchbuf ? fnIsMem(opcodeF) : fnIsMem(opcodeE);
assign fetchbuf2_jmp    = fnIsFlowCtrl(opcode2);
assign fetchbuf2_fp		= fnIsFP(opcode2);
assign fetchbuf2_rfw	= fetchbuf ? fnIsRFW(opcodeF,fetchbufF_instr) : fnIsRFW(opcodeE,fetchbufE_instr);
assign fetchbuf2_pfw    = fetchbuf ? fnIsPFW(opcodeF) : fnIsPFW(opcodeE);
`endif

wire predict_taken0 = fetchbuf ? predict_takenC : predict_takenA;
wire predict_taken1 = fetchbuf ? predict_takenD : predict_takenB;
`ifdef THREEWAY
wire predict_taken2 = fetchbuf ? predict_takenF : predict_takenE;
`endif
//
// set branchback and backpc values ... ignore branches in fetchbuf slots not ready for enqueue yet
//
assign take_branch0 = ({fetchbuf0_v, fnIsBranch(opcode0), predict_taken0}  == {`VAL, `TRUE, `TRUE}) ||
                      ({fetchbuf0_v, opcode0==`LOOP}  == {`VAL, `TRUE})
                        ;
assign take_branch1 = ({fetchbuf1_v, fnIsBranch(opcode1), predict_taken1}  == {`VAL, `TRUE, `TRUE}) ||
                      ({fetchbuf1_v, opcode1==`LOOP}  == {`VAL, `TRUE})
                        ;
`ifdef THREEWAY
assign take_branch2 = ({fetchbuf2_v, fnIsBranch(opcode2), predict_taken2}  == {`VAL, `TRUE, `TRUE}) ||
                      ({fetchbuf2_v, opcode2==`LOOP}  == {`VAL, `TRUE})
                        ;
`endif                     
assign take_branch = take_branch0 || take_branch1
`ifdef THREEWAY
        || take_branch2
`endif
        ;

reg [DBW-1:0] branch_pc;// =
//		({fetchbuf0_v, fnIsBranch(opcode0), predict_taken0}  == {`VAL, `TRUE, `TRUE}) ? (ihit ?
//			fetchbuf0_pc + {{DBW-12{fetchbuf0_instr[11]}},fetchbuf0_instr[11:8],fetchbuf0_instr[23:16]} + 64'd3 : fetchbuf0_pc):
//			(ihit ? fetchbuf1_pc + {{DBW-12{fetchbuf1_instr[11]}},fetchbuf1_instr[11:8],fetchbuf1_instr[23:16]} + 64'd3 : fetchbuf1_pc);
always @*
if (fnIsBranch(opcode0) && fetchbuf0_v && predict_taken0) begin
    if (ihit)
        branch_pc <= fetchbuf0_pc + {{ABW-12{fetchbuf0_instr[11]}},fetchbuf0_instr[11:8],fetchbuf0_instr[23:16]} + 64'd3;
    else
        branch_pc <= fetchbuf0_pc;
end
else if (opcode0==`LOOP && fetchbuf0_v) begin
    if (ihit)
        branch_pc <= fetchbuf0_pc + {{ABW-8{fetchbuf0_instr[23]}},fetchbuf0_instr[23:16]} + 64'd3;
    else
        branch_pc <= fetchbuf0_pc;
end
else if (fnIsBranch(opcode1) && fetchbuf1_v && predict_taken1) begin
    if (ihit)
        branch_pc <= fetchbuf1_pc + {{ABW-12{fetchbuf1_instr[11]}},fetchbuf1_instr[11:8],fetchbuf1_instr[23:16]} + 64'd3;
    else
        branch_pc <= fetchbuf1_pc;
end
else if (opcode1==`LOOP && fetchbuf1_v) begin
    if (ihit)
        branch_pc <= fetchbuf1_pc + {{ABW-8{fetchbuf1_instr[23]}},fetchbuf1_instr[23:16]} + 64'd3;
    else
        branch_pc <= fetchbuf1_pc;
end
`ifdef THREEWAY
else if (fnIsBranch(opcode2) && fetchbuf2_v && predict_taken2) begin
    if (ihit)
        branch_pc <= fetchbuf2_pc + {{ABW-12{fetchbuf2_instr[11]}},fetchbuf2_instr[11:8],fetchbuf2_instr[23:16]} + 64'd3;
    else
        branch_pc <= fetchbuf2_pc;
end
else if (opcode2==`LOOP && fetchbuf2_v) begin
    if (ihit)
        branch_pc <= fetchbuf2_pc + {{ABW-8{fetchbuf2_instr[23]}},fetchbuf2_instr[23:16]} + 64'd3;
    else
        branch_pc <= fetchbuf2_pc;
end
`endif
else begin
    branch_pc <= {{ABW-8{1'b1}},8'h80};  // set to something to prevent a latch
end

assign int_pending = (nmi_edge & ~StatusHWI & ~int_commit) || (irq_i & ~im & ~StatusHWI & ~int_commit);

assign mem_stringmiss = ((dram0_op==`STS || dram0_op==`STFND) && int_pending && lc != 0) ||
                        ((dram0_op==`STMV || dram0_op==`STCMP) && int_pending && lc != 0 && stmv_flag);

// "Stream" interrupt instructions into the instruction stream until an INT
// instruction commits. This avoids the problem of an INT instruction being
// stomped on by a previous branch instruction.
// Populate the instruction buffers with INT instructions for a hardware interrupt
// Also populate the instruction buffers with a call to the instruction error vector
// if an error occurred during instruction load time.
// Translate the BRK opcode to a syscall.

// There is a one cycle delay in setting the StatusHWI that allowed an extra INT
// instruction to sneek into the queue. This is NOPped out by the int_commit
// signal.

// On a cache miss the instruction buffers are loaded with NOPs this prevents
// the PC from being trashed by invalid branch instructions.
reg [63:0] insn1a,insn2a;
reg [63:0] insn0,insn1,insn2;
always @*
//if (int_commit)
//	insn0 <= {8{8'h10}};	// load with NOPs
//else
if (nmi_edge & ~StatusHWI & ~int_commit)
	insn0 <= {8'hFE,8'hCE,8'hA6,8'h01,8'hFE,8'hCE,8'hA6,8'h01};
else if (ITLBMiss)
	insn0 <= {8'hF9,8'hCE,8'hA6,8'h01,8'hF9,8'hCE,8'hA6,8'h01};
else if (insnerr)
	insn0 <= {8'hFC,8'hCE,8'hA6,8'h01,8'hFC,8'hCE,8'hA6,8'h01};
else if (irq_i & ~im & ~StatusHWI & ~int_commit)
	insn0 <= {vec_i,8'hCE,8'hA6,8'h01,vec_i,8'hCE,8'hA6,8'h01};
else if (ihit) begin
	if (insn[7:0]==8'h00)
		insn0 <= {8'h00,8'hCD,8'hA5,8'h01,8'h00,8'hCD,8'hA5,8'h01};
	else
        insn0 <= insn[63:0];
end
else
	insn0 <= {8{8'h10}};	// load with NOPs


always @*
//if (int_commit)
//	insn1 <= {8{8'h10}};	// load with NOPs
//else
if (nmi_edge & ~StatusHWI & ~int_commit)
	insn1 <= {8'hFE,8'hCE,8'hA6,8'h01,8'hFE,8'hCE,8'hA6,8'h01};
else if (ITLBMiss)
	insn1 <= {8'hF9,8'hCE,8'hA6,8'h01,8'hF9,8'hCE,8'hA6,8'h01};
else if (insnerr)
	insn1 <= {8'hFC,8'hCE,8'hA6,8'h01,8'hFC,8'hCE,8'hA6,8'h01};
else if (irq_i & ~im & ~StatusHWI & ~int_commit)
	insn1 <= {vec_i,8'hCE,8'hA6,8'h01,vec_i,8'hCE,8'hA6,8'h01};
else if (ihit) begin
	if (insn1a[7:0]==8'h00)
		insn1 <= {8'h00,8'hCD,8'hA5,8'h01,8'h00,8'hCD,8'hA5,8'h01};
	else
		insn1 <= insn1a;
end
else
	insn1 <= {8{8'h10}};	// load with NOPs


`ifdef THREEWAY
always @*
//if (int_commit)
//	insn1 <= {8{8'h10}};	// load with NOPs
//else
if (nmi_edge & ~StatusHWI & ~int_commit)
	insn2 <= {8'hFE,8'hCE,8'hA6,8'h01,8'hFE,8'hCE,8'hA6,8'h01};
else if (ITLBMiss)
	insn2 <= {8'hF9,8'hCE,8'hA6,8'h01,8'hF9,8'hCE,8'hA6,8'h01};
else if (insnerr)
	insn2 <= {8'hFC,8'hCE,8'hA6,8'h01,8'hFC,8'hCE,8'hA6,8'h01};
else if (irq_i & ~im & ~StatusHWI & ~int_commit)
	insn2 <= {vec_i,8'hCE,8'hA6,8'h01,vec_i,8'hCE,8'hA6,8'h01};
else if (ihit) begin
	if (insn2a[7:0]==8'h00)
		insn2 <= {8'h00,8'hCD,8'hA5,8'h01,8'h00,8'hCD,8'hA5,8'h01};
	else
		insn2 <= insn2a;
end
else
	insn2 <= {8{8'h10}};	// load with NOPs
`endif

// Find the second instruction in the instruction line.
always @(insn)
	case(fnInsnLength(insn))
	4'd1:	insn1a <= insn[71: 8];
	4'd2:	insn1a <= insn[79:16];
	4'd3:	insn1a <= insn[87:24];
	4'd4:	insn1a <= insn[95:32];
	4'd5:	insn1a <= insn[103:40];
	4'd6:	insn1a <= insn[111:48];
	4'd7:	insn1a <= insn[119:56];
	4'd8:	insn1a <= insn[127:64];
	default:	insn1a <= {8{8'h10}};	// NOPs
	endcase

`ifdef THREEWAY
// Find the third instruction in the instruction line.
always @(insn)
	case(fnInsnLength(insn)+fnInsnLength1(insn))
	4'd2:	insn2a <= insn[79:16];
	4'd3:	insn2a <= insn[87:24];
	4'd4:	insn2a <= insn[95:32];
	4'd5:	insn2a <= insn[103:40];
	4'd6:	insn2a <= insn[111:48];
	4'd7:	insn2a <= insn[119:56];
	4'd8:	insn2a <= insn[127:64];
	4'd9:	insn2a <= insn[127:72];
	4'd10:	insn2a <= insn[127:80];
	4'd11:	insn2a <= insn[127:88];
	4'd12:	insn2a <= insn[127:96];
	4'd13:	insn2a <= insn[127:104];
	4'd14:	insn2a <= insn[127:112];
	4'd15:	insn2a <= insn[127:120];
	default:	insn2a <= {8{8'h10}};	// NOPs
	endcase
`endif

// Return the immediate field of an instruction
function [63:0] fnImm;
input [127:0] insn;
casex(insn[15:0])
16'bxxxxxxxx00010001:   // RTS short form
    fnImm = 64'd0;
default:
casex(insn[15:8])
`CAS:	fnImm = {{56{insn[47]}},insn[47:40]};
`BCD:	fnImm = insn[47:40];
`TLB:	fnImm = insn[23:16];
`LOOP:	fnImm = {{56{insn[23]}},insn[23:16]};
`STP:   fnImm = insn[31:16];
`JSR:	fnImm = {{40{insn[47]}},insn[47:24]};
`JSRS:  fnImm = {{48{insn[39]}},insn[39:24]};
`BITFIELD:	fnImm = insn[47:32];
`SYS,`INT:	fnImm = insn[31:24];
`RTS2:  fnImm = {insn[31:27],3'b000};
`CMPI,`LDI,`LDIS,`ADDUIS:
	fnImm = {{54{insn[31]}},insn[31:22]};
`RTS:	fnImm = insn[19:16];
`RTE,`RTI,`JSRZ,`STMV,`STCMP,`STFND,`CACHE,`STS:	fnImm = 8'h00;
`STI:	fnImm = {{58{insn[33]}},insn[33:28]};
`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`LVB,`LVC,`LVH,`LVW,`LVWAR,
`SB,`SC,`SH,`SW,`SWCR,`LWS,`SWS,`INC,`LCL:
	fnImm = {{55{insn[36]}},insn[36:28]};
default:
	fnImm = {{52{insn[39]}},insn[39:28]};
endcase
endcase

endfunction

function [7:0] fnImm8;
input [127:0] insn;
if (insn[7:0]==8'h11)
    fnImm8 = 8'h00;
else
casex(insn[15:8])
`CAS:	fnImm8 = insn[47:40];
`BCD:	fnImm8 = insn[47:40];
`TLB:	fnImm8 = insn[23:16];
`LOOP:	fnImm8 = insn[23:16];
`STP:   fnImm8 = insn[23:16];
`JSR,`JSRS,`RTS2:	fnImm8 = insn[31:24];
`BITFIELD:	fnImm8 = insn[39:32];
`SYS,`INT:	fnImm8 = insn[31:24];
`CMPI,`LDI,`LDIS,`ADDUIS:	fnImm8 = insn[29:22];
`RTS:	fnImm8 = insn[19:16];
`RTE,`RTI,`JSRZ,`STMV,`STCMP,`STFND,`CACHE,`STS:	fnImm8 = 8'h00;
`STI:	fnImm8 = insn[39:28];
`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`LVB,`LVC,`LVH,`LVW,`LVWAR,
`SB,`SC,`SH,`SW,`SWCR,`LWS,`SWS,`INC,`LCL:
	fnImm8 = insn[35:28];
default:	fnImm8 = insn[35:28];
endcase
endfunction

// Return MSB of immediate value for instruction
function fnImmMSB;
input [127:0] insn;
if (insn[7:0]==8'h11)
    fnImmMSB = 1'b0;
else
casex(insn[15:8])
`CAS:	fnImmMSB = insn[47];
`TLB,`BCD,`STP:
	fnImmMSB = 1'b0;		// TLB regno is unsigned
`LOOP:
	fnImmMSB = insn[23];
`JSR:
	fnImmMSB = insn[47];
`JSRS:
    fnImmMSB = insn[39];
`CMPI,`LDI,`LDIS,`ADDUIS:
	fnImmMSB = insn[31];
`SYS,`INT,`CACHE:
	fnImmMSB = 1'b0;		// SYS,INT are unsigned
`RTS,`RTE,`RTI,`JSRZ,`STMV,`STCMP,`STFND,`RTS2,`STS:
	fnImmMSB = 1'b0;		// RTS is unsigned
`LBX,`LBUX,`LCX,`LCUX,`LHX,`LHUX,`LWX,
`SBX,`SCX,`SHX,`SWX:
	fnImmMSB = insn[47];
`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`LVB,`LVC,`LVH,`LVW,
`SB,`SC,`SH,`SW,`SWCR,`STI,`LWS,`SWS,`INC,`LCL:
	fnImmMSB = insn[36];
default:
	fnImmMSB = insn[39];
endcase

endfunction

function [63:0] fnImmImm;
input [63:0] insn;
case(insn[7:4])
4'd2:	fnImmImm = {{48{insn[15]}},insn[15:8],8'h00};
4'd3:	fnImmImm = {{40{insn[23]}},insn[23:8],8'h00};
4'd4:	fnImmImm = {{32{insn[31]}},insn[31:8],8'h00};
4'd5:	fnImmImm = {{24{insn[39]}},insn[39:8],8'h00};
4'd6:	fnImmImm = {{16{insn[47]}},insn[47:8],8'h00};
4'd7:	fnImmImm = {{ 8{insn[55]}},insn[55:8],8'h00};
4'd8:	fnImmImm = {insn[63:8],8'h00};
default:	fnImmImm = 64'd0;
endcase
endfunction

function [63:0] fnOpa;
input [7:0] opcode;
input [63:0] ins;
input [63:0] rfo;
input [63:0] epc;
begin
    if (opcode==`RTS) begin
        fnOpa = (commit1_v && commit1_tgt[6:0]==7'h51) ? commit1_bus :
                (commit0_v && commit0_tgt[6:0]==7'h51) ? commit0_bus :
                cregs[3'd1]; 
    end
	else if (opcode==`LOOP)
		fnOpa = epc;
	else if (fnIsFlowCtrl(opcode))
		fnOpa = fnCar(ins)==4'd0 ? 64'd0 : fnCar(ins)==4'd15 ? epc :
			(commit1_v && commit1_tgt[6:4]==3'h5 && commit1_tgt[3:0]==fnCar(ins)) ? commit1_bus :
			(commit0_v && commit0_tgt[6:4]==3'h5 && commit0_tgt[3:0]==fnCar(ins)) ? commit0_bus :
			cregs[fnCar(ins)];
	else if (opcode==`MFSPR || opcode==`SWS || opcode==`MOVS)
	    fnOpa = fnSpr(ins[`INSTRUCTION_RA],epc);
/*
		casex(ins[21:16])
		`TICK:	fnOpa = tick;
		`LCTR:	fnOpa = lc;
		`PREGS_ALL:
				begin
					fnOpa[3:0] = pregs[0];
					fnOpa[7:4] = pregs[1];
					fnOpa[11:8] = pregs[2];
					fnOpa[15:12] = pregs[3];
					fnOpa[19:16] = pregs[4];
					fnOpa[23:20] = pregs[5];
					fnOpa[27:24] = pregs[6];
					fnOpa[31:28] = pregs[7];
					fnOpa[35:32] = pregs[8];
					fnOpa[39:36] = pregs[9];
					fnOpa[43:40] = pregs[10];
					fnOpa[47:44] = pregs[11];
					fnOpa[51:48] = pregs[12];
					fnOpa[55:52] = pregs[13];
					fnOpa[59:56] = pregs[14];
					fnOpa[63:60] = pregs[15];
				end
		`ASID:	fnOpa = asid;
		`SR:	fnOpa = sr;
		6'h1x:	fnOpa = ins[19:16]==4'h0 ? 64'd0 : ins[19:16]==4'hF ? epc :
						(commit0_v && commit0_tgt[6:4]==3'h5 && commit0_tgt[3:0]==ins[19:16]) ? commit0_bus :
						cregs[ins[19:16]];
`ifdef SEGMENTATION
		6'h2x:	fnOpa = 
			(commit0_v && commit0_tgt[6:4]==3'h6 && commit0_tgt[3:0]==ins[18:16]) ? {commit0_bus[DBW-1:12],12'h000} :
			{sregs[ins[18:16]],12'h000};
`endif
		default:	fnOpa = 64'h0;
		endcase
*/
	else
		fnOpa = rfo;
end
endfunction

function [15:0] fnRegstrGrp;
input [6:0] Rn;
if (!Rn[6]) begin
	fnRegstrGrp="GP";
end
else
	case(Rn[5:4])
	2'h0:	fnRegstrGrp="PR";
	2'h1:	fnRegstrGrp="CA";
	2'h2:	fnRegstrGrp="SG";
	2'h3:
	       case(Rn[3:0])
	       3'h0:   fnRegstrGrp="PA";
	       3'h3:   fnRegstrGrp="LC";
	       endcase
	endcase

endfunction

function [7:0] fnRegstr;
input [6:0] Rn;
begin
if (!Rn[6]) begin
	fnRegstr = Rn[5:0];
end
else
	fnRegstr = Rn[3:0];
end
endfunction

initial begin
	//
	// set up panic messages
	message[ `PANIC_NONE ]			= "NONE            ";
	message[ `PANIC_FETCHBUFBEQ ]		= "FETCHBUFBEQ     ";
	message[ `PANIC_INVALIDISLOT ]		= "INVALIDISLOT    ";
	message[ `PANIC_IDENTICALDRAMS ]	= "IDENTICALDRAMS  ";
	message[ `PANIC_OVERRUN ]		= "OVERRUN         ";
	message[ `PANIC_HALTINSTRUCTION ]	= "HALTINSTRUCTION ";
	message[ `PANIC_INVALIDMEMOP ]		= "INVALIDMEMOP    ";
	message[ `PANIC_INVALIDFBSTATE ]	= "INVALIDFBSTATE  ";
	message[ `PANIC_INVALIDIQSTATE ]	= "INVALIDIQSTATE  ";
	message[ `PANIC_BRANCHBACK ]		= "BRANCHBACK      ";
	message[ `PANIC_MEMORYRACE ]		= "MEMORYRACE      ";
end

//`include "Thor_issue_combo.v"
/*
assign  iqentry_imm[0] = fnHasConst(iqentry_op[0]),
	iqentry_imm[1] = fnHasConst(iqentry_op[1]),
	iqentry_imm[2] = fnHasConst(iqentry_op[2]),
	iqentry_imm[3] = fnHasConst(iqentry_op[3]),
	iqentry_imm[4] = fnHasConst(iqentry_op[4]),
	iqentry_imm[5] = fnHasConst(iqentry_op[5]),
	iqentry_imm[6] = fnHasConst(iqentry_op[6]),
	iqentry_imm[7] = fnHasConst(iqentry_op[7]);
*/
//
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

always @(n)
for (n = 0; n < QENTRIES; n = n + 1)
    iq_cmt[n] <= fnPredicate(iqentry_pred[n], iqentry_cond[n]) ||
        (iqentry_cond[n] < 4'h2 && ({iqentry_pred[n],iqentry_cond[n]}!=8'h90));

wire [QENTRIES-1:0] args_valid;
wire [QENTRIES-1:0] could_issue;

genvar g;
generate
begin : argsv

for (g = 0; g < QENTRIES; g = g + 1)
begin
assign  iqentry_imm[g] = fnHasConst(iqentry_op[g]);

assign args_valid[g] =
			(iqentry_p_v[g]
				|| (iqentry_p_s[g]==alu0_sourceid && alu0_v)
				|| (iqentry_p_s[g]==alu1_sourceid && alu1_v))
			&& (iqentry_a1_v[g] 
//				|| (iqentry_mem[g] && !iqentry_agen[g] && iqentry_op[g]!=`TLB)
				|| (iqentry_a1_s[g] == alu0_sourceid && alu0_v)
				|| (iqentry_a1_s[g] == alu1_sourceid && alu1_v))
			&& (iqentry_a2_v[g] 
				|| (iqentry_a2_s[g] == alu0_sourceid && alu0_v)
				|| (iqentry_a2_s[g] == alu1_sourceid && alu1_v))
			&& (iqentry_a3_v[g] 
				|| (iqentry_a3_s[g] == alu0_sourceid && alu0_v)
				|| (iqentry_a3_s[g] == alu1_sourceid && alu1_v));

assign could_issue[g] = iqentry_v[g] && !iqentry_done[g] && !iqentry_out[g] && args_valid[g] &&
                         (iqentry_mem[g] ? !iqentry_agen[g] : 1'b1) && iq_cmt[g];

end
end
endgenerate

// The (old) simulator didn't handle the asynchronous race loop properly in the 
// original code. It would issue two instructions to the same islot. So the
// issue logic has been re-written to eliminate the asynchronous loop.
always @*//(could_issue or head0 or head1 or head2 or head3 or head4 or head5 or head6 or head7)
begin
	iqentry_issue = 8'h00;
	iqentry_islot[0] = 2'b00;
	iqentry_islot[1] = 2'b00;
	iqentry_islot[2] = 2'b00;
	iqentry_islot[3] = 2'b00;
	iqentry_islot[4] = 2'b00;
	iqentry_islot[5] = 2'b00;
	iqentry_islot[6] = 2'b00;
	iqentry_islot[7] = 2'b00;
	if (could_issue[head0] & !iqentry_fp[head0]) begin
		iqentry_issue[head0] = `TRUE;
		iqentry_islot[head0] = 2'b00;
	end
	else if (could_issue[head1] & !iqentry_fp[head1]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC))
	begin
		iqentry_issue[head1] = `TRUE;
		iqentry_islot[head1] = 2'b00;
	end
	else if (could_issue[head2] & !iqentry_fp[head2]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	)
	begin
		iqentry_issue[head2] = `TRUE;
		iqentry_islot[head2] = 2'b00;
	end
	else if (could_issue[head3] & !iqentry_fp[head3]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	) begin
		iqentry_issue[head3] = `TRUE;
		iqentry_islot[head3] = 2'b00;
	end
	else if (could_issue[head4] & !iqentry_fp[head4]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	) begin
		iqentry_issue[head4] = `TRUE;
		iqentry_islot[head4] = 2'b00;
	end
	else if (could_issue[head5] & !iqentry_fp[head5]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	) begin
		iqentry_issue[head5] = `TRUE;
		iqentry_islot[head5] = 2'b00;
	end
	else if (could_issue[head6] & !iqentry_fp[head6]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	&& !(iqentry_v[head5] && iqentry_op[head5]==`SYNC)
	) begin
		iqentry_issue[head6] = `TRUE;
		iqentry_islot[head6] = 2'b00;
	end
	else if (could_issue[head7] & !iqentry_fp[head7]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	&& !(iqentry_v[head5] && iqentry_op[head5]==`SYNC)
	&& !(iqentry_v[head6] && iqentry_op[head6]==`SYNC)
	) begin
		iqentry_issue[head7] = `TRUE;
		iqentry_islot[head7] = 2'b00;
	end

    // Don't bother checking head0, it should have issued to the first
    // instruction.
	if (could_issue[head1] && !iqentry_fp[head1] && !iqentry_issue[head1]
	&& !fnIsAlu0Op(iqentry_op[head1],iqentry_fn[head1])
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC))
	begin
		iqentry_issue[head1] = `TRUE;
		iqentry_islot[head1] = 2'b01;
	end
	else if (could_issue[head2] && !iqentry_fp[head2] && !iqentry_issue[head2]
	&& !fnIsAlu0Op(iqentry_op[head2],iqentry_fn[head2])
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	)
	begin
		iqentry_issue[head2] = `TRUE;
		iqentry_islot[head2] = 2'b01;
	end
	else if (could_issue[head3] & !iqentry_fp[head3] && !iqentry_issue[head3]
	&& !fnIsAlu0Op(iqentry_op[head3],iqentry_fn[head3])
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	) begin
		iqentry_issue[head3] = `TRUE;
		iqentry_islot[head3] = 2'b01;
	end
	else if (could_issue[head4] & !iqentry_fp[head4] && !iqentry_issue[head4]
	&& !fnIsAlu0Op(iqentry_op[head4],iqentry_fn[head4])
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	) begin
		iqentry_issue[head4] = `TRUE;
		iqentry_islot[head4] = 2'b01;
	end
	else if (could_issue[head5] & !iqentry_fp[head5] && !iqentry_issue[head5]
	&& !fnIsAlu0Op(iqentry_op[head5],iqentry_fn[head5])
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	) begin
		iqentry_issue[head5] = `TRUE;
		iqentry_islot[head5] = 2'b01;
	end
	else if (could_issue[head6] & !iqentry_fp[head6] && !iqentry_issue[head6]
	&& !fnIsAlu0Op(iqentry_op[head6],iqentry_fn[head6])
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	&& !(iqentry_v[head5] && iqentry_op[head5]==`SYNC)
	) begin
		iqentry_issue[head6] = `TRUE;
		iqentry_islot[head6] = 2'b01;
	end
	else if (could_issue[head7] & !iqentry_fp[head7] && !iqentry_issue[head7]
	&& !fnIsAlu0Op(iqentry_op[head7],iqentry_fn[head7])
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	&& !(iqentry_v[head5] && iqentry_op[head5]==`SYNC)
	&& !(iqentry_v[head6] && iqentry_op[head6]==`SYNC)
	) begin
		iqentry_issue[head7] = `TRUE;
		iqentry_islot[head7] = 2'b01;
	end
end


`ifdef FLOATING_POINT
reg [3:0] fpispot;
always @(could_issue or head0 or head1 or head2 or head3 or head4 or head5 or head6 or head7)
begin
	iqentry_fpissue = 8'h00;
	iqentry_fpislot[0] = 2'b00;
	iqentry_fpislot[1] = 2'b00;
	iqentry_fpislot[2] = 2'b00;
	iqentry_fpislot[3] = 2'b00;
	iqentry_fpislot[4] = 2'b00;
	iqentry_fpislot[5] = 2'b00;
	iqentry_fpislot[6] = 2'b00;
	iqentry_fpislot[7] = 2'b00;
	fpispot = head0;
	if (could_issue[head0] & iqentry_fp[head0]) begin
		iqentry_fpissue[head0] = `TRUE;
		iqentry_fpislot[head0] = 2'b00;
		fpispot = head0;
	end
	else if (could_issue[head1] & iqentry_fp[head1]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC))
	begin
		iqentry_fpissue[head1] = `TRUE;
		iqentry_fpislot[head1] = 2'b00;
		fpispot = head1;
	end
	else if (could_issue[head2] & iqentry_fp[head2]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	)
	begin
		iqentry_fpissue[head2] = `TRUE;
		iqentry_fpislot[head2] = 2'b00;
		fpispot = head2;
	end
	else if (could_issue[head3] & iqentry_fp[head3]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	) begin
		iqentry_fpissue[head3] = `TRUE;
		iqentry_fpislot[head3] = 2'b00;
		fpispot = head3;
	end
	else if (could_issue[head4] & iqentry_fp[head4]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	) begin
		iqentry_fpissue[head4] = `TRUE;
		iqentry_fpislot[head4] = 2'b00;
		fpispot = head4;
	end
	else if (could_issue[head5] & iqentry_fp[head5]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	) begin
		iqentry_fpissue[head5] = `TRUE;
		iqentry_fpislot[head5] = 2'b00;
		fpispot = head5;
	end
	else if (could_issue[head6] & iqentry_fp[head6]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	&& !(iqentry_v[head5] && iqentry_op[head5]==`SYNC)
	) begin
		iqentry_fpissue[head6] = `TRUE;
		iqentry_fpislot[head6] = 2'b00;
		fpispot = head6;
	end
	else if (could_issue[head7] & iqentry_fp[head7]
	&& !(iqentry_v[head0] && iqentry_op[head0]==`SYNC)
	&& !(iqentry_v[head1] && iqentry_op[head1]==`SYNC)
	&& !(iqentry_v[head2] && iqentry_op[head2]==`SYNC)
	&& !(iqentry_v[head3] && iqentry_op[head3]==`SYNC)
	&& !(iqentry_v[head4] && iqentry_op[head4]==`SYNC)
	&& !(iqentry_v[head5] && iqentry_op[head5]==`SYNC)
	&& !(iqentry_v[head6] && iqentry_op[head6]==`SYNC)
	) begin
		iqentry_fpissue[head7] = `TRUE;
		iqentry_fpislot[head7] = 2'b00;
		fpispot = head7;
	end
	else
		fpispot = 4'd8;

end
`endif

assign stomp_all = `FALSE;//fnIsStoreString(iqentry_op[head0]) && int_pending;
reg [7:0] stomp_mask;
reg [DBW-1:0] cmt_miss_pc;
// 
// additional logic for handling a branch miss (STOMP logic)
//
always @*     
begin
    cmt_miss = `FALSE;
    cmt_miss_id = 3'd0;
    stomp_mask = 8'hFF;
    // If not committing
    if (!iqentry_cmt[head0]) begin
        // And the next instruction depends on the commit
        if (iqentry_v[head1] && (iqentry_a1_s[head1][2:0]==head0 ||
            iqentry_a2_s[head1][2:0]==head0 || iqentry_a3_s[head1]==head0 || iqentry_p_s[head1]==head0)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head1;
            cmt_miss_pc = iqentry_pc[head1];
            stomp_mask[head1] = 1'b0;
            stomp_mask[head2] = 1'b0;
            stomp_mask[head3] = 1'b0;
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        // Or the following instruction
        else if (iqentry_v[head2] && (iqentry_a1_s[head2][2:0]==head0 ||
            iqentry_a2_s[head2][2:0]==head0 || iqentry_a3_s[head2]==head0 || iqentry_p_s[head2]==head0)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head2;
            cmt_miss_pc = iqentry_pc[head2];
            stomp_mask[head2] = 1'b0;
            stomp_mask[head3] = 1'b0;
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head3] && (iqentry_a1_s[head3][2:0]==head0 ||
            iqentry_a2_s[head3][2:0]==head0 || iqentry_a3_s[head3]==head0 || iqentry_p_s[head3]==head0)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head3;
            cmt_miss_pc = iqentry_pc[head3];
            stomp_mask[head3] = 1'b0;
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head4] && (iqentry_a1_s[head4][2:0]==head0 || 
        iqentry_a2_s[head4][2:0]==head0 || iqentry_a3_s[head4]==head0 || iqentry_p_s[head4]==head0)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head4;
            cmt_miss_pc = iqentry_pc[head4];
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head5] && (iqentry_a1_s[head5][2:0]==head0 ||
            iqentry_a2_s[head5][2:0]==head0 || iqentry_a3_s[head5]==head0 || iqentry_p_s[head5]==head0)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head5;
            cmt_miss_pc = iqentry_pc[head5];
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head6] && (iqentry_a1_s[head6][2:0]==head0 ||
         iqentry_a2_s[head6][2:0]==head0 || iqentry_a3_s[head6]==head0 || iqentry_p_s[head6]==head0)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head6;
            cmt_miss_pc = iqentry_pc[head6];
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head7] && (iqentry_a1_s[head7][2:0]==head0 ||
        iqentry_a2_s[head7][2:0]==head0 || iqentry_a3_s[head7]==head0 || iqentry_p_s[head7]==head0)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head7;
            cmt_miss_pc = iqentry_pc[head7];
            stomp_mask[head7] = 1'b0; 
        end
    end
    else if (!iqentry_cmt[head1]) begin
        if (iqentry_v[head2] && (iqentry_a1_s[head2][2:0]==head1 || 
        iqentry_a2_s[head2][2:0]==head1 || iqentry_a3_s[head2]==head1 || iqentry_p_s[head2]==head1)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head2;
            cmt_miss_pc = iqentry_pc[head2];
            stomp_mask[head2] = 1'b0;
            stomp_mask[head3] = 1'b0;
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head3] && (iqentry_a1_s[head3][2:0]==head1 ||
        iqentry_a2_s[head3][2:0]==head1 || iqentry_a3_s[head3]==head1 || iqentry_p_s[head3]==head1)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head3;
            cmt_miss_pc = iqentry_pc[head3];
            stomp_mask[head3] = 1'b0;
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head4] && (iqentry_a1_s[head4][2:0]==head1 || 
        iqentry_a2_s[head4][2:0]==head1 || iqentry_a3_s[head4]==head1 || iqentry_p_s[head4]==head1)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head4;
            cmt_miss_pc = iqentry_pc[head4];
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head5] && (iqentry_a1_s[head5][2:0]==head1 || 
        iqentry_a2_s[head5][2:0]==head1 || iqentry_a3_s[head5]==head1 || iqentry_p_s[head5]==head1)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head5;
            cmt_miss_pc = iqentry_pc[head5];
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head6] && (iqentry_a1_s[head6][2:0]==head1 ||
        iqentry_a2_s[head6][2:0]==head1 || iqentry_a3_s[head6]==head1 || iqentry_p_s[head6]==head1)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head6;
            cmt_miss_pc = iqentry_pc[head6];
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head7] && (iqentry_a1_s[head7][2:0]==head1 ||
        iqentry_a2_s[head7][2:0]==head1 || iqentry_a3_s[head7]==head1 || iqentry_p_s[head7]==head1)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head7;
            cmt_miss_pc = iqentry_pc[head7];
            stomp_mask[head7] = 1'b0; 
        end
    end
    else if (!iqentry_cmt[head2]) begin
        if (iqentry_v[head3] && (iqentry_a1_s[head3][2:0]==head2 ||
        iqentry_a2_s[head3][2:0]==head2 || iqentry_a3_s[head3]==head2 || iqentry_p_s[head3]==head2)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head3;
            cmt_miss_pc = iqentry_pc[head3];
            stomp_mask[head3] = 1'b0;
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head4] && (iqentry_a1_s[head4][2:0]==head2 ||
        iqentry_a2_s[head4][2:0]==head2 || iqentry_a3_s[head4]==head2 || iqentry_p_s[head4]==head2)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head4;
            cmt_miss_pc = iqentry_pc[head4];
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head5] && (iqentry_a1_s[head5][2:0]==head2 ||
        iqentry_a2_s[head5][2:0]==head2 || iqentry_a3_s[head5]==head2 || iqentry_p_s[head5]==head2)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head5;
            cmt_miss_pc = iqentry_pc[head5];
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head6] && (iqentry_a1_s[head6][2:0]==head2 || 
        iqentry_a2_s[head6][2:0]==head2 || iqentry_a3_s[head6]==head2 || iqentry_p_s[head6]==head2)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head6;
            cmt_miss_pc = iqentry_pc[head6];
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head7] && (iqentry_a1_s[head7][2:0]==head2 ||
        iqentry_a2_s[head7][2:0]==head2 || iqentry_a3_s[head7]==head2 || iqentry_p_s[head7]==head2)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head7;
            cmt_miss_pc = iqentry_pc[head7];
            stomp_mask[head7] = 1'b0; 
        end
    end
    else if (!iqentry_cmt[head3]) begin
        if (iqentry_v[head4] && (iqentry_a1_s[head4][2:0]==head3 || 
        iqentry_a2_s[head4][2:0]==head3 || iqentry_a3_s[head4]==head3 || iqentry_p_s[head4]==head3)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head4;
            cmt_miss_pc = iqentry_pc[head4];
            stomp_mask[head4] = 1'b0;
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head5] && (iqentry_a1_s[head5][2:0]==head3 ||
        iqentry_a2_s[head5][2:0]==head3 || iqentry_a3_s[head5]==head3 || iqentry_p_s[head5]==head3)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head5;
            cmt_miss_pc = iqentry_pc[head5];
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head6] && (iqentry_a1_s[head6][2:0]==head3 ||
        iqentry_a2_s[head6][2:0]==head3 || iqentry_a3_s[head6]==head3 || iqentry_p_s[head6]==head3)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head6;
            cmt_miss_pc = iqentry_pc[head6];
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head7] && (iqentry_a1_s[head7][2:0]==head3 || 
        iqentry_a2_s[head7][2:0]==head3 || iqentry_a3_s[head7]==head3 || iqentry_p_s[head7]==head3)) begin
            cmt_miss = `TRUE;
            cmt_miss_pc = iqentry_pc[head7];
            cmt_miss_id = head7;
            stomp_mask[head7] = 1'b0; 
        end
    end
    else if (!iqentry_cmt[head4]) begin
        if (iqentry_v[head5] && (iqentry_a1_s[head5][2:0]==head4 || 
        iqentry_a2_s[head5][2:0]==head4 || iqentry_a3_s[head5]==head4 || iqentry_p_s[head5]==head4)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head5;
            cmt_miss_pc = iqentry_pc[head5];
            stomp_mask[head5] = 1'b0;
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head6] && (iqentry_a1_s[head6][2:0]==head4 ||
        iqentry_a2_s[head6][2:0]==head4 || iqentry_a3_s[head6]==head4 || iqentry_p_s[head6]==head4)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head6;
            cmt_miss_pc = iqentry_pc[head6];
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head7] && (iqentry_a1_s[head7][2:0]==head4 ||
        iqentry_a2_s[head7][2:0]==head4 || iqentry_a3_s[head7]==head4 || iqentry_p_s[head7]==head4)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head7;
            cmt_miss_pc = iqentry_pc[head7];
            stomp_mask[head7] = 1'b0; 
        end
    end
    else if (!iqentry_cmt[head5]) begin
        if (iqentry_v[head6] && (iqentry_a1_s[head6][2:0]==head5 || 
        iqentry_a2_s[head6][2:0]==head5 || iqentry_a3_s[head6]==head5 || iqentry_p_s[head6]==head5)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head6;
            cmt_miss_pc = iqentry_pc[head6];
            stomp_mask[head6] = 1'b0;
            stomp_mask[head7] = 1'b0; 
        end
        else if (iqentry_v[head7] && (iqentry_a1_s[head7][2:0]==head5 ||
        iqentry_a2_s[head7][2:0]==head5 || iqentry_a3_s[head7]==head5 || iqentry_p_s[head7]==head5)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head7;
            cmt_miss_pc = iqentry_pc[head7];
            stomp_mask[head7] = 1'b0; 
        end
    end
    else if (!iqentry_cmt[head6]) begin
        if (iqentry_v[head7] && (iqentry_a1_s[head7][2:0]==head6 ||
        iqentry_a2_s[head7][2:0]==head6 || iqentry_a3_s[head7]==head6 || iqentry_p_s[head7]==head6)) begin
            cmt_miss = `TRUE;
            cmt_miss_id = head7;
            cmt_miss_pc = iqentry_pc[head7];
            stomp_mask[head7] = 1'b0; 
        end
    end
end

assign
	iqentry_stomp[0] = branchmiss ? (iqentry_v[0] && head0 != 3'd0 && (missid == 3'd7 || iqentry_stomp[7])) :
	                   cmt_miss ? ~stomp_mask[0] : 1'b0;
assign	                   
	iqentry_stomp[1] = branchmiss ? (iqentry_v[1] && head0 != 3'd1 && (missid == 3'd0 || iqentry_stomp[0])) :
	                   cmt_miss ? ~stomp_mask[1] : 1'b0;
assign	                  
	iqentry_stomp[2] = branchmiss ? (iqentry_v[2] && head0 != 3'd2 && (missid == 3'd1 || iqentry_stomp[1])) :
	                   cmt_miss ? ~stomp_mask[2] : 1'b0;
assign	                   
	iqentry_stomp[3] = branchmiss ? (iqentry_v[3] && head0 != 3'd3 && (missid == 3'd2 || iqentry_stomp[2])) :
	                   cmt_miss ? ~stomp_mask[3] : 1'b0;
assign	                   
	iqentry_stomp[4] = branchmiss ? (iqentry_v[4] && head0 != 3'd4 && (missid == 3'd3 || iqentry_stomp[3])) :
	                   cmt_miss ? ~stomp_mask[4] : 1'b0;
assign	                  
	iqentry_stomp[5] = branchmiss ? (iqentry_v[5] && head0 != 3'd5 && (missid == 3'd4 || iqentry_stomp[4])) :
	                   cmt_miss ? ~stomp_mask[5] : 1'b0;
assign	                   
	iqentry_stomp[6] = branchmiss ? (iqentry_v[6] && head0 != 3'd6 && (missid == 3'd5 || iqentry_stomp[5])) :
	                   cmt_miss ? ~stomp_mask[6] : 1'b0;
assign	                  
	iqentry_stomp[7] = branchmiss ? (iqentry_v[7] && head0 != 3'd7 && (missid == 3'd6 || iqentry_stomp[6])) :
	                   cmt_miss ? ~stomp_mask[7] : 1'b0;
/*
	iqentry_stomp[1] = stomp_all || ((branchmiss|cmt_miss) && iqentry_v[1] && head0 != 3'd1 && (missid == 3'd0 || iqentry_stomp[0])),
	iqentry_stomp[2] = stomp_all || ((branchmiss|cmt_miss) && iqentry_v[2] && head0 != 3'd2 && (missid == 3'd1 || iqentry_stomp[1])),
	iqentry_stomp[3] = stomp_all || ((branchmiss|cmt_miss) && iqentry_v[3] && head0 != 3'd3 && (missid == 3'd2 || iqentry_stomp[2])),
	iqentry_stomp[4] = stomp_all || ((branchmiss|cmt_miss) && iqentry_v[4] && head0 != 3'd4 && (missid == 3'd3 || iqentry_stomp[3])),
	iqentry_stomp[5] = stomp_all || ((branchmiss|cmt_miss) && iqentry_v[5] && head0 != 3'd5 && (missid == 3'd4 || iqentry_stomp[4])),
	iqentry_stomp[6] = stomp_all || ((branchmiss|cmt_miss) && iqentry_v[6] && head0 != 3'd6 && (missid == 3'd5 || iqentry_stomp[5])),
	iqentry_stomp[7] = stomp_all || ((branchmiss|cmt_miss) && iqentry_v[7] && head0 != 3'd7 && (missid == 3'd6 || iqentry_stomp[6]));
*/

assign alu0_issue = (!(iqentry_v[0] && iqentry_stomp[0]) && iqentry_issue[0] && iqentry_islot[0]==2'd0) ||
			(!(iqentry_v[1] && iqentry_stomp[1]) && iqentry_issue[1] && iqentry_islot[1]==2'd0) ||
			(!(iqentry_v[2] && iqentry_stomp[2]) && iqentry_issue[2] && iqentry_islot[2]==2'd0) ||
			(!(iqentry_v[3] && iqentry_stomp[3]) && iqentry_issue[3] && iqentry_islot[3]==2'd0) ||
			(!(iqentry_v[4] && iqentry_stomp[4]) && iqentry_issue[4] && iqentry_islot[4]==2'd0) ||
			(!(iqentry_v[5] && iqentry_stomp[5]) && iqentry_issue[5] && iqentry_islot[5]==2'd0) ||
			(!(iqentry_v[6] && iqentry_stomp[6]) && iqentry_issue[6] && iqentry_islot[6]==2'd0) ||
			(!(iqentry_v[7] && iqentry_stomp[7]) && iqentry_issue[7] && iqentry_islot[7]==2'd0)
			;

assign alu1_issue = (!(iqentry_v[0] && iqentry_stomp[0]) && iqentry_issue[0] && iqentry_islot[0]==2'd1) ||
			(!(iqentry_v[1] && iqentry_stomp[1]) && iqentry_issue[1] && iqentry_islot[1]==2'd1) ||
			(!(iqentry_v[2] && iqentry_stomp[2]) && iqentry_issue[2] && iqentry_islot[2]==2'd1) ||
			(!(iqentry_v[3] && iqentry_stomp[3]) && iqentry_issue[3] && iqentry_islot[3]==2'd1) ||
			(!(iqentry_v[4] && iqentry_stomp[4]) && iqentry_issue[4] && iqentry_islot[4]==2'd1) ||
			(!(iqentry_v[5] && iqentry_stomp[5]) && iqentry_issue[5] && iqentry_islot[5]==2'd1) ||
			(!(iqentry_v[6] && iqentry_stomp[6]) && iqentry_issue[6] && iqentry_islot[6]==2'd1) ||
			(!(iqentry_v[7] && iqentry_stomp[7]) && iqentry_issue[7] && iqentry_islot[7]==2'd1)
			;

`ifdef FLOATING_POINT
assign fp0_issue = (!(iqentry_v[0] && iqentry_stomp[0]) && iqentry_fpissue[0] && iqentry_islot[0]==2'd0) ||
			(!(iqentry_v[1] && iqentry_stomp[1]) && iqentry_fpissue[1] && iqentry_islot[1]==2'd0) ||
			(!(iqentry_v[2] && iqentry_stomp[2]) && iqentry_fpissue[2] && iqentry_islot[2]==2'd0) ||
			(!(iqentry_v[3] && iqentry_stomp[3]) && iqentry_fpissue[3] && iqentry_islot[3]==2'd0) ||
			(!(iqentry_v[4] && iqentry_stomp[4]) && iqentry_fpissue[4] && iqentry_islot[4]==2'd0) ||
			(!(iqentry_v[5] && iqentry_stomp[5]) && iqentry_fpissue[5] && iqentry_islot[5]==2'd0) ||
			(!(iqentry_v[6] && iqentry_stomp[6]) && iqentry_fpissue[6] && iqentry_islot[6]==2'd0) ||
			(!(iqentry_v[7] && iqentry_stomp[7]) && iqentry_fpissue[7] && iqentry_islot[7]==2'd0)
			;
`endif

wire dcache_access_pending = dram0 == 3'd6 && (!rhit || (dram0_op==`LCL && dram0_tgt==7'd1));

//
// determine if the instructions ready to issue can, in fact, issue.
// "ready" means that the instruction has valid operands but has not gone yet
//
// Stores can only issue if there is no possibility of a change of program flow.
// That means no flow control operations or instructions that can cause an
// exception can be before the store.
assign iqentry_memissue_head0 =	iqentry_memready[ head0 ] && cstate==IDLE && !dcache_access_pending && dram0==0;		// first in line ... go as soon as ready

assign iqentry_memissue_head1 =	~iqentry_stomp[head1] && iqentry_memready[ head1 ] 		// addr and data are valid
				// ... and no preceding instruction is ready to go
				&& ~iqentry_memready[head0]
				// ... and there is no address-overlap with any preceding instruction
				&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
					|| (iqentry_a1_v[head0] && iqentry_a1[head1][DBW-1:3] != iqentry_a1[head0][DBW-1:3]))
				// ... and, if it is a SW, there is no chance of it being undone
				&& (fnIsStore(iqentry_op[head1]) ? !fnIsFlowCtrl(iqentry_op[head0])
				&& !fnCanException(iqentry_op[head0],iqentry_fn[head0]) : `TRUE)
				&& (iqentry_op[head1]!=`CAS)
				&& !(iqentry_v[head0] && fnIsMem(iqentry_op[head0]) && iqentry_op[head0]==`MEMDB) 
				&& !(iqentry_v[head0] && iqentry_op[head0]==`MEMSB) 
				&& cstate==IDLE && !dcache_access_pending && dram0==0
				;

assign iqentry_memissue_head2 =	~iqentry_stomp[head2] && iqentry_memready[ head2 ]		// addr and data are valid
				// ... and no preceding instruction is ready to go
				&& ~iqentry_memready[head0]
				&& ~iqentry_memready[head1] 
				// ... and there is no address-overlap with any preceding instruction
				&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
					|| (iqentry_a1_v[head0] && iqentry_a1[head2][DBW-1:3] != iqentry_a1[head0][DBW-1:3]))
				&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
					|| (iqentry_a1_v[head1] && iqentry_a1[head2][DBW-1:3] != iqentry_a1[head1][DBW-1:3]))
				// ... and, if it is a SW, there is no chance of it being undone
				&& (fnIsStore(iqentry_op[head2]) ?
				    !fnIsFlowCtrl(iqentry_op[head0]) && !fnCanException(iqentry_op[head0],iqentry_fn[head0]) && 
				    !fnIsFlowCtrl(iqentry_op[head1]) && !fnCanException(iqentry_op[head1],iqentry_fn[head1]) 
				    : `TRUE)
				&& (iqentry_op[head2]!=`CAS)
				&& !(iqentry_v[head0] && fnIsMem(iqentry_op[head0]) && iqentry_op[head0]==`MEMDB)
				&& !(iqentry_v[head1] && fnIsMem(iqentry_op[head1]) && iqentry_op[head1]==`MEMDB)
				// ... and there is no instruction barrier
				&& !(iqentry_v[head0] && iqentry_op[head0]==`MEMSB) 
				&& !(iqentry_v[head1] && iqentry_op[head1]==`MEMSB)
				&& cstate==IDLE && !dcache_access_pending && dram0==0
				;
//					(   !fnIsFlowCtrl(iqentry_op[head0])
//					 && !fnIsFlowCtrl(iqentry_op[head1])));

assign iqentry_memissue_head3 =	~iqentry_stomp[head3] && iqentry_memready[ head3 ] 	// addr and data are valid
				// ... and no preceding instruction is ready to go
				&& ~iqentry_memready[head0]
				&& ~iqentry_memready[head1] 
				&& ~iqentry_memready[head2] 
				// ... and there is no address-overlap with any preceding instruction
				&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
					|| (iqentry_a1_v[head0] && iqentry_a1[head3][DBW-1:3] != iqentry_a1[head0][DBW-1:3]))
				&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
					|| (iqentry_a1_v[head1] && iqentry_a1[head3][DBW-1:3] != iqentry_a1[head1][DBW-1:3]))
				&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
					|| (iqentry_a1_v[head2] && iqentry_a1[head3][DBW-1:3] != iqentry_a1[head2][DBW-1:3]))
				// ... and, if it is a SW, there is no chance of it being undone
				&& (fnIsStore(iqentry_op[head3]) ?
                    !fnIsFlowCtrl(iqentry_op[head0]) && !fnCanException(iqentry_op[head0],iqentry_fn[head0]) && 
                    !fnIsFlowCtrl(iqentry_op[head1]) && !fnCanException(iqentry_op[head1],iqentry_fn[head1]) &&
                    !fnIsFlowCtrl(iqentry_op[head2]) && !fnCanException(iqentry_op[head2],iqentry_fn[head2]) 
                    : `TRUE)
				&& (iqentry_op[head3]!=`CAS)
				// ... and there is no memory barrier
				&& !(iqentry_v[head0] && fnIsMem(iqentry_op[head0]) && iqentry_op[head0]==`MEMDB)
				&& !(iqentry_v[head1] && fnIsMem(iqentry_op[head1]) && iqentry_op[head1]==`MEMDB)
				&& !(iqentry_v[head2] && fnIsMem(iqentry_op[head2]) && iqentry_op[head2]==`MEMDB)
				// ... and there is no instruction barrier
				&& !(iqentry_v[head0] && iqentry_op[head0]==`MEMSB) 
                && !(iqentry_v[head1] && iqentry_op[head1]==`MEMSB) 
                && !(iqentry_v[head2] && iqentry_op[head2]==`MEMSB)
				&& cstate==IDLE && !dcache_access_pending && dram0==0
				;
/*					(   !fnIsFlowCtrl(iqentry_op[head0])
					 && !fnIsFlowCtrl(iqentry_op[head1])
					 && !fnIsFlowCtrl(iqentry_op[head2])));
*/
assign iqentry_memissue_head4 =	~iqentry_stomp[head4] && iqentry_memready[ head4 ] 		// addr and data are valid
				// ... and no preceding instruction is ready to go
				&& ~iqentry_memready[head0]
				&& ~iqentry_memready[head1] 
				&& ~iqentry_memready[head2] 
				&& ~iqentry_memready[head3] 
				// ... and there is no address-overlap with any preceding instruction
				&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
					|| (iqentry_a1_v[head0] && iqentry_a1[head4][DBW-1:3] != iqentry_a1[head0][DBW-1:3]))
				&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
					|| (iqentry_a1_v[head1] && iqentry_a1[head4][DBW-1:3] != iqentry_a1[head1][DBW-1:3]))
				&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
					|| (iqentry_a1_v[head2] && iqentry_a1[head4][DBW-1:3] != iqentry_a1[head2][DBW-1:3]))
				&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
					|| (iqentry_a1_v[head3] && iqentry_a1[head4][DBW-1:3] != iqentry_a1[head3][DBW-1:3]))
				// ... and, if it is a SW, there is no chance of it being undone
				&& (fnIsStore(iqentry_op[head4]) ?
                    !fnIsFlowCtrl(iqentry_op[head0]) && !fnCanException(iqentry_op[head0],iqentry_fn[head0]) && 
                    !fnIsFlowCtrl(iqentry_op[head1]) && !fnCanException(iqentry_op[head1],iqentry_fn[head1]) &&
                    !fnIsFlowCtrl(iqentry_op[head2]) && !fnCanException(iqentry_op[head2],iqentry_fn[head2]) && 
                    !fnIsFlowCtrl(iqentry_op[head3]) && !fnCanException(iqentry_op[head3],iqentry_fn[head3]) 
                    : `TRUE)
				&& (iqentry_op[head4]!=`CAS)
				// ... and there is no memory barrier
				&& !(iqentry_v[head0] && fnIsMem(iqentry_op[head0]) && iqentry_op[head0]==`MEMDB)
				&& !(iqentry_v[head1] && fnIsMem(iqentry_op[head1]) && iqentry_op[head1]==`MEMDB)
				&& !(iqentry_v[head2] && fnIsMem(iqentry_op[head2]) && iqentry_op[head2]==`MEMDB)
				&& !(iqentry_v[head3] && fnIsMem(iqentry_op[head3]) && iqentry_op[head3]==`MEMDB)
				// ... and there is no instruction barrier
				&& !(iqentry_v[head0] && iqentry_op[head0]==`MEMSB) 
                && !(iqentry_v[head1] && iqentry_op[head1]==`MEMSB) 
                && !(iqentry_v[head2] && iqentry_op[head2]==`MEMSB) 
                && !(iqentry_v[head3] && iqentry_op[head3]==`MEMSB)
				&& cstate==IDLE && !dcache_access_pending && dram0==0
				;
/* ||
					(   !fnIsFlowCtrl(iqentry_op[head0])
					 && !fnIsFlowCtrl(iqentry_op[head1])
					 && !fnIsFlowCtrl(iqentry_op[head2])
					 && !fnIsFlowCtrl(iqentry_op[head3])));
*/
assign iqentry_memissue_head5 =	~iqentry_stomp[head5] && iqentry_memready[ head5 ] 		// addr and data are valid
				// ... and no preceding instruction is ready to go
				&& ~iqentry_memready[head0]
				&& ~iqentry_memready[head1] 
				&& ~iqentry_memready[head2] 
				&& ~iqentry_memready[head3] 
				&& ~iqentry_memready[head4] 
				// ... and there is no address-overlap with any preceding instruction
				&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
					|| (iqentry_a1_v[head0] && iqentry_a1[head5][DBW-1:3] != iqentry_a1[head0][DBW-1:3]))
				&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
					|| (iqentry_a1_v[head1] && iqentry_a1[head5][DBW-1:3] != iqentry_a1[head1][DBW-1:3]))
				&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
					|| (iqentry_a1_v[head2] && iqentry_a1[head5][DBW-1:3] != iqentry_a1[head2][DBW-1:3]))
				&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
					|| (iqentry_a1_v[head3] && iqentry_a1[head5][DBW-1:3] != iqentry_a1[head3][DBW-1:3]))
				&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
					|| (iqentry_a1_v[head4] && iqentry_a1[head5][DBW-1:3] != iqentry_a1[head4][DBW-1:3]))
				// ... and, if it is a SW, there is no chance of it being undone
				&& (fnIsStore(iqentry_op[head5]) ?
                    !fnIsFlowCtrl(iqentry_op[head0]) && !fnCanException(iqentry_op[head0],iqentry_fn[head0]) && 
                    !fnIsFlowCtrl(iqentry_op[head1]) && !fnCanException(iqentry_op[head1],iqentry_fn[head1]) &&
                    !fnIsFlowCtrl(iqentry_op[head2]) && !fnCanException(iqentry_op[head2],iqentry_fn[head2]) && 
                    !fnIsFlowCtrl(iqentry_op[head3]) && !fnCanException(iqentry_op[head3],iqentry_fn[head3]) && 
                    !fnIsFlowCtrl(iqentry_op[head4]) && !fnCanException(iqentry_op[head4],iqentry_fn[head4]) 
                    : `TRUE)
				&& (iqentry_op[head5]!=`CAS)
				// ... and there is no memory barrier
				&& !(iqentry_v[head0] && fnIsMem(iqentry_op[head0]) && iqentry_op[head0]==`MEMDB)
				&& !(iqentry_v[head1] && fnIsMem(iqentry_op[head1]) && iqentry_op[head1]==`MEMDB)
				&& !(iqentry_v[head2] && fnIsMem(iqentry_op[head2]) && iqentry_op[head2]==`MEMDB)
				&& !(iqentry_v[head3] && fnIsMem(iqentry_op[head3]) && iqentry_op[head3]==`MEMDB)
				&& !(iqentry_v[head4] && fnIsMem(iqentry_op[head4]) && iqentry_op[head4]==`MEMDB)
				// ... and there is no instruction barrier
				&& !(iqentry_v[head0] && iqentry_op[head0]==`MEMSB) 
                && !(iqentry_v[head1] && iqentry_op[head1]==`MEMSB) 
                && !(iqentry_v[head2] && iqentry_op[head2]==`MEMSB) 
                && !(iqentry_v[head3] && iqentry_op[head3]==`MEMSB) 
                && !(iqentry_v[head4] && iqentry_op[head4]==`MEMSB)
				&& cstate==IDLE && !dcache_access_pending && dram0==0
				;
/*||
					(   !fnIsFlowCtrl(iqentry_op[head0])
					 && !fnIsFlowCtrl(iqentry_op[head1])
					 && !fnIsFlowCtrl(iqentry_op[head2])
					 && !fnIsFlowCtrl(iqentry_op[head3])
					 && !fnIsFlowCtrl(iqentry_op[head4])));
*/
assign iqentry_memissue_head6 =	~iqentry_stomp[head6] && iqentry_memready[ head6 ] 		// addr and data are valid
				// ... and no preceding instruction is ready to go
				&& ~iqentry_memready[head0]
				&& ~iqentry_memready[head1] 
				&& ~iqentry_memready[head2] 
				&& ~iqentry_memready[head3] 
				&& ~iqentry_memready[head4] 
				&& ~iqentry_memready[head5] 
				// ... and there is no address-overlap with any preceding instruction
				&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
					|| (iqentry_a1_v[head0] && iqentry_a1[head6][DBW-1:3] != iqentry_a1[head0][DBW-1:3]))
				&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
					|| (iqentry_a1_v[head1] && iqentry_a1[head6][DBW-1:3] != iqentry_a1[head1][DBW-1:3]))
				&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
					|| (iqentry_a1_v[head2] && iqentry_a1[head6][DBW-1:3] != iqentry_a1[head2][DBW-1:3]))
				&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
					|| (iqentry_a1_v[head3] && iqentry_a1[head6][DBW-1:3] != iqentry_a1[head3][DBW-1:3]))
				&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
					|| (iqentry_a1_v[head4] && iqentry_a1[head6][DBW-1:3] != iqentry_a1[head4][DBW-1:3]))
				&& (!iqentry_mem[head5] || (iqentry_agen[head5] & iqentry_out[head5]) 
					|| (iqentry_a1_v[head5] && iqentry_a1[head6][DBW-1:3] != iqentry_a1[head5][DBW-1:3]))
				// ... and, if it is a SW, there is no chance of it being undone
				&& (fnIsStore(iqentry_op[head6]) ?
                    !fnIsFlowCtrl(iqentry_op[head0]) && !fnCanException(iqentry_op[head0],iqentry_fn[head0]) && 
                    !fnIsFlowCtrl(iqentry_op[head1]) && !fnCanException(iqentry_op[head1],iqentry_fn[head1]) &&
                    !fnIsFlowCtrl(iqentry_op[head2]) && !fnCanException(iqentry_op[head2],iqentry_fn[head2]) && 
                    !fnIsFlowCtrl(iqentry_op[head3]) && !fnCanException(iqentry_op[head3],iqentry_fn[head3]) && 
                    !fnIsFlowCtrl(iqentry_op[head4]) && !fnCanException(iqentry_op[head4],iqentry_fn[head4]) && 
                    !fnIsFlowCtrl(iqentry_op[head5]) && !fnCanException(iqentry_op[head5],iqentry_fn[head5]) 
                    : `TRUE)
				&& (iqentry_op[head6]!=`CAS)
				// ... and there is no memory barrier
				&& !(iqentry_v[head0] && fnIsMem(iqentry_op[head0]) && iqentry_op[head0]==`MEMDB)
				&& !(iqentry_v[head1] && fnIsMem(iqentry_op[head1]) && iqentry_op[head1]==`MEMDB)
				&& !(iqentry_v[head2] && fnIsMem(iqentry_op[head2]) && iqentry_op[head2]==`MEMDB)
				&& !(iqentry_v[head3] && fnIsMem(iqentry_op[head3]) && iqentry_op[head3]==`MEMDB)
				&& !(iqentry_v[head4] && fnIsMem(iqentry_op[head4]) && iqentry_op[head4]==`MEMDB)
				&& !(iqentry_v[head5] && fnIsMem(iqentry_op[head5]) && iqentry_op[head5]==`MEMDB)
				// ... and there is no instruction barrier
				&& !(iqentry_v[head0] && iqentry_op[head0]==`MEMSB) 
                && !(iqentry_v[head1] && iqentry_op[head1]==`MEMSB) 
                && !(iqentry_v[head2] && iqentry_op[head2]==`MEMSB) 
                && !(iqentry_v[head3] && iqentry_op[head3]==`MEMSB) 
                && !(iqentry_v[head4] && iqentry_op[head4]==`MEMSB) 
                && !(iqentry_v[head5] && iqentry_op[head5]==`MEMSB)
				&& cstate==IDLE && !dcache_access_pending && dram0==0
				;
				/*||
					(   !fnIsFlowCtrl(iqentry_op[head0])
					 && !fnIsFlowCtrl(iqentry_op[head1])
					 && !fnIsFlowCtrl(iqentry_op[head2])
					 && !fnIsFlowCtrl(iqentry_op[head3])
					 && !fnIsFlowCtrl(iqentry_op[head4])
					 && !fnIsFlowCtrl(iqentry_op[head5])));
*/
assign iqentry_memissue_head7 =	~iqentry_stomp[head7] && iqentry_memready[ head7 ] 		// addr and data are valid
				// ... and no preceding instruction is ready to go
				&& ~iqentry_memready[head0]
				&& ~iqentry_memready[head1] 
				&& ~iqentry_memready[head2] 
				&& ~iqentry_memready[head3] 
				&& ~iqentry_memready[head4] 
				&& ~iqentry_memready[head5] 
				&& ~iqentry_memready[head6] 
				// ... and there is no address-overlap with any preceding instruction
				&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
					|| (iqentry_a1_v[head0] && iqentry_a1[head7][DBW-1:3] != iqentry_a1[head0][DBW-1:3]))
				&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
					|| (iqentry_a1_v[head1] && iqentry_a1[head7][DBW-1:3] != iqentry_a1[head1][DBW-1:3]))
				&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
					|| (iqentry_a1_v[head2] && iqentry_a1[head7][DBW-1:3] != iqentry_a1[head2][DBW-1:3]))
				&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
					|| (iqentry_a1_v[head3] && iqentry_a1[head7][DBW-1:3] != iqentry_a1[head3][DBW-1:3]))
				&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
					|| (iqentry_a1_v[head4] && iqentry_a1[head7][DBW-1:3] != iqentry_a1[head4][DBW-1:3]))
				&& (!iqentry_mem[head5] || (iqentry_agen[head5] & iqentry_out[head5]) 
					|| (iqentry_a1_v[head5] && iqentry_a1[head7][DBW-1:3] != iqentry_a1[head5][DBW-1:3]))
				&& (!iqentry_mem[head6] || (iqentry_agen[head6] & iqentry_out[head6]) 
					|| (iqentry_a1_v[head6] && iqentry_a1[head7][DBW-1:3] != iqentry_a1[head6][DBW-1:3]))
				// ... and, if it is a SW, there is no chance of it being undone
				&& (fnIsStore(iqentry_op[head7]) ?
                    !fnIsFlowCtrl(iqentry_op[head0]) && !fnCanException(iqentry_op[head0],iqentry_fn[head0]) && 
                    !fnIsFlowCtrl(iqentry_op[head1]) && !fnCanException(iqentry_op[head1],iqentry_fn[head1]) &&
                    !fnIsFlowCtrl(iqentry_op[head2]) && !fnCanException(iqentry_op[head2],iqentry_fn[head2]) && 
                    !fnIsFlowCtrl(iqentry_op[head3]) && !fnCanException(iqentry_op[head3],iqentry_fn[head3]) && 
                    !fnIsFlowCtrl(iqentry_op[head4]) && !fnCanException(iqentry_op[head4],iqentry_fn[head4]) && 
                    !fnIsFlowCtrl(iqentry_op[head5]) && !fnCanException(iqentry_op[head5],iqentry_fn[head5]) && 
                    !fnIsFlowCtrl(iqentry_op[head6]) && !fnCanException(iqentry_op[head6],iqentry_fn[head6]) 
                    : `TRUE)
				&& (iqentry_op[head7]!=`CAS)
				// ... and there is no memory barrier
				&& !(iqentry_v[head0] && fnIsMem(iqentry_op[head0]) && iqentry_op[head0]==`MEMDB)
				&& !(iqentry_v[head1] && fnIsMem(iqentry_op[head1]) && iqentry_op[head1]==`MEMDB)
				&& !(iqentry_v[head2] && fnIsMem(iqentry_op[head2]) && iqentry_op[head2]==`MEMDB)
				&& !(iqentry_v[head3] && fnIsMem(iqentry_op[head3]) && iqentry_op[head3]==`MEMDB)
				&& !(iqentry_v[head4] && fnIsMem(iqentry_op[head4]) && iqentry_op[head4]==`MEMDB)
				&& !(iqentry_v[head5] && fnIsMem(iqentry_op[head5]) && iqentry_op[head5]==`MEMDB)
				&& !(iqentry_v[head6] && fnIsMem(iqentry_op[head6]) && iqentry_op[head6]==`MEMDB)
				// ... and there is no instruction barrier
				&& !(iqentry_v[head0] && iqentry_op[head0]==`MEMSB) 
                && !(iqentry_v[head1] && iqentry_op[head1]==`MEMSB) 
                && !(iqentry_v[head2] && iqentry_op[head2]==`MEMSB) 
                && !(iqentry_v[head3] && iqentry_op[head3]==`MEMSB) 
                && !(iqentry_v[head4] && iqentry_op[head4]==`MEMSB) 
                && !(iqentry_v[head5] && iqentry_op[head5]==`MEMSB) 
                && !(iqentry_v[head6] && iqentry_op[head6]==`MEMSB)
				&& cstate==IDLE && !dcache_access_pending && dram0==0
				;

`include "Thor_execute_combo.v"
//`include "Thor_memory_combo.v"
// additional DRAM-enqueue logic

Thor_TLB #(DBW) utlb1
(
	.rst(rst_i),
	.clk(clk),
	.km(km),
	.pc(spc),
	.ea(dram0_addr),
	.ppc(ppc),
	.pea(pea),
	.iuncached(iuncached),
	.uncached(uncached),
	.m1IsStore(we_o),
	.ASID(asid),
	.op(tlb_op),
	.state(tlb_state),
	.regno(tlb_regno),
	.dati(tlb_data),
	.dato(tlb_dato),
	.ITLBMiss(ITLBMiss),
	.DTLBMiss(DTLBMiss),
	.HTLBVirtPageo()
);
	
assign dram_avail = (dram0 == `DRAMSLOT_AVAIL || dram1 == `DRAMSLOT_AVAIL || dram2 == `DRAMSLOT_AVAIL);

generate
begin : memr
    for (g = 0; g < QENTRIES; g = g + 1)
    begin
assign iqentry_memopsvalid[g] = (iqentry_mem[g] & iqentry_a2_v[g] & iqentry_a3_v[g] & iqentry_agen[g]);
assign iqentry_memready[g] = (iqentry_v[g] & iqentry_memopsvalid[g] & ~iqentry_memissue[g] & !iqentry_issue[g] & ~iqentry_done[g] & ~iqentry_out[g] & ~iqentry_stomp[g]);
    end
end
endgenerate

/*
assign
    iqentry_memopsvalid[0] = (iqentry_mem[0] & iqentry_a2_v[0] & iqentry_a3_v[0] & iqentry_agen[0]),
	iqentry_memopsvalid[1] = (iqentry_mem[1] & iqentry_a2_v[1] & iqentry_a3_v[1] & iqentry_agen[1]),
	iqentry_memopsvalid[2] = (iqentry_mem[2] & iqentry_a2_v[2] & iqentry_a3_v[2] & iqentry_agen[2]),
	iqentry_memopsvalid[3] = (iqentry_mem[3] & iqentry_a2_v[3] & iqentry_a3_v[3] & iqentry_agen[3]),
	iqentry_memopsvalid[4] = (iqentry_mem[4] & iqentry_a2_v[4] & iqentry_a3_v[4] & iqentry_agen[4]),
	iqentry_memopsvalid[5] = (iqentry_mem[5] & iqentry_a2_v[5] & iqentry_a3_v[5] & iqentry_agen[5]),
	iqentry_memopsvalid[6] = (iqentry_mem[6] & iqentry_a2_v[6] & iqentry_a3_v[6] & iqentry_agen[6]),
	iqentry_memopsvalid[7] = (iqentry_mem[7] & iqentry_a2_v[7] & iqentry_a3_v[7] & iqentry_agen[7]);

assign
    iqentry_memready[0] = (iqentry_v[0] & iqentry_memopsvalid[0] & ~iqentry_memissue[0] & ~iqentry_done[0] & ~iqentry_out[0] & ~iqentry_stomp[0]),
	iqentry_memready[1] = (iqentry_v[1] & iqentry_memopsvalid[1] & ~iqentry_memissue[1] & ~iqentry_done[1] & ~iqentry_out[1] & ~iqentry_stomp[1]),
	iqentry_memready[2] = (iqentry_v[2] & iqentry_memopsvalid[2] & ~iqentry_memissue[2] & ~iqentry_done[2] & ~iqentry_out[2] & ~iqentry_stomp[2]),
	iqentry_memready[3] = (iqentry_v[3] & iqentry_memopsvalid[3] & ~iqentry_memissue[3] & ~iqentry_done[3] & ~iqentry_out[3] & ~iqentry_stomp[3]),
	iqentry_memready[4] = (iqentry_v[4] & iqentry_memopsvalid[4] & ~iqentry_memissue[4] & ~iqentry_done[4] & ~iqentry_out[4] & ~iqentry_stomp[4]),
	iqentry_memready[5] = (iqentry_v[5] & iqentry_memopsvalid[5] & ~iqentry_memissue[5] & ~iqentry_done[5] & ~iqentry_out[5] & ~iqentry_stomp[5]),
	iqentry_memready[6] = (iqentry_v[6] & iqentry_memopsvalid[6] & ~iqentry_memissue[6] & ~iqentry_done[6] & ~iqentry_out[6] & ~iqentry_stomp[6]),
	iqentry_memready[7] = (iqentry_v[7] & iqentry_memopsvalid[7] & ~iqentry_memissue[7] & ~iqentry_done[7] & ~iqentry_out[7] & ~iqentry_stomp[7]);
*/
assign outstanding_stores = (dram0 && fnIsStore(dram0_op)) || (dram1 && fnIsStore(dram1_op)) || (dram2 && fnIsStore(dram2_op));

// This signal needed to stave off an instruction cache access.
assign mem_issue =
    iqentry_memissue_head0 |
    iqentry_memissue_head1 |
    iqentry_memissue_head2 |
    iqentry_memissue_head3 |
    iqentry_memissue_head4 |
    iqentry_memissue_head5 |
    iqentry_memissue_head6 |
    iqentry_memissue_head7
    ;

//`include "Thor_commit_combo.v"
// If trying to write to two branch registers at once, or trying to write 
// to two predicate registers at once, then limit the processor to single
// commit.
// The processor does not support writing two registers in the same register
// group at the same time for anything other than the general purpose
// registers. It is possible for the processor to write to two diffent groups
// at the same time.
//assign limit_cmt = (iqentry_rfw[head0] && iqentry_rfw[head1] && iqentry_tgt[head0][8]==1'b1 && iqentry_tgt[head1][8]==1'b1);
assign limit_cmt = 1'b0;
//assign committing2 = (iqentry_v[head0] && iqentry_v[head1] && !limit_cmt) || (head0 != tail0 && head1 != tail0);

assign commit0_v = ({iqentry_v[head0], iqentry_done[head0]} == 2'b11 && ~|panic && iqentry_cmt[head0]);
assign commit1_v = ({iqentry_v[head0], iqentry_done[head0]} != 2'b10 
		&& {iqentry_v[head1], iqentry_done[head1]} == 2'b11 && ~|panic && iqentry_cmt[head1] && !limit_cmt);

assign commit0_id = {iqentry_mem[head0], head0};	// if a memory op, it has a DRAM-bus id
assign commit1_id = {iqentry_mem[head1], head1};	// if a memory op, it has a DRAM-bus id

assign commit0_tgt = iqentry_tgt[head0];
assign commit1_tgt = iqentry_tgt[head1];

assign commit0_bus = iqentry_res[head0];
assign commit1_bus = iqentry_res[head1];

assign int_commit = (iqentry_op[head0]==`INT && commit0_v) || (commit0_v && iqentry_op[head1]==`INT && commit1_v);
assign sys_commit = (iqentry_op[head0]==`SYS && commit0_v) || (commit0_v && iqentry_op[head1]==`SYS && commit1_v);

always @(posedge clk)
	if (rst_i)
		tick <= 64'd0;
	else
		tick <= tick + 64'd1;

always @(posedge clk)
	if (rst_i)
		nmi1 <= 1'b0;
	else
		nmi1 <= nmi_i;

//-----------------------------------------------------------------------------
// Clock control
// - reset or NMI reenables the clock
// - this circuit must be under the clk_i domain
//-----------------------------------------------------------------------------
//
reg cpu_clk_en;
reg [15:0] clk_throttle;
reg [15:0] clk_throttle_new;
reg ld_clk_throttle;

//BUFGCE u20 (.CE(cpu_clk_en), .I(clk_i), .O(clk) );

reg lct1;
always @(posedge clk_i)
if (rst_i) begin
	cpu_clk_en <= 1'b1;
	lct1 <= 1'b0;
	clk_throttle <= 16'hAAAA;	// 50% power
end
else begin
	lct1 <= ld_clk_throttle;
	clk_throttle <= {clk_throttle[14:0],clk_throttle[15]};
	if (ld_clk_throttle && !lct1) begin
		clk_throttle <= clk_throttle_new;
    end
	if (nmi_i)
		clk_throttle <= 16'hAAAA;
	cpu_clk_en <= clk_throttle[15];
end

// Clock throttling bypassed for now
assign clk_o = clk;
assign clk = clk_i;

//-----------------------------------------------------------------------------
// Note that everything clocked has to be in the same always block. This is a
// limitation of some toolsets. Simulation / synthesis may get confused if the
// logic isn't placed in the same always block.
//-----------------------------------------------------------------------------

always @(posedge clk) begin

	if (nmi_i & !nmi1)
		nmi_edge <= 1'b1;
	
	ld_clk_throttle <= `FALSE;
	dram_v <= `INV;
	alu0_ld <= 1'b0;
	alu1_ld <= 1'b0;
`ifdef FLOATING_POINT
	fp0_ld <= 1'b0;
`endif

	ic_invalidate <= `FALSE;
	dc_invalidate <= `FALSE;
	ic_invalidate_line <= `FALSE;
    dc_invalidate_line <= `FALSE;
    if (rst_i)
        cstate <= RESET1;
	if (rst_i||cstate==RESET1||cstate==RESET2) begin
	    wb_nack();
	    ierr <= 1'b0;
		GM <= 8'hFF;
		nmi_edge <= 1'b0;
		pc <= {{DBW-8{1'b1}},8'h80};
		StatusHWI <= `TRUE;		// disables interrupts at startup until an RTI instruction is executed.
		im <= 1'b1;
		ic_invalidate <= `TRUE;
		dc_invalidate <= `TRUE;
		fetchbuf <= 1'b0;
		fetchbufA_v <= `INV;
		fetchbufB_v <= `INV;
		fetchbufC_v <= `INV;
		fetchbufD_v <= `INV;
		fetchbufA_instr <= {8{8'h10}};
		fetchbufB_instr <= {8{8'h10}};
		fetchbufC_instr <= {8{8'h10}};
		fetchbufD_instr <= {8{8'h10}};
		fetchbufA_pc <= {{DBW-4{1'b1}},4'h0};
		fetchbufB_pc <= {{DBW-4{1'b1}},4'h0};
		fetchbufC_pc <= {{DBW-4{1'b1}},4'h0};
		fetchbufD_pc <= {{DBW-4{1'b1}},4'h0};
`ifdef THREEWAY
		fetchbufE_v <= `INV;
		fetchbufF_v <= `INV;
		fetchbufE_instr <= {8{8'h10}};
        fetchbufF_instr <= {8{8'h10}};
		fetchbufE_pc <= {{DBW-4{1'b1}},4'h0};
        fetchbufF_pc <= {{DBW-4{1'b1}},4'h0};
`endif
		for (i=0; i< QENTRIES; i=i+1) begin
			iqentry_v[i] <= `INV;
			iqentry_agen[i] <= `FALSE;
			iqentry_op[i] <= `NOP;
			iqentry_memissue[i] <= `FALSE;
			iqentry_a1[i] <= 64'd0;
			iqentry_a2[i] <= 64'd0;
			iqentry_a3[i] <= 64'd0;
			iqentry_a1_v[i] <= `INV;
			iqentry_a2_v[i] <= `INV;
			iqentry_a3_v[i] <= `INV;
		end
		// All the register are flagged as valid on startup even though they
		// may not contain valid data. Otherwise the processor will stall
		// waiting for the registers to become valid. Ideally the registers
		// should be initialized with valid values before use. But who knows
		// what someone will do in boot code and we don't want the processor
		// to stall.
		for (n = 1; n < NREGS; n = n + 1)
			rf_v[n] = `VAL;
//		rf_v[0] = `VAL;
//		rf_v[7'h50] = `VAL;
//		rf_v[7'h5F] = `VAL;
		alu0_available <= `TRUE;
		alu1_available <= `TRUE;
        reset_tail_pointers(1);
		head0 <= 3'd0;
		head1 <= 3'd1;
		head2 <= 3'd2;
		head3 <= 3'd3;
		head4 <= 3'd4;
		head5 <= 3'd5;
		head6 <= 3'd6;
		head7 <= 3'd7;
		dram0 <= 3'b00;
		dram1 <= 3'b00;
		dram2 <= 3'b00;
		tlb_state <= 3'd0;
		panic <= `PANIC_NONE;
		string_pc <= 64'd0;
		// The pc wraps around to address zero while fetching the reset vector.
		// This causes the processor to use the code segement register so the
		// CS has to be defined for reset.
		sregs[7] <= 52'd0;
		for (i=0; i < 16; i=i+1)
			pregs[i] <= 4'd0;
		asid <= 8'h00;
		rrmapno <= 3'd0;
		dram0_id <= 0;
		alu1_sourceid <= 0;
	end

	// The following registers are always valid
	rf_v[7'h00] = `VAL;
	rf_v[7'h50] = `VAL;	// C0
	rf_v[7'h5F] = `VAL;	// C15 (PC)
	rf_v[7'h72] = `VAL; // tick
    queued1 = `FALSE;
    queued2 = `FALSE;

	did_branchback <= take_branch;
	did_branchback0 <= take_branch0;
	did_branchback1 <= take_branch1;

	if (branchmiss|cmt_miss) begin
		for (n = 1; n < NREGS; n = n + 1)
			if (rf_v[n] == `INV && ~livetarget[n]) begin
			  $display("brmiss: rf_v[%d] <= VAL",n);
			  rf_v[n] = `VAL;
			end

	    if (|iqentry_0_latestID[NREGS:1])	rf_source[ iqentry_tgt[0] ] <= { iqentry_mem[0], 3'd0 };
	    if (|iqentry_1_latestID[NREGS:1])	rf_source[ iqentry_tgt[1] ] <= { iqentry_mem[1], 3'd1 };
	    if (|iqentry_2_latestID[NREGS:1])	rf_source[ iqentry_tgt[2] ] <= { iqentry_mem[2], 3'd2 };
	    if (|iqentry_3_latestID[NREGS:1])	rf_source[ iqentry_tgt[3] ] <= { iqentry_mem[3], 3'd3 };
	    if (|iqentry_4_latestID[NREGS:1])	rf_source[ iqentry_tgt[4] ] <= { iqentry_mem[4], 3'd4 };
	    if (|iqentry_5_latestID[NREGS:1])	rf_source[ iqentry_tgt[5] ] <= { iqentry_mem[5], 3'd5 };
	    if (|iqentry_6_latestID[NREGS:1])	rf_source[ iqentry_tgt[6] ] <= { iqentry_mem[6], 3'd6 };
	    if (|iqentry_7_latestID[NREGS:1])	rf_source[ iqentry_tgt[7] ] <= { iqentry_mem[7], 3'd7 };

	end

	if (ihit) begin
		$display("\r\n");
		$display("TIME %0d", $time);
	end
	
// COMMIT PHASE (register-file update only ... dequeue is elsewhere)
//
// look at head0 and head1 and let 'em write the register file if they are ready
//
// why is it happening here and not in another phase?
// want to emulate a pass-through register file ... i.e. if we are reading
// out of r3 while writing to r3, the value read is the value written.
// requires BLOCKING assignments, so that we can read from rf[i] later.
//
if (commit0_v) begin
        if (!rf_v[ commit0_tgt ]) begin 
            rf_v[ commit0_tgt ] = rf_source[ commit0_tgt ] == commit0_id || (branchmiss && iqentry_source[ commit0_id[2:0] ]);
        end
        if (commit0_tgt != 7'd0) $display("r%d <- %h", commit0_tgt, commit0_bus);
end
if (commit1_v) begin
        if (!rf_v[ commit1_tgt ]) begin 
            rf_v[ commit1_tgt ] = rf_source[ commit1_tgt ] == commit1_id || (branchmiss && iqentry_source[ commit1_id[2:0] ]);
        end
        if (commit1_tgt != 7'd0) $display("r%d <- %h", commit1_tgt, commit1_bus);
end

//-------------------------------------------------------------------------------
// ENQUEUE
//
// place up to three instructions from the fetch buffer into slots in the IQ.
//   note: they are placed in-order, and they are expected to be executed
// 0, 1, or 2 of the fetch buffers may have valid data
// 0, 1, or 2 slots in the instruction queue may be available.
// if we notice that one of the instructions in the fetch buffer is a predicted
// branch, (set branchback/backpc and delete any instructions after it in
// fetchbuf)
//
// We place the queue logic before the fetch to allow the tools to do the work
// for us. The fetch logic needs to know how many entries were queued, this is
// tracked in the queue stage by variables queued1,queued2,queued3. Blocking
// assignments are used for these vars.
//-------------------------------------------------------------------------------
//
`ifdef THREEWAY
    queued1 = `FALSE;
    queued2 = `FALSE;
    queued3 = `FALSE;
    if (branchmiss|cmt_miss) // don't bother doing anything if there's been a branch miss
        reset_tail_pointers(0);
    else begin    
        case ({fetchbuf0_v, fetchbuf1_v, fetchbuf2_v})// && ((fnNumReadPorts(fetchbuf0_instr) + fnNumReadPorts(fetchbuf1_instr) < 3'd5)||!fetchbuf0_v)})
        3'b000: ;   // do nothing
        3'b001: enque2(tail0,1,0,1);
        3'b010: enque1(tail0,1,0,1);
        3'b011: begin
                enque1(tail0,1,1,1);
                enque2(tail1,2,0,0);
                validate_args1();
                end
        3'b100: enque0(tail0,1,0,1);
        3'b101: ;   // illegal state
        3'b110: begin
                enque0(tail0,1,1,1);
                enque1(tail1,2,0,0);
                validate_args();
                end
        3'b111: begin
                enque0(tail0,1,1,1);
                enque1(tail1,2,1,0);
                enque2(tail2,3,0,0);
                validate_args3();
                end
        endcase
    end
`else
    queued1 = `FALSE;
    queued2 = `FALSE;
    if (branchmiss|cmt_miss) // don't bother doing anything if there's been a branch miss
        reset_tail_pointers(0);
    else begin
        qstomp = `FALSE;
        case ({fetchbuf0_v, fetchbuf1_v && fnNumReadPorts(fetchbuf1_instr) <=  ports_avail})
        2'b00: ; // do nothing
        2'b01:  enque1(tail0,1,0,1);
        2'b10:  enque0(tail0,1,0,1);
        2'b11:  begin
                enque0(tail0,1,1,1);
                enque1(tail1,2,0,0);
                validate_args();
                end
        endcase
    end
`endif
//------------------------------------------------------------------------------
// FETCH
//
// fetch at least two instructions from memory into the fetch buffer unless
// either one of the buffers is still full, in which case we do nothing (kinda
// like alpha approach)
//------------------------------------------------------------------------------
//
`ifdef THREEWAY
if (branchmiss) begin
	$display("pc <= %h", misspc);
	pc <= misspc;
	fetchbuf <= 1'b0;
	fetchbufA_v <= 1'b0;
	fetchbufB_v <= 1'b0;
	fetchbufC_v <= 1'b0;
	fetchbufD_v <= 1'b0;
	fetchbufE_v <= 1'b0;
	fetchbufF_v <= 1'b0;
end
else if (take_branch) begin
	if (fetchbuf == 1'b0) begin
		casex ({fetchbufA_v,fetchbufB_v,fetchbufC_v,fetchbufD_v,fetchbufE_v,fetchbufF_v})
		6'b000000:
			begin
			    fetchDEF();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
				fetchbuf <= 1'b1;
			end
		6'b000001:    panic <= `PANIC_INVALIDFBSTATE;
		6'b000010:    panic <= `PANIC_INVALIDFBSTATE;
		6'b000011:    panic <= `PANIC_INVALIDFBSTATE;
		6'b000100:    panic <= `PANIC_INVALIDFBSTATE;
		6'b000101:    panic <= `PANIC_INVALIDFBSTATE;
		6'b000110:    panic <= `PANIC_INVALIDFBSTATE;
		6'b000111:    panic <= `PANIC_INVALIDFBSTATE;
		6'b001000:
			begin
			    fetchDEF();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
				fetchbufC_v <= iqentry_v[tail0];
				if (iqentry_v[tail0]==`INV)
					fetchbuf <= 1'b1;
			end
		6'b001001:    panic <= `PANIC_INVALIDFBSTATE;
		6'b001010:    panic <= `PANIC_INVALIDFBSTATE;
		6'b001011:    panic <= `PANIC_INVALIDFBSTATE;
		6'b001100:    panic <= `PANIC_INVALIDFBSTATE;
		6'b001101:    panic <= `PANIC_INVALIDFBSTATE;
		6'b001110:    panic <= `PANIC_INVALIDFBSTATE;
		6'b001111:    
			begin
                fetchbufC_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b010000:
			begin
			    fetchDEF();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbufB_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b010001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010111:
            begin
                fetchbufB_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b011000:
            begin
                if ((fnIsBranch(opcodeB) && predict_takenB)||opcodeB==`LOOP) begin
                    pc <= branch_pc;
                    fetchbufB_v <= iqentry_v[tail0];
                    fetchbufC_v <= `INV;
                end
                else begin
                    if (did_branchback0) begin
                        fetchDEF();
                        if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                        fetchbufB_v <= iqentry_v[tail0];
                        fetchbufC_v <= iqentry_v[tail1];
                        if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                            fetchbuf <= 1'b1;
                    end
                    else begin
                        pc <= branch_pc;
                        fetchbufB_v <= iqentry_v[tail0];
                        fetchbufC_v <= iqentry_v[tail1];
                    end
                end
            end
        6'b011001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011111:
            begin
                fetchbufB_v <= iqentry_v[tail0];
                fetchbufC_v <= iqentry_v[tail1];
                if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b100000:
            begin
                fetchDEF();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbufA_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b100001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100111:
            begin
                fetchbufA_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b101xxx:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110000:
            begin
                if ((fnIsBranch(opcodeA) && predict_takenA)||opcodeA==`LOOP) begin
                    pc <= branch_pc;
                    fetchbufA_v <= iqentry_v[tail0];
                    fetchbufB_v <= `INV;
                end
                else begin
                    if (did_branchback0) begin
                        fetchDEF();
                        if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                        fetchbufA_v <= iqentry_v[tail0];
                        fetchbufB_v <= iqentry_v[tail1];
                        if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                            fetchbuf <= 1'b1;
                    end
                    else begin
                        pc <= branch_pc;
                        fetchbufA_v <= iqentry_v[tail0];
                        fetchbufB_v <= iqentry_v[tail1];
                    end
                end
            end
        6'b110001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110111:
            begin
                if ((fnIsBranch(opcodeA) && predict_takenA)||opcodeA==`LOOP)
                    panic <= `PANIC_INVALIDFBSTATE;
                else begin
                    fetchbufA_v <= iqentry_v[tail0];
                    fetchbufB_v <= iqentry_v[tail1];
                    if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                        fetchbuf <= 1'b1;
                end
        6'b111000:
            begin
                fetchDEF();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbufA_v <= iqentry_v[tail0];
                fetchbufB_v <= iqentry_v[tail1];
                fetchbufC_v <= iqentry_v[tail2];
                if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV && iqentry_v[tail2]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b111001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111111:  panic <= `PANIC_INVALIDFBSTATE;
            begin
                fetchbufA_v <= iqentry_v[tail0];
                fetchbufB_v <= iqentry_v[tail1];
                fetchbufC_v <= iqentry_v[tail2];
                if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV && iqentry_v[tail2]==`INV)
                    fetchbuf <= 1'b1;
            end
        endcase
    else
		casex ({fetchbufD_v,fetchbufE_v,fetchbufF_v,fetchbufA_v,fetchbufB_v,fetchbufC_v})
        6'b000000:
            begin
                fetchABC();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbuf <= 1'b1;
            end
        6'b000001:    panic <= `PANIC_INVALIDFBSTATE;
        6'b000010:    panic <= `PANIC_INVALIDFBSTATE;
        6'b000011:    panic <= `PANIC_INVALIDFBSTATE;
        6'b000100:    panic <= `PANIC_INVALIDFBSTATE;
        6'b000101:    panic <= `PANIC_INVALIDFBSTATE;
        6'b000110:    panic <= `PANIC_INVALIDFBSTATE;
        6'b000111:    panic <= `PANIC_INVALIDFBSTATE;
        6'b001000:
            begin
                fetchABC();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbufF_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b001001:    panic <= `PANIC_INVALIDFBSTATE;
        6'b001010:    panic <= `PANIC_INVALIDFBSTATE;
        6'b001011:    panic <= `PANIC_INVALIDFBSTATE;
        6'b001100:    panic <= `PANIC_INVALIDFBSTATE;
        6'b001101:    panic <= `PANIC_INVALIDFBSTATE;
        6'b001110:    panic <= `PANIC_INVALIDFBSTATE;
        6'b001111:    
            begin
                fetchbufF_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b010000:
            begin
                fetchABC();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbufE_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b010001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b010111:
            begin
                fetchbufE_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b011000:
            begin
                if ((fnIsBranch(opcodeE) && predict_takenE)||opcodeE==`LOOP) begin
                    pc <= branch_pc;
                    fetchbufE_v <= iqentry_v[tail0];
                    fetchbufF_v <= `INV;
                end
                else begin
                    if (did_branchback1) begin
                        fetchABC();
                        if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                        fetchbufE_v <= iqentry_v[tail0];
                        fetchbufF_v <= iqentry_v[tail1];
                        if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                            fetchbuf <= 1'b1;
                    end
                    else begin
                        pc <= branch_pc;
                        fetchbufE_v <= iqentry_v[tail0];
                        fetchbufF_v <= iqentry_v[tail1];
                    end
                end
            end
        6'b011001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b011111:
            begin
                fetchbufE_v <= iqentry_v[tail0];
                fetchbufF_v <= iqentry_v[tail1];
                if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b100000:
            begin
                fetchABC();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbufD_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b100001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b100111:
            begin
                fetchbufD_v <= iqentry_v[tail0];
                if (iqentry_v[tail0]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b101xxx:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110000:
            begin
                if ((fnIsBranch(opcodeD) && predict_takenD)||opcodeD==`LOOP) begin
                    pc <= branch_pc;
                    fetchbufD_v <= iqentry_v[tail0];
                    fetchbufE_v <= `INV;
                end
                else begin
                    if (did_branchback1) begin
                        fetchABC();
                        if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                        fetchbufD_v <= iqentry_v[tail0];
                        fetchbufE_v <= iqentry_v[tail1];
                        if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                            fetchbuf <= 1'b1;
                    end
                    else begin
                        pc <= branch_pc;
                        fetchbufD_v <= iqentry_v[tail0];
                        fetchbufE_v <= iqentry_v[tail1];
                    end
                end
            end
        6'b110001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b110111:
            begin
                if ((fnIsBranch(opcodeD) && predict_takenD)||opcodeD==`LOOP)
                    panic <= `PANIC_INVALIDFBSTATE;
                else begin
                    fetchbufD_v <= iqentry_v[tail0];
                    fetchbufE_v <= iqentry_v[tail1];
                    if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV)
                        fetchbuf <= 1'b1;
                end
        6'b111000:
            begin
                fetchABC();
                if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
                fetchbufD_v <= iqentry_v[tail0];
                fetchbufE_v <= iqentry_v[tail1];
                fetchbufF_v <= iqentry_v[tail2];
                if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV && iqentry_v[tail2]==`INV)
                    fetchbuf <= 1'b1;
            end
        6'b111001:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111010:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111011:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111100:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111101:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111110:  panic <= `PANIC_INVALIDFBSTATE;
        6'b111111:  panic <= `PANIC_INVALIDFBSTATE;
            begin
                fetchbufD_v <= iqentry_v[tail0];
                fetchbufE_v <= iqentry_v[tail1];
                fetchbufF_v <= iqentry_v[tail2];
                if (iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV && iqentry_v[tail2]==`INV)
                    fetchbuf <= 1'b1;
            end
        endcase
else begin  // if (take_branch)
    if (fetchbuf==1'b0)
		case ({fetchbufA_v,fetchbufB_v,fetchbufC_v})
		3'b000:   ;
		3'b001:
		    begin
		        fetchbufC_v <= !queued1;
		        fetchbuf <= !queued1;
		    end
		3'b010:
		    begin
		        fetchbufB_v <= !queued1;
		        fetchbuf <= !queued1;
		    end
		3'b011:
		    begin
		        fetchbufB_v <= !(queued1|queued2);
		        fetchbufC_v <= !queued2;
                fetchbuf <= !queued2;
		    end
		3'b100:
		    begin
		        fetchbufA_v <= !queued1;
                fetchbuf <= !queued1;
		    end
		3'b101:   // This is an invalid state
		    begin
                fetchbufA_v <= !(queued1|queued2);
                fetchbufC_v <= !queued2;
                fetchbuf <= !queued2;
            end
        3'b110:
		    begin
                fetchbufA_v <= !(queued1|queued2);
                fetchbufB_v <= !queued2;
                fetchbuf <= !queued2;
            end
        3'b111:
		    begin
                fetchbufA_v <= !(queued1|queued2|queued3);
                fetchbufB_v <= !(queued2|queued3);
                fetchbufC_v <= !queued3;
                fetchbuf <= !queued3;
            end
        endcase
    else
		case ({fetchbufD_v,fetchbufE_v,fetchbufF_v})
		3'b000:   ;
        3'b001:
            begin
                fetchbufF_v <= !queued1;
                fetchbuf <= queued1;
            end
        3'b010:
            begin
                fetchbufE_v <= !queued1;
                fetchbuf <= queued1;
            end
        3'b011:
            begin
                fetchbufE_v <= !(queued1|queued2);
                fetchbufF_v <= !queued2;
                fetchbuf <= queued2;
            end
        3'b100:
            begin
                fetchbufF_v <= !queued1;
                fetchbuf <= queued1;
            end
        3'b101:   // This is an invalid state
            begin
                fetchbufD_v <= !(queued1|queued2);
                fetchbufF_v <= !queued2;
                fetchbuf <= queued2;
            end
        3'b110:
            begin
                fetchbufD_v <= !(queued1|queued2);
                fetchbufE_v <= !queued2;
                fetchbuf <= queued2;
            end
        3'b111:
            begin
                fetchbufD_v <= !(queued1|queued2|queued3);
                fetchbufE_v <= !(queued2|queued3);
                fetchbufF_v <= !queued3;
                fetchbuf <= queued3;
            end
        endcase

	if (fetchbufA_v == `INV && fetchbufB_v == `INV && fetchbufD_v==`INV) begin
	    fetchABC();
        if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
        // fetchbuf steering logic correction
        if (fetchbufD_v==`INV && fetchbufE_v==`INV && fetchbufF_v==`INV && do_pcinc)
            fetchbuf <= 1'b0;
        $display("hit %b 1pc <= %h", do_pcinc, pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn));
    end
    else if (fetchbufD_v == `INV && fetchbufE_v == `INV && fetchbufF_v==`INV) begin
        fetchDEF();
        if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn);
        $display("2pc <= %h", pc + fnInsnLength(insn) + fnInsnLength1(insn) + fnInsnLength2(insn));
    end
end
`else
if (branchmiss|cmt_miss) begin
    if (branchmiss) begin
        $display("pc <= %h", misspc);
        pc <= misspc;
        fetchbuf <= 1'b0;
        fetchbufA_v <= 1'b0;
        fetchbufB_v <= 1'b0;
        fetchbufC_v <= 1'b0;
        fetchbufD_v <= 1'b0;
	end
	else begin
        $display("pc <= %h", misspc);
        pc <= cmt_miss_pc;
        fetchbuf <= 1'b0;
        fetchbufA_v <= 1'b0;
        fetchbufB_v <= 1'b0;
        fetchbufC_v <= 1'b0;
        fetchbufD_v <= 1'b0;
	end
end
else if (take_branch) begin
	if (fetchbuf == 1'b0) begin
		case ({fetchbufA_v,fetchbufB_v,fetchbufC_v,fetchbufD_v})
		4'b0000:
			begin
			    fetchCD();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
				fetchbuf <= 1'b1;
			end
		4'b0100:
			begin
			    fetchCD();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
				fetchbufB_v <= !queued1;
				if (queued1) begin
				    fetchbufB_instr <= 64'd0;
					fetchbuf <= 1'b1;
				end
				if (queued2|queued3)
				    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b0111:
			begin
				fetchbufB_v <= !queued1;
				if (queued1) begin
					fetchbuf <= 1'b1;
				    fetchbufB_instr <= 64'd0;
				end
				if (queued2|queued3)
                    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b1000:
			begin
			    fetchCD();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
				fetchbufA_v <= !queued1;
				if (queued1) begin
					fetchbuf <= 1'b1;
				    fetchbufA_instr <= 64'd0;
				end
				if (queued2|queued3)
                    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b1011:
			begin
				fetchbufA_v <= !queued1;
				if (queued1) begin
					fetchbuf <= 1'b1;
				    fetchbufB_instr <= 64'd0;
			    end
				if (queued2|queued3)
                    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b1100: 
			// Note that there is no point to loading C,D here because
			// there is a predicted taken branch that would stomp on the
			// instructions anyways.
			if ((fnIsBranch(opcodeA) && predict_takenA)||opcodeA==`LOOP) begin
				pc <= branch_pc;
				fetchbufA_v <= !(queued1|queued2);
				fetchbufB_v <= `INV;		// stomp on it
				// may as well stick with same fetchbuf
			end
			else begin
				if (did_branchback0) begin
				    fetchCD();
					if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
					fetchbufA_v <= !(queued1|queued2);
					fetchbufB_v <= !queued2;
					if (queued2)
						fetchbuf <= 1'b1;
				end
				else begin
					pc <= branch_pc;
					fetchbufA_v <= !(queued1|queued2);
					fetchbufB_v <= !queued2;
					// may as well keep the same fetchbuffer
				end
			end
		4'b1111:
			begin
				fetchbufA_v <= !(queued1|queued2);
				fetchbufB_v <= !queued2;
				if (queued2) begin
					fetchbuf <= 1'b1;
				    fetchbufA_instr <= 64'd0;
				    fetchbufB_instr <= 64'd0;
			    end
			end
		default: panic <= `PANIC_INVALIDFBSTATE;
		endcase
	end
	else begin	// fetchbuf==1'b1
		case ({fetchbufC_v,fetchbufD_v,fetchbufA_v,fetchbufB_v})
		4'b0000:
			begin
			    fetchAB();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
				fetchbuf <= 1'b0;
			end
		4'b0100:
			begin
			    fetchAB();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
				fetchbufD_v <= !queued1;
				if (queued1)
					fetchbuf <= 1'b0;
				if (queued2|queued3)
                    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b0111:
			begin
				fetchbufD_v <= !queued1;
				if (queued1)
					fetchbuf <= 1'b0;
				if (queued2|queued3)
                    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b1000:
			begin
			    fetchAB();
				if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
				fetchbufC_v <= !queued1;
				if (queued1)
					fetchbuf <= 1'b0;
				if (queued2|queued3)
                    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b1011:
			begin
				fetchbufC_v <= !queued1;
				if (queued1)
					fetchbuf <= 1'b0;
				if (queued2|queued3)
                    panic <= `PANIC_INVALIDIQSTATE;
			end
		4'b1100:
			if ((fnIsBranch(opcodeC) && predict_takenC)||opcodeC==`LOOP) begin
				pc <= branch_pc;
				fetchbufC_v <= !(queued1|queued2);
				fetchbufD_v <= `INV;		// stomp on it
				// may as well stick with same fetchbuf
			end
			else begin
				if (did_branchback1) begin
				    fetchAB();
					if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
					fetchbufC_v <= !(queued1|queued2);
					fetchbufD_v <= !queued2;
					if (queued2)
						fetchbuf <= 1'b0;
				end
				else begin
					pc <= branch_pc;
					fetchbufC_v <= !(queued1|queued2);
					fetchbufD_v <= !queued2;
					// may as well keep the same fetchbuffer
				end
			end
		4'b1111:
			begin
				fetchbufC_v <= !(queued1|queued2);
				fetchbufD_v <= !queued2;
				if (queued2)
					fetchbuf <= 1'b0;
			end
		default: panic <= `PANIC_INVALIDFBSTATE;
		endcase
	end
end
else begin
	if (fetchbuf == 1'b0)
		case ({fetchbufA_v, fetchbufB_v})
		2'b00: ;
		2'b01: begin
			fetchbufB_v <= !(queued2|queued1);
			fetchbuf <= queued2|queued1;
			end
		2'b10: begin
			fetchbufA_v <= !(queued2|queued1);
			fetchbuf <= queued2|queued1;
			end
		2'b11: begin
			fetchbufA_v <= !(queued1|queued2);
			fetchbufB_v <= !queued2;
			fetchbuf <= queued2;
			end
		endcase
	else
		case ({fetchbufC_v, fetchbufD_v})
		2'b00:    ;
		2'b01: begin
			fetchbufD_v <= !(queued2|queued1);
			fetchbuf <= !(queued2|queued1);
			end
		2'b10: begin
			fetchbufC_v <= !(queued2|queued1);
			fetchbuf <= !(queued2|queued1);
			end
		2'b11: begin
			fetchbufC_v <= !(queued2|queued1);
			fetchbufD_v <= !queued2;
			fetchbuf <= !queued2;
			end
		endcase
	if (fetchbufA_v == `INV && fetchbufB_v == `INV) begin
	    fetchAB();
		if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
		// fetchbuf steering logic correction
		if (fetchbufC_v==`INV && fetchbufD_v==`INV && do_pcinc)
			fetchbuf <= 1'b0;
		$display("hit %b 1pc <= %h", do_pcinc, pc + fnInsnLength(insn) + fnInsnLength1(insn));
	end
	else if (fetchbufC_v == `INV && fetchbufD_v == `INV) begin
	    fetchCD();
		if (do_pcinc) pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
		$display("2pc <= %h", pc + fnInsnLength(insn) + fnInsnLength1(insn));
	end
end
`endif
	if (ihit) begin
	$display("%h %h hit0=%b hit1=%b#", spc, pc, hit0, hit1);
	$display("insn=%h", insn);
	$display("%c insn0=%h insn1=%h", nmi_edge ? "*" : " ",insn0, insn1);
	$display("takb=%d br_pc=%h #", take_branch, branch_pc);
	$display("%c%c A: %d %h %h #",
	    45, fetchbuf?45:62, fetchbufA_v, fetchbufA_instr, fetchbufA_pc);
	$display("%c%c B: %d %h %h #",
	    45, fetchbuf?45:62, fetchbufB_v, fetchbufB_instr, fetchbufB_pc);
	$display("%c%c C: %d %h %h #",
	    45, fetchbuf?62:45, fetchbufC_v, fetchbufC_instr, fetchbufC_pc);
	$display("%c%c D: %d %h %h #",
	    45, fetchbuf?62:45, fetchbufD_v, fetchbufD_instr, fetchbufD_pc);
	$display("fetchbuf=%d",fetchbuf);
	end

//	if (ihit) begin
	for (i=0; i<QENTRIES; i=i+1) 
	    $display("%c%c %d: %c%c%c%c%c%c%c%c %d %c %c%h %d%s %h %h %h %c %o %h %c %o %h %c %o %h %c %o %h #",
		(i[2:0]==head0)?72:46, (i[2:0]==tail0)?84:46, i,
		iqentry_v[i]?"v":"-", iqentry_done[i]?"d":"-",
		iqentry_cmt[i]?"c":"-", iqentry_out[i]?"o":"-", iqentry_bt[i]?"b":"-", iqentry_memissue[i]?"m":"-",
		iqentry_agen[i]?"a":"-", iqentry_issue[i]?"i":"-",
		iqentry_islot[i],
//		((i==0) ? iqentry_0_islot : (i==1) ? iqentry_1_islot : (i==2) ? iqentry_2_islot : (i==3) ? iqentry_3_islot :
//		 (i==4) ? iqentry_4_islot : (i==5) ? iqentry_5_islot : (i==6) ? iqentry_6_islot : iqentry_7_islot),
		 iqentry_stomp[i] ? "s" : "-",
		(fnIsFlowCtrl(iqentry_op[i]) ? 98 : fnIsMem(iqentry_op[i]) ? 109 : 97), 
		iqentry_op[i],
		fnRegstr(iqentry_tgt[i]),fnRegstrGrp(iqentry_tgt[i]),
		iqentry_res[i], iqentry_a0[i],
		iqentry_a1[i], iqentry_a1_v[i]?"v":"-", iqentry_a1_s[i],
		iqentry_a2[i], iqentry_a2_v[i]?"v":"-", iqentry_a2_s[i],
		iqentry_a3[i], iqentry_a3_v[i]?"v":"-", iqentry_a3_s[i],
		iqentry_pred[i], iqentry_p_v[i]?"v":"-", iqentry_p_s[i],
		iqentry_pc[i]);
	$display("com0:%c%c %d r%d %h", commit0_v?"v":"-", iqentry_cmt[head0]?"c":"-", commit0_id, commit0_tgt, commit0_bus);
	$display("com1:%c%c %d r%d %h", commit1_v?"v":"-", iqentry_cmt[head1]?"c":"-", commit1_id, commit1_tgt, commit1_bus);
	
//	end
//`include "Thor_dataincoming.v"
// DATAINCOMING
//
// wait for operand/s to appear on alu busses and puts them into 
// the iqentry_a1 and iqentry_a2 slots (if appropriate)
// as well as the appropriate iqentry_res slots (and setting valid bits)
//
//
// put results into the appropriate instruction entries
//
if (alu0_v) begin
	if (|alu0_exc) begin
		iqentry_op [alu0_id[2:0] ] <= `INT;
		iqentry_cond [alu0_id[2:0]] <= 4'd1;		// always execute
		iqentry_mem[alu0_id[2:0]] <= `FALSE;
		iqentry_rfw[alu0_id[2:0]] <= `TRUE;			// writes to IPC
		iqentry_a0 [alu0_id[2:0]] <= alu0_exc;
		iqentry_p_v  [alu0_id[2:0]] <= `TRUE;
		iqentry_a1 [alu0_id[2:0]] <= cregs[4'hC];	// *** assumes BR12 is static
		iqentry_a1_v [alu0_id[2:0]] <= `TRUE;		// Flag arguments as valid
		iqentry_a2_v [alu0_id[2:0]] <= `TRUE;
		iqentry_a3_v [alu0_id[2:0]] <= `TRUE;
		iqentry_out [alu0_id[2:0]] <= `FALSE;
		iqentry_agen [alu0_id[2:0]] <= `FALSE;
		iqentry_tgt[alu0_id[2:0]] <= {1'b1,2'h1,4'hE};	// Target IPC
	end
	else begin
		if ((alu0_op==`RR && (alu0_fn==`MUL || alu0_fn==`MULU)) || alu0_op==`MULI || alu0_op==`MULUI) begin
			if (alu0_mult_done) begin
				iqentry_res	[ alu0_id[2:0] ] <= alu0_prod[63:0];
				iqentry_done[alu0_id[2:0]] <= `TRUE;
				iqentry_out	[ alu0_id[2:0] ] <= `FALSE;
			end
		end
		else if ((alu0_op==`RR && (alu0_fn==`DIV || alu0_fn==`DIVU)) || alu0_op==`DIVI || alu0_op==`DIVUI) begin
			if (alu0_div_done) begin
				iqentry_res	[ alu0_id[2:0] ] <= alu0_divq;
				iqentry_done[alu0_id[2:0]] <= `TRUE;
				iqentry_out	[ alu0_id[2:0] ] <= `FALSE;
			end
		end
		else
//		if (!iqentry_done[alu0_id[2:0]])
		begin    // <- this is a bit of a hack
			iqentry_res	[ alu0_id[2:0] ] <= alu0_bus;
			if (iqentry_op[alu0_id[2:0]]!=`IMM)
			    iqentry_done[ alu0_id[2:0] ] <= (!iqentry_mem[ alu0_id[2:0] ] || !alu0_cmt);
			iqentry_out	[ alu0_id[2:0] ] <= `FALSE;
		end
		iqentry_cmt [ alu0_id[2:0] ] <= alu0_cmt;
		
		if ((queued1|queued2)&&(tail0==alu0_id[2:0])) begin
//		     alu0_dataready <= `FALSE;
		     iqentry_agen[alu0_id[2:0]] <= `FALSE;
        end
		else if (queued2 && tail1==alu0_id[2:0]) begin
//		     alu0_dataready <= `FALSE;
		     iqentry_agen[alu0_id[2:0]] <= `FALSE;
        end
		else
		     iqentry_agen[ alu0_id[2:0] ] <= `TRUE;
//        iqentry_agen[ alu0_id[2:0] ] <= `TRUE;
		iqentry_out [ alu0_id[2:0] ] <= `FALSE;
	end
end

if (alu1_v) begin
	if (|alu1_exc) begin
		iqentry_op [alu1_id[2:0] ] <= `INT;
		iqentry_cond [alu1_id[2:0]] <= 4'd1;		// always execute
		iqentry_mem[alu1_id[2:0]] <= `FALSE;
		iqentry_rfw[alu1_id[2:0]] <= `TRUE;			// writes to IPC
		iqentry_a0 [alu1_id[2:0]] <= alu1_exc;
		iqentry_p_v  [alu1_id[2:0]] <= `TRUE;
		iqentry_a1 [alu1_id[2:0]] <= cregs[4'hC];	// *** assumes BR12 is static
		iqentry_a1_v [alu1_id[2:0]] <= `TRUE;		// Flag arguments as valid
		iqentry_a2_v [alu1_id[2:0]] <= `TRUE;
		iqentry_a3_v [alu1_id[2:0]] <= `TRUE;
		iqentry_out [alu1_id[2:0]] <= `FALSE;
		iqentry_agen [alu1_id[2:0]] <= `FALSE;
		iqentry_tgt[alu1_id[2:0]] <= {1'b1,2'h1,4'hE};	// Target IPC
	end
	else begin
		if (((alu1_op==`RR && (alu1_fn==`MUL || alu1_fn==`MULU)) || alu1_op==`MULI || alu1_op==`MULUI) && ALU1BIG) begin
			if (alu1_mult_done) begin
				iqentry_res	[ alu1_id[2:0] ] <= alu1_prod[63:0];
				iqentry_done[alu1_id[2:0]] <= `TRUE;
				iqentry_out	[ alu1_id[2:0] ] <= `FALSE;
			end
		end
		else if (((alu1_op==`RR && (alu1_fn==`DIV || alu1_fn==`DIVU)) || alu1_op==`DIVI || alu1_op==`DIVUI) && ALU1BIG) begin
			if (alu1_div_done) begin
				iqentry_res	[ alu1_id[2:0] ] <= alu1_divq;
				iqentry_done[alu1_id[2:0]] <= `TRUE;
				iqentry_out	[ alu1_id[2:0] ] <= `FALSE;
			end
		end
		else
//		if (!iqentry_done[alu1_id[2:0]]) 
		begin
			iqentry_res	[ alu1_id[2:0] ] <= alu1_bus;
			if (iqentry_op[alu1_id[2:0]]!=`IMM)
			     iqentry_done[ alu1_id[2:0] ] <= (!iqentry_mem[ alu1_id[2:0] ] || !alu1_cmt);
			iqentry_out	[ alu1_id[2:0] ] <= `FALSE;
		end
		iqentry_cmt [ alu1_id[2:0] ] <= alu1_cmt;
		// Force the agen bit to zero on a enqueue, even if the alu output is valid.
		if ((queued1|queued2)&&(tail0==alu1_id[2:0])) begin
//		     alu1_dataready <= `FALSE;
             iqentry_agen[alu1_id[2:0]] <= `FALSE;
        end
        else if (queued2 && tail1==alu1_id[2:0]) begin
//		     alu1_dataready <= `FALSE;
             iqentry_agen[alu1_id[2:0]] <= `FALSE;
        end
        else
             iqentry_agen[ alu1_id[2:0] ] <= `TRUE;
//		iqentry_agen[ alu1_id[2:0] ] <= `TRUE;
		iqentry_out [ alu1_id[2:0] ] <= `FALSE;
	end
end

`ifdef FLOATING_POINT
if (fp0_v) begin
	$display("0results to iq[%d]=%h", alu0_id[2:0],alu0_bus);
	if (|fp0_exc) begin
		iqentry_op [alu0_id[2:0] ] <= `INT;
		iqentry_cond [alu0_id[2:0]] <= 4'd1;		// always execute
		iqentry_mem[alu0_id[2:0]] <= `FALSE;
		iqentry_rfw[alu0_id[2:0]] <= `TRUE;			// writes to IPC
		iqentry_a0 [alu0_id[2:0]] <= fp0_exc;
		iqentry_a1 [alu0_id[2:0]] <= cregs[4'hC];	// *** assumes BR12 is static
		iqentry_p_v  [alu0_id[2:0]] <= `TRUE;
		iqentry_a1_v [alu0_id[2:0]] <= `TRUE;		// Flag arguments as valid
		iqentry_a2_v [alu0_id[2:0]] <= `TRUE;
		iqentry_a3_v [alu0_id[2:0]] <= `TRUE;
		iqentry_out [alu0_id[2:0]] <= `FALSE;
		iqentry_agen [alu0_id[2:0]] <= `FALSE;
		iqentry_tgt[alu0_id[2:0]] <= {1'b1,2'h1,4'hE};	// Target IPC
	end
	else begin
		iqentry_res	[ alu0_id[2:0] ] <= fp0_bus;
		iqentry_done[ alu0_id[2:0] ] <= fp0_done || !fp0_cmt;
		iqentry_out	[ alu0_id[2:0] ] <= `FALSE;
		iqentry_cmt [ alu0_id[2:0] ] <= fp0_cmt;
		iqentry_agen[ alu0_id[2:0] ] <= `TRUE;
	end
end
`endif

if (dram_v && iqentry_v[ dram_id[2:0] ] && iqentry_mem[ dram_id[2:0] ] ) begin	// if data for stomped instruction, ignore
	$display("dram results to iq[%d]=%h", dram_id[2:0],dram_bus);
	iqentry_res	[ dram_id[2:0] ] <= dram_bus;
	// If an exception occurred, stuff an interrupt instruction into the queue
	// slot. The instruction will re-issue as an ALU operation.
	if (|dram_exc) begin
		iqentry_op [dram_id[2:0] ] <= `INT;
		iqentry_cond [dram_id[2:0]] <= 4'd1;		// always execute
		iqentry_mem[dram_id[2:0]] <= `FALSE;		// It's no longer a memory op
		iqentry_rfw[dram_id[2:0]] <= `TRUE;			// writes to IPC
		iqentry_a0 [dram_id[2:0]] <= dram_exc==`EXC_DBE ? 8'hFB : 8'hF8;
		iqentry_p_v  [dram_id[2:0]] <= `TRUE;
		iqentry_a1 [dram_id[2:0]] <= cregs[4'hC];	// *** assumes BR12 is static
		iqentry_a1_v [dram_id[2:0]] <= `TRUE;		// Flag arguments as valid
		iqentry_a2_v [dram_id[2:0]] <= `TRUE;
		iqentry_a3_v [dram_id[2:0]] <= `TRUE;
		iqentry_out [dram_id[2:0]] <= `FALSE;
		iqentry_agen [dram_id[2:0]] <= `FALSE;
		iqentry_tgt[dram_id[2:0]] <= {1'b1,2'h1,4'hE};	// Target IPC
	end
	else begin
	    iqentry_cmt[dram_id[2:0]] <= `TRUE;
		iqentry_done[ dram_id[2:0] ] <= `TRUE;
		if (iqentry_op[dram_id[2:0]]==`STS && lc==64'd0) begin
			string_pc <= 64'd0;
		end
	end
end

// What if there's a databus error during the store ?
// set the IQ entry == DONE as soon as the SW is let loose to the memory system
//
if (dram0 == 2'd2 && fnIsStore(dram0_op) && dram0_op != `STS) begin
	if ((alu0_v && dram0_id[2:0] == alu0_id[2:0]) || (alu1_v && dram0_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
	iqentry_done[ dram0_id[2:0] ] <= `TRUE;
	iqentry_cmt [ dram0_id[2:0]] <= `TRUE;
	iqentry_out[ dram0_id[2:0] ] <= `FALSE;
end
if (dram1 == 2'd2 && fnIsStore(dram1_op) && dram1_op != `STS) begin
	if ((alu0_v && dram1_id[2:0] == alu0_id[2:0]) || (alu1_v && dram1_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
	iqentry_done[ dram1_id[2:0] ] <= `TRUE;
	iqentry_cmt [ dram1_id[2:0]] <= `TRUE;
	iqentry_out[ dram1_id[2:0] ] <= `FALSE;
end
if (dram2 == 2'd2 && fnIsStore(dram2_op) && dram2_op != `STS) begin
	if ((alu0_v && dram2_id[2:0] == alu0_id[2:0]) || (alu1_v && dram2_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
	iqentry_done[ dram2_id[2:0] ] <= `TRUE;
	iqentry_cmt [ dram2_id[2:0]] <= `TRUE;
	iqentry_out[ dram2_id[2:0] ] <= `FALSE;
end

//
// see if anybody else wants the results ... look at lots of buses:
//  - alu0_bus
//  - alu1_bus
//  - fp0_bus
//  - dram_bus
//  - commit0_bus
//  - commit1_bus
//

for (n = 0; n < QENTRIES; n = n + 1)
begin
	if (iqentry_p_v[n] == `INV && iqentry_p_s[n]==alu0_id && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
		iqentry_pred[n] <= alu0_bus[3:0];
		iqentry_p_v[n] <= `VAL;
	end
	if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == alu0_id && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
		iqentry_a1[n] <= alu0_bus;
		iqentry_a1_v[n] <= `VAL;
	end
	if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == alu0_id && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
		iqentry_a2[n] <= alu0_bus;
		iqentry_a2_v[n] <= `VAL;
	end
	if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == alu0_id && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
		iqentry_a3[n] <= alu0_bus;
		iqentry_a3_v[n] <= `VAL;
	end
	if (iqentry_p_v[n] == `INV && iqentry_p_s[n] == alu1_id && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
		iqentry_pred[n] <= alu1_bus[3:0];
		iqentry_p_v[n] <= `VAL;
	end
	if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == alu1_id && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
		iqentry_a1[n] <= alu1_bus;
		iqentry_a1_v[n] <= `VAL;
	end
	if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == alu1_id && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
		iqentry_a2[n] <= alu1_bus;
		iqentry_a2_v[n] <= `VAL;
	end
	if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == alu1_id && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
		iqentry_a3[n] <= alu1_bus;
		iqentry_a3_v[n] <= `VAL;
	end
`ifdef FLOATING_POINT
/*
	if (iqentry_p_v[n] == `INV && iqentry_p_s[n] == fp0_id && iqentry_v[n] == `VAL && fp0_v == `VAL) begin
		iqentry_pred[n] <= fp0_bus[3:0];
		iqentry_p_v[n] <= `VAL;
	end
*/
	if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == fp0_id && iqentry_v[n] == `VAL && fp0_v == `VAL) begin
		iqentry_a1[n] <= fp0_bus;
		iqentry_a1_v[n] <= `VAL;
	end
	if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == fp0_id && iqentry_v[n] == `VAL && fp0_v == `VAL) begin
		iqentry_a2[n] <= fp0_bus;
		iqentry_a2_v[n] <= `VAL;
	end
	if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == fp0_id && iqentry_v[n] == `VAL && fp0_v == `VAL) begin
		iqentry_a3[n] <= fp0_bus;
		iqentry_a3_v[n] <= `VAL;
	end
`endif
    // For SWCR
	if (iqentry_p_v[n] == `INV && iqentry_p_s[n]==dram_id && iqentry_v[n] == `VAL && dram_v == `VAL) begin
		iqentry_pred[n] <= dram_bus[3:0];
		iqentry_p_v[n] <= `VAL;
	end
	if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == dram_id && iqentry_v[n] == `VAL && dram_v == `VAL) begin
		iqentry_a1[n] <= dram_bus;
		iqentry_a1_v[n] <= `VAL;
	end
	if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == dram_id && iqentry_v[n] == `VAL && dram_v == `VAL) begin
		iqentry_a2[n] <= dram_bus;
		iqentry_a2_v[n] <= `VAL;
	end
	if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == dram_id && iqentry_v[n] == `VAL && dram_v == `VAL) begin
		iqentry_a3[n] <= dram_bus;
		iqentry_a3_v[n] <= `VAL;
	end
	if (iqentry_p_v[n] == `INV && iqentry_p_s[n]==commit0_id && iqentry_v[n] == `VAL && commit0_v == `VAL) begin
		iqentry_pred[n] <= commit0_bus[3:0];
		iqentry_p_v[n] <= `VAL;
	end
	if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == commit0_id && iqentry_v[n] == `VAL && commit0_v == `VAL) begin
		iqentry_a1[n] <= commit0_bus;
		iqentry_a1_v[n] <= `VAL;
	end
	if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == commit0_id && iqentry_v[n] == `VAL && commit0_v == `VAL) begin
		iqentry_a2[n] <= commit0_bus;
		iqentry_a2_v[n] <= `VAL;
	end
	if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == commit0_id && iqentry_v[n] == `VAL && commit0_v == `VAL) begin
		iqentry_a3[n] <= commit0_bus;
		iqentry_a3_v[n] <= `VAL;
	end
	if (iqentry_p_v[n] == `INV && iqentry_p_s[n] == commit1_id && iqentry_v[n] == `VAL && commit1_v == `VAL) begin
		iqentry_pred[n] <= commit1_bus[3:0];
		iqentry_p_v[n] <= `VAL;
	end
	if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == commit1_id && iqentry_v[n] == `VAL && commit1_v == `VAL) begin
		iqentry_a1[n] <= commit1_bus;
		iqentry_a1_v[n] <= `VAL;
	end
	if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == commit1_id && iqentry_v[n] == `VAL && commit1_v == `VAL) begin
		iqentry_a2[n] <= commit1_bus;
		iqentry_a2_v[n] <= `VAL;
	end
	if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == commit1_id && iqentry_v[n] == `VAL && commit1_v == `VAL) begin
		iqentry_a3[n] <= commit1_bus;
		iqentry_a3_v[n] <= `VAL;
	end
end

//`include "Thor_issue.v"
// ISSUE 
//
// determines what instructions are ready to go, then places them
// in the various ALU queues.  
// also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
//

alu0_dataready <= alu0_available 
			&& ((iqentry_issue[0] && iqentry_islot[0] == 4'd0 && !iqentry_stomp[0])
			 || (iqentry_issue[1] && iqentry_islot[1] == 4'd0 && !iqentry_stomp[1])
			 || (iqentry_issue[2] && iqentry_islot[2] == 4'd0 && !iqentry_stomp[2])
			 || (iqentry_issue[3] && iqentry_islot[3] == 4'd0 && !iqentry_stomp[3])
			 || (iqentry_issue[4] && iqentry_islot[4] == 4'd0 && !iqentry_stomp[4])
			 || (iqentry_issue[5] && iqentry_islot[5] == 4'd0 && !iqentry_stomp[5])
			 || (iqentry_issue[6] && iqentry_islot[6] == 4'd0 && !iqentry_stomp[6])
			 || (iqentry_issue[7] && iqentry_islot[7] == 4'd0 && !iqentry_stomp[7]));

alu1_dataready <= alu1_available 
			&& ((iqentry_issue[0] && iqentry_islot[0] == 4'd1 && !iqentry_stomp[0])
			 || (iqentry_issue[1] && iqentry_islot[1] == 4'd1 && !iqentry_stomp[1])
			 || (iqentry_issue[2] && iqentry_islot[2] == 4'd1 && !iqentry_stomp[2])
			 || (iqentry_issue[3] && iqentry_islot[3] == 4'd1 && !iqentry_stomp[3])
			 || (iqentry_issue[4] && iqentry_islot[4] == 4'd1 && !iqentry_stomp[4])
			 || (iqentry_issue[5] && iqentry_islot[5] == 4'd1 && !iqentry_stomp[5])
			 || (iqentry_issue[6] && iqentry_islot[6] == 4'd1 && !iqentry_stomp[6])
			 || (iqentry_issue[7] && iqentry_islot[7] == 4'd1 && !iqentry_stomp[7]));

`ifdef FLOATING_POINT
fp0_dataready <= 1'b1
			&& ((iqentry_fpissue[0] && iqentry_islot[0] == 4'd0 && !iqentry_stomp[0])
			 || (iqentry_fpissue[1] && iqentry_islot[1] == 4'd0 && !iqentry_stomp[1])
			 || (iqentry_fpissue[2] && iqentry_islot[2] == 4'd0 && !iqentry_stomp[2])
			 || (iqentry_fpissue[3] && iqentry_islot[3] == 4'd0 && !iqentry_stomp[3])
			 || (iqentry_fpissue[4] && iqentry_islot[4] == 4'd0 && !iqentry_stomp[4])
			 || (iqentry_fpissue[5] && iqentry_islot[5] == 4'd0 && !iqentry_stomp[5])
			 || (iqentry_fpissue[6] && iqentry_islot[6] == 4'd0 && !iqentry_stomp[6])
			 || (iqentry_fpissue[7] && iqentry_islot[7] == 4'd0 && !iqentry_stomp[7]));
`endif

for (n = 0; n < QENTRIES; n = n + 1)
begin
	if (iqentry_v[n] && iqentry_stomp[n]) begin
		iqentry_v[n] <= `INV;
		if (dram0_id[2:0] == n[2:0])	dram0 <= `DRAMSLOT_AVAIL;
		if (dram1_id[2:0] == n[2:0])	dram1 <= `DRAMSLOT_AVAIL;
		if (dram2_id[2:0] == n[2:0])	dram2 <= `DRAMSLOT_AVAIL;
	end
	else if (iqentry_issue[n]) begin
		case (iqentry_islot[n]) 
		2'd0: if (alu0_available) begin
			alu0_ld <= 1'b1;
			alu0_sourceid	<= n[3:0];
			alu0_insnsz <= iqentry_insnsz[n];
			alu0_op		<= iqentry_op[n];
			alu0_fn     <= iqentry_fn[n];
			alu0_cond   <= iqentry_cond[n];
			alu0_bt		<= iqentry_bt[n];
			alu0_pc		<= iqentry_pc[n];
			alu0_pred   <= iqentry_p_v[n] ? iqentry_pred[n] :
							(iqentry_p_s[n] == alu0_id) ? alu0_bus[3:0] :
							(iqentry_p_s[n] == alu1_id) ? alu1_bus[3:0] : 4'h0;
			alu0_argA	<= iqentry_a1_v[n] ? iqentry_a1[n]
						: (iqentry_a1_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a1_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			alu0_argB	<= iqentry_a2_v[n] ? iqentry_a2[n]
						: (iqentry_a2_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a2_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			alu0_argC	<= iqentry_mem[n] ? {sregs[iqentry_fn[n][5:3]],12'h000} :
			               iqentry_a3_v[n] ? iqentry_a3[n]
						: (iqentry_a3_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a3_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			alu0_argI	<= iqentry_a0[n];
			end
		2'd1: if (alu1_available) begin
			alu1_ld <= 1'b1;
			alu1_sourceid	<= n[3:0];
			alu1_insnsz <= iqentry_insnsz[n];
			alu1_op		<= iqentry_op[n];
			alu1_fn     <= iqentry_fn[n];
			alu1_cond   <= iqentry_cond[n];
			alu1_bt		<= iqentry_bt[n];
			alu1_pc		<= iqentry_pc[n];
			alu1_pred   <= iqentry_p_v[n] ? iqentry_pred[n] :
							(iqentry_p_s[n] == alu0_id) ? alu0_bus[3:0] :
							(iqentry_p_s[n] == alu1_id) ? alu1_bus[3:0] : 4'h0;
			alu1_argA	<= iqentry_a1_v[n] ? iqentry_a1[n]
						: (iqentry_a1_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a1_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			alu1_argB	<= iqentry_a2_v[n] ? iqentry_a2[n]
						: (iqentry_a2_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a2_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			alu1_argC	<= iqentry_mem[n] ? {sregs[iqentry_fn[n][5:3]],12'h000} : 
			               iqentry_a3_v[n] ? iqentry_a3[n]
						: (iqentry_a3_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a3_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			alu1_argI	<= iqentry_a0[n];
			end
		default: panic <= `PANIC_INVALIDISLOT;
		endcase
		iqentry_out[n] <= `TRUE;
		// if it is a memory operation, this is the address-generation step ... collect result into arg1
		if (iqentry_mem[n] && iqentry_op[n]!=`TLB) begin
			iqentry_a1_v[n] <= `INV;
			iqentry_a1_s[n] <= n[3:0];
		end
	end
end


`ifdef FLOATING_POINT
for (n = 0; n < QENTRIES; n = n + 1)
begin
	if (iqentry_v[n] && iqentry_stomp[n])
		;
	else if (iqentry_fpissue[n]) begin
		case (iqentry_fpislot[n]) 
		2'd0: if (1'b1) begin
			fp0_ld <= 1'b1;
			fp0_sourceid	<= n[3:0];
			fp0_op		<= iqentry_op[n];
			fp0_fn     <= iqentry_fn[n];
			fp0_cond   <= iqentry_cond[n];
			fp0_pred   <= iqentry_p_v[n] ? iqentry_pred[n] :
							(iqentry_p_s[n] == alu0_id) ? alu0_bus[3:0] :
							(iqentry_p_s[n] == alu1_id) ? alu1_bus[3:0] : 4'h0;
			fp0_argA	<= iqentry_a1_v[n] ? iqentry_a1[n]
						: (iqentry_a1_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a1_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			fp0_argB	<= iqentry_a2_v[n] ? iqentry_a2[n]
						: (iqentry_a2_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a2_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			fp0_argC	<= iqentry_a3_v[n] ? iqentry_a3[n]
						: (iqentry_a3_s[n] == alu0_id) ? alu0_bus
						: (iqentry_a3_s[n] == alu1_id) ? alu1_bus
						: 64'hDEADDEADDEADDEAD;
			fp0_argI	<= iqentry_a0[n];
			end
		default: panic <= `PANIC_INVALIDISLOT;
		endcase
		iqentry_out[n] <= `TRUE;
	end
end
`endif

// MEMORY
//
// update the memory queues and put data out on bus if appropriate
// Always puts data on the bus even for stores. In the case of
// stores, the data is ignored.
//
//
// dram0, dram1, dram2 are the "state machines" that keep track
// of three pipelined DRAM requests.  if any has the value "00", 
// then it can accept a request (which bumps it up to the value "01"
// at the end of the cycle).  once it hits the value "10" the request
// and the bus is acknowledged the dram request
// is finished and the dram_bus takes the value.  if it is a store, the 
// dram_bus value is not used, but the dram_v value along with the
// dram_id value signals the waiting memq entry that the store is
// completed and the instruction can commit.
//
if (tlb_state != 3'd0 && tlb_state < 3'd3)
	tlb_state <= tlb_state + 3'd1;
if (tlb_state==3'd3) begin
	dram_v <= `TRUE;
	dram_id <= tlb_id;
	dram_tgt <= tlb_tgt;
	dram_exc <= `EXC_NONE;
	dram_bus <= tlb_dato;
	tlb_op <= 4'h0;
	tlb_state <= 3'd0;
end

case(dram0)
// The first state is to translate the virtual to physical address.
3'd1:
	begin
		$display("0MEM %c:%h %h cycle started",fnIsLoad(dram0_op)?"L" : "S", dram0_addr, dram0_data);
        if (!cyc_o) dram0 <= dram0 + 3'd1;
	end

// State 2:
// Check for a TLB miss on the translated address, and
// Initiate a bus transfer
3'd2:
	if (DTLBMiss) begin
		dram_v <= `TRUE;			// we are finished the memory cycle
		dram_id <= dram0_id;
		dram_tgt <= dram0_tgt;
		dram_exc <= `EXC_TLBMISS;	//dram0_exc;
		dram_bus <= 64'h0;
		dram0 <= 3'd0;
	end
	else if (dram0_exc!=`EXC_NONE) begin
		dram_v <= `TRUE;			// we are finished the memory cycle
        dram_id <= dram0_id;
        dram_tgt <= dram0_tgt;
        dram_exc <= dram0_exc;
		dram_bus <= 64'h0;
        dram0 <= 3'd0;
	end
	else begin
	    if (dram0_op==`LCL) begin
	       if (dram0_tgt==7'd0) begin
	           ic_invalidate_line <= `TRUE;
	           ic_lineno <= dram0_addr;
	       end
           dram0 <= 3'd6;
	    end
		else if (uncached || fnIsStore(dram0_op) || fnIsLoadV(dram0_op) || dram0_op==`CAS ||
		  ((dram0_op==`STMV || dram0_op==`INC) && stmv_flag)) begin
    		if (cstate==IDLE) begin // make sure an instruction load isn't taking place
                dram0_owns_bus <= `TRUE;
                resv_o <= dram0_op==`LVWAR;
                cres_o <= dram0_op==`SWCR;
                lock_o <= dram0_op==`CAS;
                cyc_o <= 1'b1;
                stb_o <= 1'b1;
                we_o <= fnIsStore(dram0_op) || ((dram0_op==`STMV || dram0_op==`INC) && stmv_flag);
                sel_o <= fnSelect(dram0_op,dram0_fn,pea);
                rsel <= fnSelect(dram0_op,dram0_fn,pea);
                adr_o <= pea;
                if (dram0_op==`INC)
                    dat_o <= fnDatao(dram0_op,dram0_fn,dram0_data) + index;
                else
                    dat_o <= fnDatao(dram0_op,dram0_fn,dram0_data);
                dram0 <= dram0 + 3'd1;
			end
		end
		else begin	// cached read
			dram0 <= 3'd6;
            rsel <= fnSelect(dram0_op,dram0_fn,pea);
	   end
	end

// State 3:
// Wait for a memory ack
3'd3:
	if (ack_i|err_i) begin
		$display("MEM ack");
		dram_v <= dram0_op != `CAS && dram0_op != `INC && dram0_op != `STS && dram0_op != `STMV && dram0_op != `STCMP && dram0_op != `STFND;
		dram_id <= dram0_id;
		dram_tgt <= dram0_tgt;
		dram_exc <= (err_i & dram0_tgt!=7'd0) ? `EXC_DBE : `EXC_NONE;//dram0_exc;
		if (dram0_op==`SWCR)
		     dram_bus <= {63'd0,resv_i};
		else
		     dram_bus <= fnDatai(dram0_op,dram0_fn,dat_i,rsel);
		dram0_owns_bus <= `FALSE;
		wb_nack();
		dram0 <= 3'd7;
		case(dram0_op)
		`STS:
			if (lc != 0 && !int_pending) begin
			    dram0_owns_bus <= `TRUE;
				dram0_addr <= dram0_addr +
				    (dram0_fn[2:0]==3'd0 ? 64'd1 :
				    dram0_fn[2:0]==3'd1 ? 64'd2 :
				    dram0_fn[2:0]==3'd2 ? 64'd4 :
				    64'd8); 
				lc <= lc - 64'd1;
				dram0 <= 3'd1;
				dram_bus <= dram0_addr +
                    (dram0_fn[2:0]==3'd0 ? 64'd1 :
                    dram0_fn[2:0]==3'd1 ? 64'd2 :
                    dram0_fn[2:0]==3'd2 ? 64'd4 :
                    64'd8); 
            end
            else begin
                dram_bus <= dram0_addr;
                dram_v <= `VAL;
            end
        `STMV,`STCMP:
            if (lc != 0 && !(int_pending && stmv_flag)) begin 
                dram0 <= 3'd1;
			    dram0_owns_bus <= `TRUE;
                if (stmv_flag) begin
                    dram0_addr <= src_addr + index;
                    if (dram0_op==`STCMP) begin
                        if (dram0_data != fnDatai(dram0_op,dram0_fn,dat_i,rsel)) begin
                            lc <= 64'd0;
                            dram0 <= 3'd7;
                            dram_v <= `VAL;
                            dram_bus <= index;
                        end
                    end
                end               
                else begin
                    dram0_addr <= dst_addr + index;
                    dram0_data <= fnDatai(dram0_op,dram0_fn,dat_i,rsel);
                end
                if (!stmv_flag)
                    inc_index(dram0_fn);
                stmv_flag <= ~stmv_flag;
            end
            else begin
                dram_bus <= index;
                dram_v <= `VAL;
            end
        `STFND:
            if (lc != 0 && !int_pending) begin 
                dram0_addr <= src_addr + index;
                inc_index(dram0_fn);
                if (dram0_data == dram_bus) begin
                    lc <= 64'd0;
                    dram0 <= 3'd7;
                    dram_v <= `VAL;
                    dram_bus <= index;
                end
                else
                    dram0 <= 3'd1;
            end
            else begin
                dram_bus <= index;
                dram_v <= `VAL;
            end
        `CAS:
			if (dram0_datacmp == dat_i) begin
				$display("CAS match");
				dram0_owns_bus <= `TRUE;
				cyc_o <= 1'b1;	// hold onto cyc_o
				dram0 <= dram0 + 3'd1;
			end
			else
				dram_v <= `VAL;
		`INC:
		     begin
		         if (stmv_flag) begin
		             dram_v <= `VAL;
		         end
		         else begin
		             dram0_data <= fnDatai(dram0_op,dram0_fn,dat_i,rsel);
                     stmv_flag <= ~stmv_flag;
                     dram0 <= 3'd2;
		         end
		     end
		default:  ;
		endcase
	end

// State 4:
// Start a second bus transaction for the CAS instruction
3'd4:
	begin
		stb_o <= 1'b1;
		we_o <= 1'b1;
		sel_o <= fnSelect(dram0_op,dram0_fn,pea);
		adr_o <= pea;
		dat_o <= fnDatao(dram0_op,dram0_fn,dram0_data);
		dram0 <= dram0 + 3'd1;
	end

// State 5:
// Wait for a memory ack for the second bus transaction of a CAS
//
3'd5:
	if (ack_i|err_i) begin
        $display("MEM ack2");
        dram_v <= `VAL;
        dram_id <= dram0_id;
        dram_tgt <= dram0_tgt;
        dram_exc <= (err_i & dram0_tgt!=7'd0) ? `EXC_DBE : `EXC_NONE;
        dram0_owns_bus <= `FALSE;
        wb_nack();
        lock_o <= 1'b0;
        dram0 <= 3'd7;
    end

// State 6:
// Wait for a data cache read hit
3'd6:
	if (rhit && dram0_op!=`LCL) begin
	    case(dram0_op)
	    // The read portion of the STMV was just done, go back and do
	    // the write portion.
        `STMV:
           begin
               stmv_flag <= `TRUE;
               dram0_addr <= dst_addr + index;
               dram0_data <= fnDatai(dram0_op,dram0_fn,cdat,rsel);
               dram0 <= 3'd2;
           end
        `STCMP:
            if (lc != 0 && !int_pending && stmv_flag) begin
                dram0_addr <= src_addr + index;
                stmv_flag <= ~stmv_flag;
                if (dram0_data != dram_bus) begin
                    lc <= 64'd0;
                    dram0 <= 3'd7;
                    dram_v <= `VAL;
                    dram_bus <= index;
                end
            end
            else if (!stmv_flag) begin
                stmv_flag <= ~stmv_flag;
                dram0_addr <= dst_addr + index;
                dram0_data <= fnDatai(dram0_op,dram0_fn,cdat,rsel);
                dram0 <= 3'd2;
                inc_index(dram0_fn);
            end
            else begin
                dram_bus <= index;
                dram_v <= `VAL;
                dram0 <= 3'd7;
            end
        `STFND:
            if (lc != 0 && !int_pending) begin 
                dram0_addr <= src_addr + index;
                inc_index(dram0_fn);
                if (dram0_data == dram_bus) begin
                    lc <= 64'd0;
                    dram0 <= 3'd7;
                    dram_v <= `VAL;
                    dram_bus <= index;
                end
            end
            else begin
                dram_bus <= index;
                dram_v <= `VAL;
                dram0 <= 3'd7;
            end
		`INC:
             begin
                 dram0_data <= fnDatai(dram0_op,dram0_fn,cdat,rsel);
                 stmv_flag <= `TRUE;
                 dram0 <= 3'd2;
            end
    default: begin
            $display("Read hit [%h]",dram0_addr);
            dram_v <= `TRUE;
            dram_id <= dram0_id;
            dram_tgt <= dram0_tgt;
            dram_exc <= `EXC_NONE;
            dram_bus <= fnDatai(dram0_op,dram0_fn,cdat,rsel);
            dram0 <= 3'd0;
            end
        endcase
	end
3'd7:
    dram0 <= 3'd0;
endcase

//
// determine if the instructions ready to issue can, in fact, issue.
// "ready" means that the instruction has valid operands but has not gone yet
//
// Stores can only issue if there is no possibility of a change of program flow.
// That means no flow control operations or instructions that can cause an
// exception can be before the store.
iqentry_memissue[ head0 ] <= iqentry_memissue_head0;
iqentry_memissue[ head1 ] <= iqentry_memissue_head1;
iqentry_memissue[ head2 ] <= iqentry_memissue_head2;
iqentry_memissue[ head3 ] <= iqentry_memissue_head3;
iqentry_memissue[ head4 ] <= iqentry_memissue_head4;
iqentry_memissue[ head5 ] <= iqentry_memissue_head5;
iqentry_memissue[ head6 ] <= iqentry_memissue_head6;
iqentry_memissue[ head7 ] <= iqentry_memissue_head7;
	
				/* ||
					(   !fnIsFlowCtrl(iqentry_op[head0])
					 && !fnIsFlowCtrl(iqentry_op[head1])
					 && !fnIsFlowCtrl(iqentry_op[head2])
					 && !fnIsFlowCtrl(iqentry_op[head3])
					 && !fnIsFlowCtrl(iqentry_op[head4])
					 && !fnIsFlowCtrl(iqentry_op[head5])
					 && !fnIsFlowCtrl(iqentry_op[head6])));
*/
//
// take requests that are ready and put them into DRAM slots

if (dram0 == `DRAMSLOT_AVAIL)	dram0_exc <= `EXC_NONE;

// Memory should also wait until segment registers are valid. The segment
// registers are essentially static registers while a program runs. They are
// setup by only the operating system. The system software must ensure the
// segment registers are stable before they get used. We don't bother checking
// for rf_v[].
//
for (n = 0; n < QENTRIES; n = n + 1)
	if (!iqentry_stomp[n] && iqentry_memissue[n] && iqentry_agen[n] && iqentry_op[n]==`TLB && !iqentry_out[n]) begin
	    $display("TLB issue");
	    if (!iq_cmt[n]) begin
	        iqentry_cmt[n] <= `FALSE;
	        iqentry_done[n] <= `TRUE;
	        iqentry_out[n] <= `FALSE;
	        iqentry_agen[n] <= `FALSE;
	    end
		else if (tlb_state==3'd0) begin
			tlb_state <= 3'd1;
			tlb_id <= {1'b1, n[2:0]};
			tlb_op <= iqentry_a0[n][3:0];
			tlb_regno <= iqentry_a0[n][7:4];
			tlb_tgt <= iqentry_tgt[n];
			tlb_data <= iqentry_a1[n];
			iqentry_out[n] <= `TRUE;
		end
	end
	else if (!iqentry_stomp[n] && iqentry_memissue[n] && iqentry_agen[n] && !iqentry_out[n]) begin
	    if (!iq_cmt[n]) begin
            iqentry_cmt[n] <= `FALSE;
            iqentry_done[n] <= `TRUE;
            iqentry_out[n] <= `FALSE;
            iqentry_agen[n] <= `FALSE;
        end
        else begin
            if (fnIsStoreString(iqentry_op[n]))
                string_pc <= iqentry_pc[n];
            $display("issued memory cycle");
            if (dram0 == `DRAMSLOT_AVAIL) begin
                dram0 		<= 3'd1;
                dram0_id 	<= { 1'b1, n[2:0] };
                dram0_op 	<= iqentry_op[n];
                dram0_fn    <= iqentry_fn[n];
                dram0_tgt 	<= iqentry_tgt[n];
                dram0_data	<= (fnIsIndexed(iqentry_op[n]) || iqentry_op[n]==`CAS) ? iqentry_a3[n] : iqentry_a2[n];
                dram0_datacmp <= iqentry_a2[n];
`ifdef SEGMENTATION
                dram0_addr <= iqentry_a1[n];
                src_addr <= iqentry_a1[n] + {sregs[iqentry_fn[n][5:3]],12'h000};
                dst_addr <= iqentry_a2[n] + {sregs[iqentry_fn[n][5:3]],12'h000};
`else
                dram0_addr <= iqentry_a1[n];
                src_addr <= iqentry_a1[n];
                dst_addr <= iqentry_a2[n];
`endif
                stmv_flag <= `FALSE;
                index <= iqentry_op[n]==`INC ? iqentry_a2[n] : iqentry_a3[n];
                iqentry_out[n]	<= `TRUE;
            end
		end
	end

for (n = 0; n < QENTRIES; n = n + 1)
begin
    if (iqentry_op[n]==`IMM && iqentry_v[(n+1)&7] && iqentry_pc[(n+1)&7]==iqentry_pc[n]+iqentry_insnsz[n])
        iqentry_done[n] <= `TRUE;
    if (iqentry_v[n] && args_valid[n] && !iqentry_out[n] && !iq_cmt[n] && iqentry_op[n]!=`IMM)
        iqentry_done[n] <= `TRUE;
    if (!iqentry_v[n])
        iqentry_done[n] <= `FALSE;
/*
    if (iqentry_v[n] && !iqentry_done[n]) begin
        if (!iqentry_a1_v[n] && iqentry_v[iqentry_a1_s[n][2:0]] && iqentry_done[iqentry_a1_s[n][2:0]]) begin
            iqentry_a1_v[n] <= `VAL;
            iqentry_a1[n] <= iqentry_res[iqentry_a1_s[n][2:0]];
        end 
        if (!iqentry_a2_v[n] && iqentry_v[iqentry_a2_s[n][2:0]] && iqentry_done[iqentry_a2_s[n][2:0]]) begin
            iqentry_a2_v[n] <= `VAL;
            iqentry_a2[n] <= iqentry_res[iqentry_a2_s[n][2:0]];
        end 
        if (!iqentry_a3_v[n] && iqentry_v[iqentry_a3_s[n][2:0]] && iqentry_done[iqentry_a3_s[n][2:0]]) begin
            iqentry_a3_v[n] <= `VAL;
            iqentry_a3[n] <= iqentry_res[iqentry_a3_s[n][2:0]];
        end 
    end
*/
end
        

//	$display("TLB: en=%b imatch=%b pgsz=%d pcs=%h phys=%h", utlb1.TLBenabled,utlb1.IMatch,utlb1.PageSize,utlb1.pcs,utlb1.IPFN);
//	for (i = 0; i < 64; i = i + 1)
//		$display("vp=%h G=%b",utlb1.TLBVirtPage[i],utlb1.TLBG[i]);
//`include "Thor_commit.v"
// It didn't work in simulation when the following was declared under an
// independant always clk block
//
    // Special purpose registers commit only at head0 to reduce the amount of
    // logic required. Since they are rarely used performance isn't likely
    // to be affected.
    commit_spr(commit0_v,commit0_tgt,commit0_bus);
    commit_spr(commit1_v,commit1_tgt,commit1_bus);
    
// When the INT instruction commits set the hardware interrupt status to disable further interrupts.
if (int_commit)
begin
	$display("*********************");
	$display("*********************");
	$display("Interrupt committing");
	$display("*********************");
	$display("*********************");
	StatusHWI <= `TRUE;
	imb <= im;
	im <= 1'b0;
	// Reset the nmi edge sense circuit but only for an NMI
	if ((iqentry_a0[head0][7:0]==8'hFE && commit0_v && iqentry_op[head0]==`INT) ||
	    (iqentry_a0[head1][7:0]==8'hFE && commit1_v && iqentry_op[head1]==`INT))
		nmi_edge <= 1'b0;
	string_pc <= 64'd0;
end

if (sys_commit)
begin
	if (StatusEXL!=8'hFF)
		StatusEXL <= StatusEXL + 8'd1;
end

oddball_commit(commit0_v,head0);
oddball_commit(commit1_v,head1);

//
// COMMIT PHASE (dequeue only ... not register-file update)
//
// If the third instruction is invalidated or if it doesn't update the register
// file then it is allowed to commit too.
// The head pointer might advance by three.
//
if (~|panic)
casex ({ iqentry_v[head0],
	iqentry_done[head0],
	iqentry_v[head1],
	iqentry_done[head1],
	iqentry_v[head2],
	iqentry_done[head2]})

	// retire 3
	6'b0x_0x_0x:
		if (head0 != tail0 && head1 != tail0 && head2 != tail0) begin
		    head_inc(3);
		end
		else if (head0 != tail0 && head1 != tail0) begin
 		    head_inc(2);
		end
		else if (head0 != tail0) begin
		    head_inc(1);
		end

	// retire 2 (wait for regfile for head2)
	6'b0x_0x_10:
		begin
		    head_inc(2);
		end

	// retire 2 or 3 (wait for regfile for head2)
	6'b0x_0x_11:
	   begin
	        if (iqentry_tgt[head2]==7'd0) begin
	            iqentry_v[head2] <= `INV;
	            head_inc(3);
	        end
	        else begin
	            head_inc(2);
			end
		end

	// retire 3
	6'b0x_11_0x:
		if (head1 != tail0 && head2 != tail0) begin
			iqentry_v[head1] <= `INV;
			head_inc(3);
		end
		else begin
			iqentry_v[head1] <= `INV;
			head_inc(2);
		end

	// retire 2	(wait on head2 or wait on register file for head2)
	6'b0x_11_10:
		begin
			iqentry_v[head1] <= `INV;
			head_inc(2);
		end
	6'b0x_11_11:
        begin
            if (iqentry_tgt[head2]==7'd0) begin
                iqentry_v[head1] <= `INV;
                iqentry_v[head2] <= `INV;
                head_inc(3);
            end
            else begin
                iqentry_v[head1] <= `INV;
                head_inc(2);
            end
        end

	// 4'b00_00	- neither valid; skip both
	// 4'b00_01	- neither valid; skip both
	// 4'b00_10	- skip head0, wait on head1
	// 4'b00_11	- skip head0, commit head1
	// 4'b01_00	- neither valid; skip both
	// 4'b01_01	- neither valid; skip both
	// 4'b01_10	- skip head0, wait on head1
	// 4'b01_11	- skip head0, commit head1
	// 4'b10_00	- wait on head0
	// 4'b10_01	- wait on head0
	// 4'b10_10	- wait on head0
	// 4'b10_11	- wait on head0
	// 4'b11_00	- commit head0, skip head1
	// 4'b11_01	- commit head0, skip head1
	// 4'b11_10	- commit head0, wait on head1
	// 4'b11_11	- commit head0, commit head1

	//
	// retire 0 (stuck on head0)
	6'b10_xx_xx:	;
	
	// retire 3
	6'b11_0x_0x:
		if (head1 != tail0 && head2 != tail0) begin
			iqentry_v[head0] <= `INV;
			head_inc(3);
		end
		else if (head1 != tail0) begin
			iqentry_v[head0] <= `INV;
			head_inc(2);
		end
		else begin
			iqentry_v[head0] <= `INV;
			head_inc(1);
		end

	// retire 2 (wait for regfile for head2)
	6'b11_0x_10:
		begin
			iqentry_v[head0] <= `INV;
			head_inc(2);
		end

	// retire 2 or 3 (wait for regfile for head2)
	6'b11_0x_11:
	    if (iqentry_tgt[head2]==7'd0) begin
			iqentry_v[head0] <= `INV;
			iqentry_v[head2] <= `INV;
			head_inc(3);
	    end
	    else begin
			iqentry_v[head0] <= `INV;
			head_inc(2);
		end

	//
	// retire 1 (stuck on head1)
	6'b00_10_xx,
	6'b01_10_xx,
	6'b11_10_xx:
		if (iqentry_v[head0] || head0 != tail0) begin
    	    iqentry_v[head0] <= `INV;
    	    head_inc(1);
		end

	// retire 2 or 3
	6'b11_11_0x:
		if (head2 != tail0) begin
			iqentry_v[head0] <= `INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			iqentry_v[head1] <= `INV;
			head_inc(3);
		end
		else begin
			iqentry_v[head0] <= `INV;
			iqentry_v[head1] <= `INV;
			head_inc(2);
		end

	// retire 2 (wait on regfile for head2)
	6'b11_11_10:
		begin
			iqentry_v[head0] <= `INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			iqentry_v[head1] <= `INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			head_inc(2);
		end
	6'b11_11_11:
	    if (iqentry_tgt[head2]==7'd0) begin
            iqentry_v[head0] <= `INV;    // may conflict with STOMP, but since both are setting to 0, it is okay
            iqentry_v[head1] <= `INV;    // may conflict with STOMP, but since both are setting to 0, it is okay
            iqentry_v[head2] <= `INV;    // may conflict with STOMP, but since both are setting to 0, it is okay
            head_inc(3);
	    end
        else begin
            iqentry_v[head0] <= `INV;    // may conflict with STOMP, but since both are setting to 0, it is okay
            iqentry_v[head1] <= `INV;    // may conflict with STOMP, but since both are setting to 0, it is okay
            head_inc(2);
        end
endcase

	if (branchmiss)
		rrmapno <= iqentry_renmapno[missid];

	case(cstate)
	RESET1:
	   begin
	       ic_ld <= `TRUE;
	       ic_ld_cntr <= 32'd0;
	       cstate <= RESET2;
	   end
	RESET2:
	   begin
	       ic_ld_cntr <= ic_ld_cntr + 32'd32;
	       if (ic_ld_cntr >= 32'd32768) begin
	           ic_ld <= `FALSE;
	           ic_ld_cntr <= 32'd0;
	           cstate <= IDLE;
	       end;
	   end
	IDLE:
		if (dcache_access_pending) begin
				$display("********************");
				$display("DCache access to: %h",{pea[DBW-1:5],5'b00000});
				$display("********************");
				derr <= 1'b0;
				bte_o <= 2'b00;
				cti_o <= 3'b001;
				bl_o <= DBW==32 ? 5'd7 : 5'd3;
				cyc_o <= 1'b1;
				stb_o <= 1'b1;
				we_o <= 1'b0;
				sel_o <= {DBW/8{1'b1}};
				adr_o <= {pea[DBW-1:5],5'b00000};
				dat_o <= {DBW{1'b0}};
				cstate <= DCACHE1;
		end
		else if ((!ihit && !mem_issue && dram0==3'd0)||(dram0==3'd6 && (dram0_op==`LCL && dram0_tgt==7'd0))) begin
			if ((dram0!=2'd0 || dram1!=2'd0 || dram2!=2'd0) && !(dram0==3'd6 && (dram0_op==`LCL && dram0_tgt==7'd0)))
				$display("drams non-zero");
			else begin
				$display("********************");
				$display("ICache access to: %h",
				    (dram0==3'd6 && (dram0_op==`LCL && dram0_tgt==7'd0)) ? {dram0_addr[ABW-1:5],5'h00} : 
				    !hit0 ? {ppc[DBW-1:5],5'b00000} : {ppcp16[DBW-1:5],5'b00000});
				$display("********************");
				ierr <= 1'b0;
				bte_o <= 2'b00;
				cti_o <= 3'b001;
				bl_o <= DBW==32 ? 5'd7 : 5'd3;
				cyc_o <= 1'b1;
				stb_o <= 1'b1;
				we_o <= 1'b0;
				sel_o <= {DBW/8{1'b1}};
				adr_o <= (dram0==3'd6 && (dram0_op==`LCL && dram0_tgt==7'd0)) ? {dram0_addr[ABW-1:5],5'h00} : !hit0 ? {ppc[DBW-1:5],5'b00000} : {ppcp16[DBW-1:5],5'b00000};
				dat_o <= {DBW{1'b0}};
				cstate <= ICACHE1;
			end
		end
	ICACHE1:
		begin
			if (ack_i|err_i) begin
				ierr <= ierr | err_i;	// cumulate an error status
				if (DBW==32) begin
					adr_o[4:2] <= adr_o[4:2] + 3'd1;
					if (adr_o[4:2]==3'b110)
						cti_o <= 3'b111;
					if (adr_o[4:2]==3'b111) begin
						wb_nack();
						cstate <= IDLE;
						if (dram0==3'd6 && dram0_op==`LCL) begin
						     dram0_op<=`NOP;
						end
					end
				end
				else begin
					adr_o[4:3] <= adr_o[4:3] + 2'd1;
					if (adr_o[4:3]==2'b10)
						cti_o <= 3'b111;
					if (adr_o[4:3]==2'b11) begin
						wb_nack();
						cstate <= IDLE;
						if (dram0==3'd6 && dram0_op==`LCL) begin
                             dram0_op<=`NOP;
                        end
					end
				end
			end
		end
	DCACHE1:
		begin
			if (ack_i|err_i) begin
				derr <= derr | err_i;	// cumulate an error status
				if (DBW==32) begin
					adr_o[4:2] <= adr_o[4:2] + 3'd1;
					if (adr_o[4:2]==3'b110)
						cti_o <= 3'b111;
					if (adr_o[4:2]==3'b111) begin
						wb_nack();
						cstate <= IDLE;
						if (dram0_op==`LCL) begin
						    dram0_op <= `NOP;
						    dram0_tgt <= 7'd0;
						end
					end
				end
				else begin
					adr_o[4:3] <= adr_o[4:3] + 2'd1;
					if (adr_o[4:3]==2'b10)
						cti_o <= 3'b111;
					if (adr_o[4:3]==2'b11) begin
						wb_nack();
						cstate <= IDLE;
						if (dram0_op==`LCL) begin
						    dram0_op <= `NOP;
						    dram0_tgt <= 7'd0;
					    end
					end
				end
			end
		end
    default:    cstate <= IDLE;
	endcase

//	for (i=0; i<8; i=i+1)
//	    $display("%d: %h %d %o #", i, urf1.regs0[i], rf_v[i], rf_source[i]);

	if (ihit) begin
	$display("dr=%d I=%h A=%h B=%h op=%c%d bt=%d src=%o pc=%h #",
		alu0_dataready, alu0_argI, alu0_argA, alu0_argB, 
		 (fnIsFlowCtrl(alu0_op) ? 98 : (fnIsMem(alu0_op)) ? 109 : 97),
		alu0_op, alu0_bt, alu0_sourceid, alu0_pc);
	$display("dr=%d I=%h A=%h B=%h op=%c%d bt=%d src=%o pc=%h #",
		alu1_dataready, alu1_argI, alu1_argA, alu1_argB, 
		 (fnIsFlowCtrl(alu1_op) ? 98 : (fnIsMem(alu1_op)) ? 109 : 97),
		alu1_op, alu1_bt, alu1_sourceid, alu1_pc);
	$display("v=%d bus=%h id=%o 0 #", alu0_v, alu0_bus, alu0_id);
	$display("bmiss0=%b src=%o mpc=%h #", alu0_branchmiss, alu0_sourceid, alu0_misspc); 
	$display("cmt=%b cnd=%d prd=%d", alu0_cmt, alu0_cond, alu0_pred);
	$display("bmiss1=%b src=%o mpc=%h #", alu1_branchmiss, alu1_sourceid, alu1_misspc); 
	$display("cmt=%b cnd=%d prd=%d", alu1_cmt, alu1_cond, alu1_pred);
	$display("bmiss=%b mpc=%h", branchmiss, misspc);

	$display("0: %d %h %o 0%d #", commit0_v, commit0_bus, commit0_id, commit0_tgt);
	$display("1: %d %h %o 0%d #", commit1_v, commit1_bus, commit1_id, commit1_tgt);
	end
	if (|panic) begin
	    $display("");
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("---------------     PANIC:%s     -----------------", message[panic]);
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("");
	    $display("instructions committed: %d", I);
	    $display("total execution cycles: %d", $time / 10);
	    $display("");
	end
	if (|panic && ~outstanding_stores) begin
	    $finish;
	end
end

task wb_nack;
begin
    resv_o <= 1'b0;
    cres_o <= 1'b0;
	bte_o <= 2'b00;
	cti_o <= 3'b000;
	bl_o <= 5'd0;
	cyc_o <= 1'b0;
	stb_o <= 1'b0;
	we_o <= 1'b0;
	sel_o <= 8'h00;
	adr_o <= {DBW{1'b0}};
	dat_o <= {DBW{1'b0}};
end
endtask

task commit_spr;
input commit_v;
input [6:0] commit_tgt;
input [DBW-1:0] commit_bus;
begin
if (commit_v && commit_tgt[6]) begin
    casex(commit_tgt[5:0])
    6'b00xxxx:  begin
                pregs[commit_tgt[3:0]] <= commit_bus[3:0];
	            $display("pregs[%d]<=%h", commit_tgt[3:0], commit_bus[3:0]);
//	            $stop;
                end
    6'b01xxxx:  begin
                cregs[commit_tgt[3:0]] <= commit_bus;
	            $display("cregs[%d]<=%h", commit_tgt[3:0], commit_bus);
	           end
`ifdef SEGMENTATION    
    6'b100xxx:  begin
                sregs[commit_tgt[2:0]] <= commit_bus[DBW-1:12];
	            $display("sregs[%d]<=%h", commit_tgt[2:0], commit_bus);
	            end
`endif
    6'b110000:
        begin
        pregs[0] <= commit_bus[3:0];
        pregs[1] <= commit_bus[7:4];
        pregs[2] <= commit_bus[11:8];
        pregs[3] <= commit_bus[15:12];
        pregs[4] <= commit_bus[19:16];
        pregs[5] <= commit_bus[23:20];
        pregs[6] <= commit_bus[27:24];
        pregs[7] <= commit_bus[31:28];
        if (DBW==64) begin
            pregs[8] <= commit_bus[35:32];
            pregs[9] <= commit_bus[39:36];
            pregs[10] <= commit_bus[43:40];
            pregs[11] <= commit_bus[47:44];
            pregs[12] <= commit_bus[51:48];
            pregs[13] <= commit_bus[55:52];
            pregs[14] <= commit_bus[59:56];
            pregs[15] <= commit_bus[63:60];
        end
        end
    `LCTR:  begin    lc <= commit_bus; $display("LC <= %h", commit_bus); end
	`ASID:	    asid <= commit_bus;
    `SR:    begin
            GM <= commit_bus[7:0];
            GMB <= commit_bus[23:16];
            imb <= commit_bus[31];
            im <= commit_bus[15];
            fxe <= commit_bus[12];
            end
    6'b111111:
            begin
                ld_clk_throttle <= `TRUE;
                clk_throttle_new <= commit_bus[15:0];
            end
    endcase
end
end
endtask

// For string memory operations.
//
task inc_index;
input [5:0] fn;
begin
    case(fn[2:0])
    3'd0:   index <= index + 64'd1;
    3'd1:   index <= index + 64'd2;
    3'd2:   index <= index + 64'd4;
    3'd3:   index <= index + 64'd8;
    3'd4:   index <= index - 64'd1;
    3'd5:   index <= index - 64'd2;
    3'd6:   index <= index - 64'd4;
    3'd7:   index <= index - 64'd8;
    endcase
    lc <= lc - 64'd1;    
end
endtask

function [DBW-1:0] fnSpr;
input [5:0] regno;
input [63:0] epc;
begin
    // Read from the special registers unless overridden by the
    // value on the commit bus.
    casex(regno)
    6'b00xxxx:  fnSpr = pregs[regno[3:0]];
    6'b01xxxx:  fnSpr = cregs[regno[3:0]];
    6'b100xxx:  fnSpr = sregs[regno[2:0]];
    6'b110000:  if (DBW==64)
                fnSpr = {pregs[15],pregs[14],pregs[13],pregs[12],
                         pregs[11],pregs[10],pregs[9],pregs[8],
                         pregs[7],pregs[6],pregs[5],pregs[4],
                         pregs[3],pregs[2],pregs[1],pregs[0]};
                else
                fnSpr = {pregs[7],pregs[6],pregs[5],pregs[4],
                         pregs[3],pregs[2],pregs[1],pregs[0]};
    `TICK:      fnSpr = tick;                    
    `LCTR:      fnSpr = lc;
    `ASID:      fnSpr = asid; 
    `SR:    begin
            fnSpr[7:0] = GM;
            fnSpr[23:16] = GMB;
            fnSpr[31] = imb;
            fnSpr[15] = im;
            fnSpr[12] = fxe;
            end
    default:    fnSpr = 64'd0;
    endcase
    
    // If an spr is committing...
    if (commit0_v && commit0_tgt=={1'b1,regno})
        fnSpr = commit0_bus;
    if (commit1_v && commit1_tgt=={1'b1,regno})
            fnSpr = commit1_bus;
 
    // Special cases where the register would not be read from the commit bus
    case(regno)
    `TICK:      fnSpr = tick;
    6'b010000:  fnSpr = 64'd0;  // code address zero
    6'b011111:  fnSpr = epc;    // current program counter from fetchbufx_pc
    default:    ;
    endcase
end
endfunction

// "oddball" instruction commit cases.
//
task oddball_commit;
input commit_v;
input [2:0] head;
begin
    if (commit_v)
        case(iqentry_op[head])
        `CLI:	im <= 1'b0;
        `SEI:	im <= 1'b1;
        // When the RTI instruction commits clear the hardware interrupt status to enable interrupts.
        `RTI:	begin
                StatusHWI <= `FALSE;
                im <= imb;
                end
        `RTE:	begin
                    if (StatusEXL!=8'h00)
                        StatusEXL <= StatusEXL - 8'd1;
                end
        `CACHE:
               begin
                   case(iqentry_fn[head])
                   6'd0:   ic_invalidate <= `TRUE;
                   6'd1:   begin
                           ic_invalidate_line <= `TRUE;
                           ic_lineno <= iqentry_a1[head]  + {sregs[3'd7],12'h000};
                           end
                   6'd32:  dc_invalidate <= `TRUE;
                   6'd33:  begin
                           dc_invalidate_line <= `TRUE;
                           dc_lineno <= iqentry_a1[head] + {sregs[iqentry_fn[head][5:3]],12'h000};
                           end
                   default: ;   // do nothing
                   endcase
               end
        default:	;
        endcase
end
endtask

// enque 0 on tail0 or tail1
task enque0;
input [2:0] tail;
input [2:0] inc;
input test_stomp;
input validate_args;
begin
    if (opcode0==`NOP)
        queued1 = `TRUE;    // to update fetch buffers
    else if (iqentry_v[tail] == `INV) begin
        if ((({fnIsBranch(opcode0), predict_taken0} == {`TRUE, `TRUE})||(opcode0==`LOOP)) && test_stomp)
            qstomp = `TRUE;
        iqentry_v    [tail]    <=   `VAL;
        iqentry_done [tail]    <=   `INV;
        iqentry_cmt  [tail]    <=   `TRUE;
        iqentry_out  [tail]    <=   `INV;
        iqentry_res  [tail]    <=   `ZERO;
        iqentry_insnsz[tail]   <=  fnInsnLength(fetchbuf0_instr);
        iqentry_op   [tail]    <=   opcode0; 
        iqentry_fn   [tail]    <=   opcode0==`MLO ? rfoc0[5:0] : fnFunc(fetchbuf0_instr);
        iqentry_cond [tail]    <=   cond0;
        iqentry_bt   [tail]    <=   fnIsFlowCtrl(opcode0) && predict_taken0; 
        iqentry_agen [tail]    <=   `INV;
        iqentry_pc   [tail]    <=   
            (opcode0==`INT && iqentry_op[tail0-3'd1]==`IMM && iqentry_v[tail-3'd1]==`VAL) ? (string_pc != 0 ? string_pc :
                iqentry_pc[tail-3'd1]) : fetchbuf0_pc;
        iqentry_mem  [tail]    <=   fetchbuf0_mem;
        iqentry_jmp  [tail]    <=   fetchbuf0_jmp;
        iqentry_fp   [tail]    <=   fetchbuf0_fp;
        iqentry_rfw  [tail]    <=   fetchbuf0_rfw;
        iqentry_tgt  [tail]    <=   Rt0;
        iqentry_pred [tail]    <=   pregs[Pn0];
        // Look at the previous queue slot to see if an immediate prefix is enqueued
        iqentry_a0[tail]   <=      opcode0==`INT ? fnImm(fetchbuf0_instr) :
                                    fnIsBranch(opcode0) ? {{DBW-12{fetchbuf0_instr[11]}},fetchbuf0_instr[11:8],fetchbuf0_instr[23:16]} : 
                                    iqentry_op[tail-3'd1]==`IMM && iqentry_v[tail-3'd1] ? {iqentry_a0[tail-3'd1][DBW-1:8],fnImm8(fetchbuf0_instr)}:
                                    opcode0==`IMM ? fnImmImm(fetchbuf0_instr) :
                                    fnImm(fetchbuf0_instr);
        iqentry_a1   [tail]    <=   fnOpa(opcode0,fetchbuf0_instr,rfoa0,fetchbuf0_pc);
        iqentry_a2   [tail]    <=   fnIsShiftiop(fetchbuf0_instr) ? {{DBW-6{1'b0}},fetchbuf0_instr[`INSTRUCTION_RB]} :
                                    fnIsFPCtrl(fetchbuf0_instr) ? {{DBW-6{1'b0}},fetchbuf0_instr[`INSTRUCTION_RB]} :
                                     opcode0==`INC ? {{56{fetchbuf0_instr[47]}},fetchbuf0_instr[47:40]} : 
                                     opcode0==`STI ? fetchbuf0_instr[27:22] :
                                     Rb0[6] ? fnSpr(Rb0[5:0],fetchbuf0_pc) :
                                     rfob0;
        iqentry_a3   [tail]    <=   rfoc0;
        // The source is set even though the arg might be automatically valid (less logic).
        // This is harmless to do. Note there is no source for the 'I' argument.
        iqentry_p_s  [tail]    <=   rf_source[{1'b1,2'h0,Pn0}];
        iqentry_a1_s [tail]    <=   rf_source[Ra0];
        iqentry_a2_s [tail]    <=   rf_source[Rb0];
        iqentry_a3_s [tail]    <=   rf_source[Rc0];
        // Always do this because it's the first queue slot.
        validate_args10(tail);
        tail0 <= tail0 + inc;
        tail1 <= tail1 + inc;
        tail2 <= tail2 + inc;
        queued1 = `TRUE;
        rrmapno <= rrmapno + 3'd1;
    end
end
endtask

// enque 1 on tail0 or tail1
task enque1;
input [2:0] tail;
input [2:0] inc;
input test_stomp;
input validate_args;
begin
    if (opcode1==`NOP) begin
        if (queued1==`TRUE) queued2 = `TRUE;
        queued1 = `TRUE;
    end
    else if (iqentry_v[tail] == `INV && !qstomp) begin
        if ((({fnIsBranch(opcode1), predict_taken1} == {`TRUE, `TRUE})||(opcode1==`LOOP)) && test_stomp)
            qstomp = `TRUE;
        iqentry_v    [tail]    <=   `VAL;
        iqentry_done [tail]    <=   `INV;
        iqentry_cmt  [tail]    <=   `TRUE;
        iqentry_out  [tail]    <=   `INV;
        iqentry_res  [tail]    <=   `ZERO;
        iqentry_insnsz[tail]   <=  fnInsnLength(fetchbuf1_instr);
        iqentry_op   [tail]    <=   opcode1;
        iqentry_fn   [tail]    <=   opcode1==`MLO ? rfoc1[5:0] : fnFunc(fetchbuf1_instr);
        iqentry_cond [tail]    <=   cond1;
        iqentry_bt   [tail]    <=   fnIsFlowCtrl(opcode1) && predict_taken1; 
        iqentry_agen [tail]    <=   `INV;
        // If an interrupt is being enqueued and the previous instruction was an immediate prefix, then
        // inherit the address of the previous instruction, so that the prefix will be executed on return
        // from interrupt.
        // If a string operation was in progress then inherit the address of the string operation so that
        // it can be continued.
        
        iqentry_pc   [tail]    <=    
            (opcode1==`INT && iqentry_op[tail0-3'd1]==`IMM && iqentry_v[tail-3'd1]==`VAL) ? 
                (string_pc != 64'd0 ? string_pc : iqentry_pc[tail-3'd1]) : fetchbuf1_pc;
        //iqentry_pc   [tail0]    <=   fetchbuf1_pc;
        iqentry_mem  [tail]    <=   fetchbuf1_mem;
        iqentry_jmp  [tail]    <=   fetchbuf1_jmp;
        iqentry_fp   [tail]    <=   fetchbuf1_fp;
        iqentry_rfw  [tail]    <=   fetchbuf1_rfw;
        iqentry_tgt  [tail]    <=   Rt1;
        iqentry_pred [tail]    <=   pregs[Pn1];
        // Look at the previous queue slot to see if an immediate prefix is enqueued
        // But don't allow it for a branch
        iqentry_a0[tail]   <=       opcode1==`INT ? fnImm(fetchbuf1_instr) :
                                    fnIsBranch(opcode1) ? {{DBW-12{fetchbuf1_instr[11]}},fetchbuf1_instr[11:8],fetchbuf1_instr[23:16]} :
                                    (inc==3'd2 && opcode0==`IMM) ? {fnImmImm(fetchbuf0_instr)|fnImm8(fetchbuf1_instr)} :
                                    iqentry_op[tail-3'd1]==`IMM && iqentry_v[tail-3'd1] ? {iqentry_a0[tail-3'd1][DBW-1:8],fnImm8(fetchbuf1_instr)} :
                                    opcode1==`IMM ? fnImmImm(fetchbuf1_instr) :
                                    fnImm(fetchbuf1_instr);
        iqentry_a1   [tail]    <=   fnOpa(opcode1,fetchbuf1_instr,rfoa1,fetchbuf1_pc);
        iqentry_a2   [tail]    <=   fnIsShiftiop(fetchbuf1_instr) ? {{DBW-6{1'b0}},fetchbuf1_instr[`INSTRUCTION_RB]} :
                                    fnIsFPCtrl(fetchbuf1_instr) ? {{DBW-6{1'b0}},fetchbuf1_instr[`INSTRUCTION_RB]} :
                                    opcode1==`INC ? {{56{fetchbuf1_instr[47]}},fetchbuf1_instr[47:40]} : 
                                    opcode1==`STI ? fetchbuf1_instr[27:22] :
                                    Rb1[6] ? fnSpr(Rb1[5:0],fetchbuf1_pc) :
                                    rfob1;
        iqentry_a3   [tail]    <=   rfoc1;
        // The source is set even though the arg might be automatically valid (less logic). If 
        // queueing two entries the source settings may be overridden in the argument valudation.
        iqentry_p_s  [tail]    <=   rf_source[{1'b1,2'h0,Pn1}];
        iqentry_a1_s [tail]    <=   rf_source[Ra1];
        iqentry_a2_s [tail]    <=   rf_source[Rb1];
        iqentry_a3_s [tail]    <=   rf_source[Rc1];
        if (validate_args)
            validate_args11(tail);
        tail0 <= tail0 + inc;
        tail1 <= tail1 + inc;
        tail2 <= tail2 + inc;
        if (queued1==`TRUE) queued2 = `TRUE;
        else queued1 = `TRUE;
    end
end
endtask

`ifdef THREEWAY
// enque 3 on tail0 or tail1
task enque2;
input [2:0] tail;
input [2:0] inc;
input test_stomp;
input validate_args;
begin
    if (iqentry_v[tail] == `INV && !qstomp) begin
        if ((({fnIsBranch(opcode2), predict_taken2} == {`TRUE, `TRUE})||(opcode2==`LOOP)) && test_stomp)
            qstomp = `TRUE;
        iqentry_v    [tail]    <=   `VAL;
        iqentry_done [tail]    <=   `INV;
        iqentry_cmt  [tail]    <=   `TRUE;
        iqentry_out  [tail]    <=   `INV;
        iqentry_res  [tail]    <=   `ZERO;
        iqentry_insnsz[tail]   <=  fnInsnLength(fetchbuf2_instr);
        iqentry_op   [tail]    <=   opcode2;
        iqentry_fn   [tail]    <=   opcode2==`MLO ? rfoc2[5:0] : fnFunc(fetchbuf2_instr);
        iqentry_cond [tail]    <=   cond2;
        iqentry_bt   [tail]    <=   fnIsFlowCtrl(opcode2) && predict_taken2; 
        iqentry_agen [tail]    <=   `INV;
        // If an interrupt is being enqueued and the previous instruction was an immediate prefix, then
        // inherit the address of the previous instruction, so that the prefix will be executed on return
        // from interrupt.
        // If a string operation was in progress then inherit the address of the string operation so that
        // it can be continued.
        
        iqentry_pc   [tail]    <=    
            (opcode2==`INT && iqentry_op[tail0-3'd1]==`IMM && iqentry_v[tail-3'd1]==`VAL) ? 
                (string_pc != 64'd0 ? string_pc : iqentry_pc[tail-3'd1]) : fetchbuf2_pc;
        //iqentry_pc   [tail0]    <=   fetchbuf1_pc;
        iqentry_mem  [tail]    <=   fetchbuf2_mem;
        iqentry_jmp  [tail]    <=   fetchbuf2_jmp;
        iqentry_fp   [tail]    <=   fetchbuf2_fp;
        iqentry_rfw  [tail]    <=   fetchbuf2_rfw;
        iqentry_tgt  [tail]    <=   Rt2;
        iqentry_pred [tail]    <=   pregs[Pn2];
        iqentry_p_s  [tail]    <=   rf_source [{1'b1,2'h0,Pn2}];
        // Look at the previous queue slot to see if an immediate prefix is enqueued
        // But don't allow it for a branch
        iqentry_a0[tail]   <=       opcode2==`INT ? fnImm(fetchbuf2_instr) :
                                    fnIsBranch(opcode2) ? {{DBW-12{fetchbuf2_instr[11]}},fetchbuf2_instr[11:8],fetchbuf2_instr[23:16]} :
                                    (inc>3'd1 && opcode1==`IMM) ? {fnImmImm(fetchbuf1_instr)|fnImm8(fetchbuf2_instr)} :
                                    iqentry_op[tail-3'd1]==`IMM && iqentry_v[tail-3'd1] ? {iqentry_a0[tail-3'd1][DBW-1:8],fnImm8(fetchbuf2_instr)} :
                                    opcode2==`IMM ? fnImmImm(fetchbuf2_instr) :
                                    fnImm(fetchbuf2_instr);
        iqentry_a1   [tail]    <=   //fnIsFlowCtrl(opcode1) ? bregs1 : rfoa1;
                                        fnOpa(opcode2,fetchbuf2_instr,rfoa2,fetchbuf2_pc);
        iqentry_a1_s [tail]    <=   rf_source [fnRa(fetchbuf2_instr)];
        iqentry_a2   [tail]    <=   fnIsShiftiop(fetchbuf2_instr) ? {{DBW-6{1'b0}},fetchbuf2_instr[`INSTRUCTION_RB]} :
                                    fnIsFPCtrl(fetchbuf2_instr) ? {{DBW-6{1'b0}},fetchbuf2_instr[`INSTRUCTION_RB]} :
                                    opcode1==`INC ? {{56{fetchbuf2_instr[47]}},fetchbuf2_instr[47:40]} : 
                                    opcode1==`STI ? fetchbuf2_instr[27:22] :
                                    Rb2[6] ? fnSpr(Rb2[5:0],fetchbuf2_pc) :
                                    rfob2;
        iqentry_a2_s [tail]    <=   rf_source[Rb2];
        iqentry_a3   [tail]    <=   rfoc2;
        iqentry_a3_s [tail]    <=   rf_source[Rc2];
        if (validate_args)
            validate_args12(tail); 
        tail0 <= tail0 + inc;
        tail1 <= tail1 + inc;
        tail2 <= tail2 + inc;
        if (inc==3) queued3=`TRUE;
        else if (inc==2) queued2=`TRUE; else queued1 = `TRUE;
    end
end
endtask
`endif

task validate_args10;
input [2:0] tail;
begin
    iqentry_p_v  [tail]    <=   rf_v [{1'b1,2'h0,Pn0}] || cond0 < 4'h2;
    iqentry_a1_v [tail]    <=   fnSource1_v( opcode0 ) | rf_v[ Ra0 ];
    iqentry_a2_v [tail]    <=   fnSource2_v( opcode0, fnFunc(fetchbuf0_instr)) | rf_v[Rb0];
    iqentry_a3_v [tail]    <=   fnSource3_v( opcode0 ) | rf_v[ Rc0 ];
    if (fetchbuf0_rfw|fetchbuf0_pfw) begin
        $display("regv[%d] = %d", Rt0,rf_v[ Rt0 ]);
        rf_v[ Rt0 ] = Rt0==7'd0;
        $display("reg[%d] <= INV",Rt0);
        rf_source[ Rt0 ] <= { fetchbuf0_mem, tail };    // top bit indicates ALU/MEM bus
        $display("10:rf_src[%d] <= %d, insn=%h", Rt0, tail,fetchbuf0_instr);
    end
end
endtask

task validate_args11;
input [2:0] tail;
begin
    // The predicate is automatically valid for condiitions 0 and 1 (always false or always true).
    iqentry_p_v  [tail]    <=   rf_v [{1'b1,2'h0,Pn1}] || cond1 < 4'h2;
    iqentry_a1_v [tail]    <=   fnSource1_v( opcode1 ) | rf_v[ Ra1 ];
    iqentry_a2_v [tail]    <=   fnSource2_v( opcode1, fnFunc(fetchbuf1_instr) ) | rf_v[ Rb1 ];
    iqentry_a3_v [tail]    <=   fnSource3_v( opcode1 ) | rf_v[ Rc1 ];
    if (fetchbuf1_rfw|fetchbuf1_pfw) begin
        $display("1:regv[%d] = %d", Rt1,rf_v[ Rt1 ]);
        rf_v[ Rt1 ] = Rt1==7'd0;
        $display("reg[%d] <= INV",Rt1);
        rf_source[ Rt1 ] <= { fetchbuf1_mem, tail };    // top bit indicates ALU/MEM bus
        $display("11:rf_src[%d] <= %d, insn=%h", Rt1, tail,fetchbuf0_instr);
    end
end
endtask

`ifdef THREEWAY
task validate_args12;
input [2:0] tail;
begin
    // The predicate is automatically valid for condiitions 0 and 1 (always false or always true).
    iqentry_p_v  [tail]    <=   rf_v [{1'b1,2'h0,Pn2}] || cond2 < 4'h2;
    iqentry_a1_v [tail]    <=   fnSource1_v( opcode2 ) | rf_v[ fnRa(fetchbuf2_instr) ];
    iqentry_a2_v [tail]    <=   fnSource2_v( opcode2, fnFunc(fetchbuf2_instr) ) | rf_v[ Rb2 ];
    iqentry_a3_v [tail]    <=   fnSource3_v( opcode2 ) | rf_v[ Rc2 ];
    if (fetchbuf2_rfw|fetchbuf2_pfw) begin
        $display("1:regv[%d] = %d", Rt2,rf_v[ Rt2 ]);
        rf_v[ Rt2 ] = Rt2==7'd0;
        $display("reg[%d] <= INV",Rt2);
        rf_source[ Rt2 ] <= { /*fetchbuf1_mem*/1'b0, tail };    // top bit indicates ALU/MEM bus
    end
end
endtask
`endif

// If two entries were queued then validate the arguments for the second entry.
//
task validate_args;
begin
    if (queued2) begin
    // SOURCE 1 ... this is relatively straightforward, because all instructions
       // that have a source (i.e. every instruction but LUI) read from RB
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource1_v( opcode1 ) == `VAL) begin
           $display("fnSource1_v=1 iq[%d]", tail1);
           iqentry_a1_v [tail1] <= `VAL;
           iqentry_a1_s [tail1] <= 4'hF;
//                    iqentry_a1_s [tail1] <= 4'd0;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (!fetchbuf0_rfw) begin
           iqentry_a1_v [tail1]    <=   rf_v [Ra1];
           iqentry_a1_s [tail1]    <=   rf_source [Ra1];
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (Rt0 != 7'd0 && Ra1 == Rt0) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           $display("invalidating iqentry_a1_v[%d]", tail1);
           iqentry_a1_v [tail1]    <=   `INV;
           iqentry_a1_s [tail1]    <=   {fetchbuf0_mem, tail0};
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           iqentry_a1_v [tail1]    <=   rf_v [Ra1];
           iqentry_a1_s [tail1]    <=   rf_source [Ra1];
           $display("2:iqentry_a1_s[%d] <= %d", tail1, rf_source [Ra1]);
       end

       if (!fetchbuf0_pfw) begin
           iqentry_p_v  [tail1]    <=   rf_v [{1'b1,2'h0,Pn1}] || cond1 < 4'h2;
           iqentry_p_s  [tail1]    <=   rf_source [{1'b1,2'h0,Pn1}];
       end
       else if ((Rt0 != 7'd0 && Pn1==Rt0[3:0]) && (Rt0 & 7'h70)==7'h40) begin
           iqentry_p_v [tail1] <= cond1 < 4'h2;
           iqentry_p_s [tail1] <= {fetchbuf0_mem, tail0};
       end
       else begin
           iqentry_p_v [tail1] <= rf_v[{1'b1,2'h0,Pn1}] || cond1 < 4'h2;
           iqentry_p_s [tail1] <= rf_source[{1'b1,2'h0,Pn1}];
       end

       //
       // SOURCE 2 ... this is more contorted than the logic for SOURCE 1 because
       // some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource2_v( opcode1,fnFunc(fetchbuf1_instr) ) == `VAL) begin
           iqentry_a2_v [tail1] <= `VAL;
           iqentry_a2_s [tail1] <= 4'hF;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (!fetchbuf0_rfw) begin
           iqentry_a2_v [tail1] <= rf_v[ Rb1 ];
           iqentry_a2_s [tail1] <= rf_source[Rb1];
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (Rt0 != 7'd0 && Rb1 == Rt0) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a2_v [tail1]    <=   `INV;
           iqentry_a2_s [tail1]    <=   {fetchbuf0_mem,tail0};
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           iqentry_a2_v [tail1] <= rf_v[ Rb1 ];
           iqentry_a2_s [tail1] <= rf_source[Rb1];
       end

       //
       // SOURCE 3 ... this is relatively straightforward, because all instructions
       // that have a source (i.e. every instruction but LUI) read from RC
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource3_v( opcode1 ) == `VAL) begin
           iqentry_a3_v [tail1] <= `VAL;
           iqentry_a3_v [tail1] <= 4'hF;
//                    iqentry_a1_s [tail1] <= 4'd0;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (!fetchbuf0_rfw) begin
           iqentry_a3_v [tail1]    <=   rf_v [Rc1];
           iqentry_a3_s [tail1]    <=   rf_source [Rc1];
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (Rt0 != 7'd0 && Rc1 == Rt0) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a3_v [tail1]    <=   `INV;
           iqentry_a3_s [tail1]    <=   {fetchbuf0_mem,tail0};
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           iqentry_a3_v [tail1]    <=   rf_v [Rc1];
           iqentry_a3_s [tail1]    <=   rf_source [Rc1];
       end
    end
    if (queued1|queued2) begin
        if (fetchbuf0_rfw|fetchbuf0_pfw) begin
            $display("regv[%d] = %d", Rt0,rf_v[ Rt0 ]);
            rf_v[ Rt0 ] = Rt0==7'd0;
            $display("reg[%d] <= INV",Rt0);
            rf_source[ Rt0 ] <= { fetchbuf0_mem, tail0 };    // top bit indicates ALU/MEM bus
            $display("12:rf_src[%d] <= %d, insn=%h", Rt0, tail0,fetchbuf0_instr);
        end
    end
    if (queued2) begin
        if (fetchbuf1_rfw|fetchbuf1_pfw) begin
            $display("1:regv[%d] = %d", Rt1,rf_v[ Rt1 ]);
            rf_v[ Rt1 ] = Rt1==7'd0;
            $display("reg[%d] <= INV",Rt1);
            rf_source[ Rt1 ] <= { fetchbuf1_mem, tail1 };    // top bit indicates ALU/MEM bus
        end
    end
end
endtask

`ifdef THREEWAY
task validate_args1;
begin
    // SOURCE 1 ... this is relatively straightforward, because all instructions
       // that have a source (i.e. every instruction but LUI) read from RB
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource1_v( opcode2 ) == `VAL) begin
           iqentry_a1_v [tail1] <= `VAL;
           iqentry_a1_s [tail1] <= 4'hF;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (!fetchbuf1_rfw) begin
           iqentry_a1_v [tail1]    <=   rf_v [Ra2];
           iqentry_a1_s [tail1]    <=   rf_source [Ra2];
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (Rt1 != 7'd0 && Ra2 == Rt1) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a1_v [tail1]    <=   `INV;
           iqentry_a1_s [tail1]    <=   { fetchbuf1_mem, tail1 };
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           iqentry_a1_v [tail1]    <=   rf_v [Ra2];
           iqentry_a1_s [tail1]    <=   rf_source [Ra2];
       end

       if (!fetchbuf1_pfw) begin
           iqentry_p_v  [tail1]    <=   rf_v [{1'b1,2'h0,Pn2}] || cond2 < 4'h2;
           iqentry_p_s  [tail1]    <=   rf_source [{1'b1,2'h0,Pn2}];
       end
       else if (fnTargetReg(fetchbuf1_instr) != 9'd0 && fetchbuf2_instr[7:4]==fnTargetReg(fetchbuf1_instr) & 4'hF
           && (fnTargetReg(fetchbuf1_instr) & 7'h70)==7'h40) begin
           iqentry_p_v [tail1] <= cond2 < 4'h2;
           iqentry_p_s [tail1] <= { fetchbuf1_mem, tail0 };
       end
       else begin
           iqentry_p_v [tail1] <= rf_v[{1'b1,2'h0,Pn2}] || cond2 < 4'h2;
           iqentry_p_s [tail1] <= rf_source[{1'b1,2'h0,Pn2}];
       end

       //
       // SOURCE 2 ... this is more contorted than the logic for SOURCE 1 because
       // some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource2_v( opcode2,fnFunc(fetchbuf2_instr) ) == `VAL) begin
           iqentry_a2_v [tail1] <= `VAL;
//                    iqentry_a2_s [tail1] <= 4'd0;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (~fetchbuf1_rfw) begin
           iqentry_a2_v [tail1] <= rf_v[ Rb2 ];
           iqentry_a2_s [tail1] <= rf_source[Rb2];
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (fnTargetReg(fetchbuf1_instr) != 7'd0 &&
           Rb2 == fnTargetReg(fetchbuf1_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a2_v [tail1]    <=   `INV;
           iqentry_a2_s [tail1]    <=   { fetchbuf1_mem, tail0 };
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           iqentry_a2_v [tail1] <= rf_v[ Rb2 ];
           iqentry_a2_s [tail1] <= rf_source[Rb2];
       end

       //
       // SOURCE 3 ... this is relatively straightforward, because all instructions
       // that have a source (i.e. every instruction but LUI) read from RC
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource3_v( opcode2 ) == `VAL) begin
           iqentry_a3_v [tail1] <= `VAL;
//                    iqentry_a1_s [tail1] <= 4'd0;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (~fetchbuf1_rfw) begin
           begin
               iqentry_a3_v [tail1]    <=   rf_v [Rc2];
               iqentry_a3_s [tail1]    <=   rf_source [Rc2];
           end
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (fnTargetReg(fetchbuf1_instr) != 7'd0
           && Rc2 == fnTargetReg(fetchbuf1_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a3_v [tail1]    <=   `INV;
           iqentry_a3_s [tail1]    <=   { fetchbuf1_mem, tail0 };
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           begin
               iqentry_a3_v [tail1]    <=   rf_v [Rc2];
               iqentry_a3_s [tail1]    <=   rf_source [Rc2];
           end
       end
       
       if (queued1|queued2) begin
            if (fetchbuf1_rfw|fetchbuf1_pfw) begin
                $display("regv[%d] = %d", fnTargetReg(fetchbuf1_instr),rf_v[ fnTargetReg(fetchbuf1_instr) ]);
                rf_v[ fnTargetReg(fetchbuf1_instr) ] = fnTargetReg(fetchbuf1_instr)==7'd0;
                $display("reg[%d] <= INV",fnTargetReg(fetchbuf1_instr));
                rf_source[ fnTargetReg(fetchbuf1_instr) ] <= { /*fetchbuf0_mem*/1'b0, tail0 };    // top bit indicates ALU/MEM bus
            end
        end
        if (queued2) begin
            if (fetchbuf2_rfw|fetchbuf2_pfw) begin
                $display("1:regv[%d] = %d", fnTargetReg(fetchbuf2_instr),rf_v[ fnTargetReg(fetchbuf2_instr) ]);
                rf_v[ fnTargetReg(fetchbuf1_instr) ] = fnTargetReg(fetchbuf2_instr)==7'd0;
                $display("reg[%d] <= INV",fnTargetReg(fetchbuf2_instr));
                rf_source[ fnTargetReg(fetchbuf2_instr) ] <= { /*fetchbuf1_mem*/1'b0, tail1 };    // top bit indicates ALU/MEM bus
            end
        end
end
endtask

// three-way argument validation
task validate_args3;
begin
       // SOURCE 1 ... this is relatively straightforward, because all instructions
        // that have a source (i.e. every instruction but LUI) read from RB
        //
        // if the argument is an immediate or not needed, we're done
        if (fnSource1_v( opcode1 ) == `VAL) begin
            iqentry_a1_v [tail1] <= `VAL;
        end
        // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
        else if (~fetchbuf0_rfw) begin
            begin
                iqentry_a1_v [tail1]    <=   rf_v [fnRa(fetchbuf1_instr)];
                iqentry_a1_s [tail1]    <=   rf_source [fnRa(fetchbuf1_instr)];
            end
        end
        // otherwise, previous instruction does write to RF ... see if overlap
        else if (fnTargetReg(fetchbuf0_instr) != 7'd0
            && fnRa(fetchbuf1_instr) == fnTargetReg(fetchbuf0_instr)) begin
            // if the previous instruction is a LW, then grab result from memq, not the iq
            iqentry_a1_v [tail1]    <=   `INV;
            iqentry_a1_s [tail1]    <=   {fetchbuf1_mem,tail0};
        end
        // if no overlap, get info from rf_v and rf_source
        else begin
            begin
                iqentry_a1_v [tail1]    <=   rf_v [fnRa(fetchbuf1_instr)];
                iqentry_a1_s [tail1]    <=   rf_source [fnRa(fetchbuf1_instr)];
            end
        end

       if (~fetchbuf0_pfw) begin
           iqentry_p_v  [tail1]    <=   rf_v [{1'b1,2'h0,Pn1}] || cond1 < 4'h2;
           iqentry_p_s  [tail1]    <=   rf_source [{1'b1,2'h0,Pn1}];
       end
       else if (fnTargetReg(fetchbuf0_instr) != 7'd0 && fetchbuf1_instr[7:4]==fnTargetReg(fetchbuf0_instr) & 4'hF
           && (fnTargetReg(fetchbuf0_instr) & 7'h70)==7'h40) begin
           iqentry_p_v [tail1] <= cond1 < 4'h2;
           iqentry_p_s [tail1] <= {fetchbuf1_mem,tail0};
       end
       else begin
           iqentry_p_v [tail1] <= rf_v[{1'b1,2'h0,Pn1}] || cond1 < 4'h2;
           iqentry_p_s [tail1] <= rf_source[{1'b1,2'h0,Pn1}];
       end

       //
       // SOURCE 2 ... this is more contorted than the logic for SOURCE 1 because
       // some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource2_v( opcode1,fnFunc(fetchbuf1_instr) ) == `VAL) begin
           iqentry_a2_v [tail1] <= `VAL;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (~fetchbuf0_rfw) begin
           iqentry_a2_v [tail1] <= rf_v[ Rb1 ];
           iqentry_a2_s [tail1] <= rf_source[Rb1];
       end
       else if (fnTargetReg(fetchbuf0_instr) != 7'd0 && Rb1 == fnTargetReg(fetchbuf0_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a2_v [tail1]    <=   `INV;
           iqentry_a2_s [tail1]    <=   {fetchbuf1_mem,tail0};
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           iqentry_a2_v [tail1] <= rf_v[ Rb1 ];
           iqentry_a2_s [tail1] <= rf_source[Rb1];
       end

       //
       // SOURCE 3 ... this is relatively straightforward, because all instructions
       // that have a source (i.e. every instruction but LUI) read from RC
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource3_v( opcode1 ) == `VAL) begin
           iqentry_a3_v [tail1] <= `VAL;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (~fetchbuf0_rfw) begin
           begin
               iqentry_a3_v [tail1]    <=   rf_v [Rc1];
               iqentry_a3_s [tail1]    <=   rf_source [Rc1];
           end
       end
       else if (fetchbuf0_rfw && fnTargetReg(fetchbuf0_instr) != 7'd0 && Rc1 == fnTargetReg(fetchbuf0_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a3_v [tail1]    <=   `INV;
           iqentry_a3_s [tail1]    <=   {fetchbuf1_mem,tail0};
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           begin
               iqentry_a3_v [tail1]    <=   rf_v [Rc1];
               iqentry_a3_s [tail1]    <=   rf_source [Rc1];
           end
       end



       // SOURCE 1 ... this is relatively straightforward, because all instructions
       // that have a source (i.e. every instruction but LUI) read from RB
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource1_v( opcode2 ) == `VAL) begin
           iqentry_a1_v [tail2] <= `VAL;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (!fetchbuf1_rfw && !fetchbuf0_rfw) begin
           begin
               iqentry_a1_v [tail2]    <=   rf_v [fnRa(fetchbuf2_instr)];
               iqentry_a1_s [tail2]    <=   rf_source [fnRa(fetchbuf2_instr)];
           end
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (fetchbuf1_rfw && fnTargetReg(fetchbuf1_instr) != 7'd0
           && fnRa(fetchbuf2_instr) == fnTargetReg(fetchbuf1_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a1_v [tail2]    <=   `INV;
           iqentry_a1_s [tail2]    <=   {fetchbuf2_mem,tail1};
       end
       else if (fetchbuf0_rfw && fnTargetReg(fetchbuf0_instr) != 7'd0
           && fnRa(fetchbuf2_instr) == fnTargetReg(fetchbuf0_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a1_v [tail2]    <=   `INV;
           iqentry_a1_s [tail2]    <=   tail0;
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           begin
               iqentry_a1_v [tail2]    <=   rf_v [fnRa(fetchbuf2_instr)];
               iqentry_a1_s [tail2]    <=   rf_source [fnRa(fetchbuf2_instr)];
           end
       end

       if (~fetchbuf1_pfw & ~fetchbuf0_pfw) begin
           iqentry_p_v  [tail2]    <=   rf_v [{1'b1,2'h0,Pn2}] || cond2 < 4'h2;
           iqentry_p_s  [tail2]    <=   rf_source [{1'b1,2'h0,Pn2}];
       end
       else if (fetchbuf1_pfw && fnTargetReg(fetchbuf1_instr) != 7'd0 && fetchbuf2_instr[7:4]==fnTargetReg(fetchbuf1_instr) & 4'hF
           && (fnTargetReg(fetchbuf1_instr) & 7'h70)==7'h40) begin
           iqentry_p_v [tail2] <= cond2 < 4'h2;
           iqentry_p_s [tail2] <= { tail1 };
       end
       else if (fetchbuf0_pfw && fnTargetReg(fetchbuf0_instr) != 7'd0 && fetchbuf2_instr[7:4]==fnTargetReg(fetchbuf0_instr) & 4'hF
           && (fnTargetReg(fetchbuf0_instr) & 7'h70)==7'h40) begin
           iqentry_p_v [tail2] <= cond2 < 4'h2;
           iqentry_p_s [tail2] <= { fetchbuf2_mem, tail0 };
       end
       else begin
           iqentry_p_v [tail2] <= rf_v[{1'b1,2'h0,Pn2}] || cond2 < 4'h2;
           iqentry_p_s [tail2] <= rf_source[{1'b1,2'h0,Pn2}];
       end

       //
       // SOURCE 2 ... this is more contorted than the logic for SOURCE 1 because
       // some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource2_v( opcode2,fnFunc(fetchbuf2_instr) ) == `VAL) begin
           iqentry_a2_v [tail2] <= `VAL;
//                    iqentry_a2_s [tail1] <= 4'd0;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (~fetchbuf1_rfw & ~fetchbuf0_rfw) begin
           iqentry_a2_v [tail2] <= rf_v[ Rb2 ];
           iqentry_a2_s [tail2] <= rf_source[Rb2];
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (fetchbuf1_rfw && fnTargetReg(fetchbuf1_instr) != 7'd0 &&
           Rb2 == fnTargetReg(fetchbuf1_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a2_v [tail2]    <=   `INV;
           iqentry_a2_s [tail2]    <=  {fetchbuf2_mem, tail1};
       end
       else if (fetchbuf0_rfw && fnTargetReg(fetchbuf0_instr) != 7'd0 &&
           Rb2 == fnTargetReg(fetchbuf0_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a2_v [tail2]    <=   `INV;
           iqentry_a2_s [tail2]    <=   tail0;
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           iqentry_a2_v [tail2] <= rf_v[ Rb2 ];
           iqentry_a2_s [tail2] <= rf_source[Rb2];
       end

       //
       // SOURCE 3 ... this is relatively straightforward, because all instructions
       // that have a source (i.e. every instruction but LUI) read from RC
       //
       // if the argument is an immediate or not needed, we're done
       if (fnSource3_v( opcode2 ) == `VAL) begin
           iqentry_a3_v [tail2] <= `VAL;
//                    iqentry_a1_s [tail1] <= 4'd0;
       end
       // if previous instruction writes nothing to RF, then get info from rf_v and rf_source
       else if (~fetchbuf1_rfw & ~fetchbuf0_rfw) begin
           begin
               iqentry_a3_v [tail2]    <=   rf_v [Rc2];
               iqentry_a3_s [tail2]    <=   rf_source [Rc2];
           end
       end
       // otherwise, previous instruction does write to RF ... see if overlap
       else if (fetchbuf1_rfw && fnTargetReg(fetchbuf1_instr) != 7'd0
           && Rc2 == fnTargetReg(fetchbuf1_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a3_v [tail2]    <=   `INV;
           iqentry_a3_s [tail2]    <=  {fetchbuf2_mem, tail1};
       end
       else if (fetchbuf0_rfw && fnTargetReg(fetchbuf0_instr) != 7'd0
           && Rc2 == fnTargetReg(fetchbuf0_instr)) begin
           // if the previous instruction is a LW, then grab result from memq, not the iq
           iqentry_a3_v [tail2]    <=   `INV;
           iqentry_a3_s [tail2]    <=   {fetchbuf2_mem,tail0};
       end
       // if no overlap, get info from rf_v and rf_source
       else begin
           begin
               iqentry_a3_v [tail2]    <=   rf_v [Rc2];
               iqentry_a3_s [tail2]    <=   rf_source [Rc2];
           end
       end

        if (queued1|queued2|queued3) begin
            if (fetchbuf0_rfw|fetchbuf0_pfw) begin
                $display("regv[%d] = %d", fnTargetReg(fetchbuf0_instr),rf_v[ fnTargetReg(fetchbuf0_instr) ]);
                rf_v[ fnTargetReg(fetchbuf0_instr) ] = fnTargetReg(fetchbuf0_instr)==7'd0;
                $display("reg[%d] <= INV",fnTargetReg(fetchbuf0_instr));
                rf_source[ fnTargetReg(fetchbuf0_instr) ] <= { /*fetchbuf0_mem*/1'b0, tail0 };    // top bit indicates ALU/MEM bus
            end
        end
        if (queued2|queued3) begin
            if (fetchbuf1_rfw|fetchbuf1_pfw) begin
                $display("regv[%d] = %d", fnTargetReg(fetchbuf1_instr),rf_v[ fnTargetReg(fetchbuf1_instr) ]);
                rf_v[ fnTargetReg(fetchbuf1_instr) ] = fnTargetReg(fetchbuf1_instr)==7'd0;
                $display("reg[%d] <= INV",fnTargetReg(fetchbuf1_instr));
                rf_source[ fnTargetReg(fetchbuf1_instr) ] <= { /*fetchbuf0_mem*/1'b0, tail };    // top bit indicates ALU/MEM bus
            end
        end
        if (queued3) begin
            if (fetchbuf2_rfw|fetchbuf2_pfw) begin
                $display("1:regv[%d] = %d", fnTargetReg(fetchbuf2_instr),rf_v[ fnTargetReg(fetchbuf2_instr) ]);
                rf_v[ fnTargetReg(fetchbuf1_instr) ] = fnTargetReg(fetchbuf2_instr)==7'd0;
                $display("reg[%d] <= INV",fnTargetReg(fetchbuf2_instr));
                rf_source[ fnTargetReg(fetchbuf2_instr) ] <= { /*fetchbuf1_mem*/1'b0, tail2 };    // top bit indicates ALU/MEM bus
            end
        end
end
endtask

task fetchABC;
begin
    fetchbufA_instr <= insn0;
    fetchbufA_pc <= pc;
    fetchbufA_v <= ld_fetchbuf;
    fetchbufB_instr <= insn1;
    fetchbufB_pc <= pc + fnInsnLength(insn);
    fetchbufB_v <= ld_fetchbuf;
    fetchbufC_instr <= insn2;
    fetchbufC_pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
    fetchbufC_v <= ld_fetchbuf;
end
endtask

task fetchDEF;
begin
    fetchbufD_instr <= insn0;
    fetchbufD_pc <= pc;
    fetchbufD_v <= ld_fetchbuf;
    fetchbufE_instr <= insn1;
    fetchbufE_pc <= pc + fnInsnLength(insn);
    fetchbufE_v <= ld_fetchbuf;
    fetchbufF_instr <= insn2;
    fetchbufF_pc <= pc + fnInsnLength(insn) + fnInsnLength1(insn);
    fetchbufF_v <= ld_fetchbuf;
end
endtask

`else
task fetchAB;
begin
    fetchbufA_instr <= insn0;
    fetchbufA_pc <= pc;
    fetchbufA_v <= ld_fetchbuf;
    fetchbufB_instr <= insn1;
    fetchbufB_pc <= pc + fnInsnLength(insn);
    fetchbufB_v <= ld_fetchbuf;
end
endtask

task fetchCD;
begin
    fetchbufC_instr <= insn0;
    fetchbufC_pc <= pc;
    fetchbufC_v <= ld_fetchbuf;
    fetchbufD_instr <= insn1;
    fetchbufD_pc <= pc + fnInsnLength(insn);
    fetchbufD_v <= ld_fetchbuf;
end
endtask
`endif

// Reset the tail pointers.
// Used by the enqueue logic
//
task reset_tail_pointers;
input first;
begin
`ifdef THREEWAY
    if ((iqentry_stomp[0] & ~iqentry_stomp[7])|first) begin
        tail0 <= 0;
        tail1 <= 1;
        tail2 <= 2;
    end
    else if (iqentry_stomp[1] & ~iqentry_stomp[0]) begin
        tail0 <= 1;
        tail1 <= 2;
        tail2 <= 3;
    end
    else if (iqentry_stomp[2] & ~iqentry_stomp[1]) begin
        tail0 <= 2;
        tail1 <= 3;
        tail2 <= 4;
    end
    else if (iqentry_stomp[3] & ~iqentry_stomp[2]) begin
        tail0 <= 3;
        tail1 <= 4;
        tail2 <= 5;
    end
    else if (iqentry_stomp[4] & ~iqentry_stomp[3]) begin
        tail0 <= 4;
        tail1 <= 5;
        tail2 <= 6;
    end
    else if (iqentry_stomp[5] & ~iqentry_stomp[4]) begin
        tail0 <= 5;
        tail1 <= 6;
        tail2 <= 7;
    end
    else if (iqentry_stomp[6] & ~iqentry_stomp[5]) begin
        tail0 <= 6;
        tail1 <= 7;
        tail2 <= 0;
    end
    else if (iqentry_stomp[7] & ~iqentry_stomp[6]) begin
        tail0 <= 7;
        tail1 <= 0;
        tail2 <= 1;
    end
`else
    if ((iqentry_stomp[0] & ~iqentry_stomp[7]) | first) begin
        tail0 <= 0;
        tail1 <= 1;
    end
    else if (iqentry_stomp[1] & ~iqentry_stomp[0]) begin
        tail0 <= 1;
        tail1 <= 2;
    end
    else if (iqentry_stomp[2] & ~iqentry_stomp[1]) begin
        tail0 <= 2;
        tail1 <= 3;
    end
    else if (iqentry_stomp[3] & ~iqentry_stomp[2]) begin
        tail0 <= 3;
        tail1 <= 4;
    end
    else if (iqentry_stomp[4] & ~iqentry_stomp[3]) begin
        tail0 <= 4;
        tail1 <= 5;
    end
    else if (iqentry_stomp[5] & ~iqentry_stomp[4]) begin
        tail0 <= 5;
        tail1 <= 6;
    end
    else if (iqentry_stomp[6] & ~iqentry_stomp[5]) begin
        tail0 <= 6;
        tail1 <= 7;
    end
    else if (iqentry_stomp[7] & ~iqentry_stomp[6]) begin
        tail0 <= 7;
        tail1 <= 0;
    end
    // otherwise, it is the last instruction in the queue that has been mispredicted ... do nothing
`endif
end
endtask

// Increment the head pointers
// Also increments the instruction counter
// Used when instructions are committed.
// Also clear any outstanding state bits that foul things up.
//
task head_inc;
input [2:0] amt;
begin
    head0 <= head0 + amt;
    head1 <= head1 + amt;
    head2 <= head2 + amt;
    head3 <= head3 + amt;
    head4 <= head4 + amt;
    head5 <= head5 + amt;
    head6 <= head6 + amt;
    head7 <= head7 + amt;
    I <= I + amt;
    if (amt==3'd3) begin
    iqentry_agen[head0] <= `INV;
    iqentry_agen[head1] <= `INV;
    iqentry_agen[head2] <= `INV;
    end else if (amt==3'd2) begin
    iqentry_agen[head0] <= `INV;
    iqentry_agen[head1] <= `INV;
    end else if (amt==3'd1)
	    iqentry_agen[head0] <= `INV;
end
endtask

endmodule
