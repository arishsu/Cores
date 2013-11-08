// ============================================================================
//        __
//   \\__/ o\    (C) 2013  Robert Finch, Stratford
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
// Thor SuperScalar
// Instruction enque logic
//
// ============================================================================
//
    //
    // ENQUEUE
    //
    // place up to three instructions from the fetch buffer into slots in the IQ.
    //   note: they are placed in-order, and they are expected to be executed
    // 0, 1, or 2 of the fetch buffers may have valid data
    // 0, 1, or 2 slots in the instruction queue may be available.
    // if we notice that one of the instructions in the fetch buffer is a backwards branch,
    // predict it taken (set branchback/backpc and delete any instructions after it in fetchbuf)
    //

	if (!branchmiss) 	// don't bother doing anything if there's been a branch miss

		case ({fetchbuf0_v, fetchbuf1_v})

		2'b00: ; // do nothing

		2'b01:
				if (iqentry_v[tail0] == `INV) begin

					iqentry_v    [tail0]    <=   `VAL;
					iqentry_done [tail0]    <=   `INV;
					iqentry_cmt	 [tail0]    <=   `INV;
					iqentry_out  [tail0]    <=   `INV;
					iqentry_res  [tail0]    <=   `ZERO;
					iqentry_insnsz[tail0]   <=  fnInsnLength(fetchbuf1_instr);
					iqentry_op   [tail0]    <=   opcode1;
					iqentry_cond [tail0]    <=   cond1;
					iqentry_bt   [tail0]    <=   fnIsFlowCtrl(opcode1) && predict_taken1; 
					iqentry_agen [tail0]    <=   `INV;
					iqentry_pc   [tail0]    <=   fetchbuf1_pc;
					iqentry_mem  [tail0]    <=   fetchbuf1_mem;
					iqentry_jmp  [tail0]    <=   fetchbuf1_jmp;
					iqentry_rfw  [tail0]    <=   fetchbuf1_rfw;
					iqentry_tgt  [tail0]    <=   fnTargetReg(fetchbuf1_instr);
					iqentry_exc  [tail0]    <=   `EXC_NONE;
					iqentry_pred [tail0]    <=   pregs[Pn1];
					iqentry_p_v  [tail0]    <=   pf_v [Pn1];
					iqentry_p_s  [tail0]    <=   pf_source [Pn1];
					// Look at the previous queue slot to see if an immediate prefix is enqueued
					// But don't allow it for a branch
					if (iqentry_v[tail0-3'd1]==`VAL && iqentry_op[tail0-3'd1]==`IMM && !fnIsBranch(opcode1))
						iqentry_a0[tail0]   <=   {iqentry_a0[tail0-3'd1][DBW-1:8],fnImm(fetchbuf1_instr)};
					else
						iqentry_a0[tail0]   <=  fnIsBranch(opcode1) ? {{DBW-12{fetchbuf1_instr[11]}},fetchbuf1_instr[11:8],fetchbuf1_instr[23:16]} : 
												{{DBW-8{fnImmMSB(fetchbuf1_instr)}},fnImm(fetchbuf1_instr)};
					iqentry_a1   [tail0]    <=   fnIsFlowCtrl(opcode1) ? bregs1 : rfoa1;
					iqentry_a1_v [tail0]    <=   fnSource1_v( opcode1 ) | rf_v[ fnRa(fetchbuf1_instr) ];
					iqentry_a1_s [tail0]    <=   rf_source [fnRa(fetchbuf1_instr)];
					iqentry_a2   [tail0]    <=   fnIsShiftiop(opcode1) ? {{DBW-6{1'b0}},Rb1[5:0]} : rfob1;
					iqentry_a2_v [tail0]    <=   fnSource2_v( opcode1 ) | rf_v[ Rb1 ];
					iqentry_a2_s [tail0]    <=   rf_source[Rb1];
					tail0 <= tail0 + 1;
					tail1 <= tail1 + 1;
					if (fetchbuf1_pfw) begin
						pf_v [Pt1] <= `INV;
						pf_source[Pt1] <= {fetchbuf1_mem, tail0};
					end
					if (fetchbuf1_rfw) begin
						rf_v[ fnTargetReg(fetchbuf1_instr) ] <= `INV;
						rf_source[ fnTargetReg(fetchbuf1_instr) ] <= { fetchbuf1_mem, tail0 };	// top bit indicates ALU/MEM bus
					end
				end

		2'b10:
				if (iqentry_v[tail0] == `INV) begin

					iqentry_v    [tail0]    <=   `VAL;
					iqentry_done [tail0]    <=   `INV;
					iqentry_cmt	 [tail0]    <=   `INV;
					iqentry_out  [tail0]    <=   `INV;
					iqentry_res  [tail0]    <=   `ZERO;
					iqentry_insnsz[tail0]   <=  fnInsnLength(fetchbuf0_instr);
					iqentry_op   [tail0]    <=   opcode0; 
					iqentry_cond [tail0]    <=   cond0;
					iqentry_bt   [tail0]    <=   fnIsFlowCtrl(opcode0) && predict_taken0; 
					iqentry_agen [tail0]    <=   `INV;
					iqentry_pc   [tail0]    <=   fetchbuf0_pc;
					iqentry_mem  [tail0]    <=   fetchbuf0_mem;
					iqentry_jmp  [tail0]    <=   fetchbuf0_jmp;
					iqentry_rfw  [tail0]    <=   fetchbuf0_rfw;
					iqentry_tgt  [tail0]    <=   fnTargetReg(fetchbuf0_instr);
					iqentry_exc  [tail0]    <=   `EXC_NONE;
					iqentry_pred [tail0]    <=   pregs[Pn0];
					iqentry_p_v  [tail0]    <=   pf_v [Pn0];
					iqentry_p_s  [tail0]    <=   pf_source [Pn0];
					// Look at the previous queue slot to see if an immediate prefix is enqueued
					if (iqentry_v[tail0-3'd1]==`VAL && iqentry_op[tail0-3'd1]==`IMM && !fnIsBranch(opcode0))
						iqentry_a0[tail0]   <=   {iqentry_a0[tail0-3'd1][DBW-1:8],fnImm(fetchbuf0_instr)};
					else
						iqentry_a0[tail0]   <=  fnIsBranch(opcode0) ? {{DBW-12{fetchbuf0_instr[11]}},fetchbuf0_instr[11:8],fetchbuf0_instr[23:16]} : 
												{{DBW-8{fnImmMSB(fetchbuf0_instr)}},fnImm(fetchbuf0_instr)};
					iqentry_a1   [tail0]    <=   fnIsFlowCtrl(opcode0) ? bregs0 : rfoa0;
					iqentry_a1_v [tail0]    <=   fnSource1_v( opcode0 ) | rf_v[ fnRa(fetchbuf0_instr) ];
					iqentry_a1_s [tail0]    <=   rf_source [fnRa(fetchbuf0_instr)];
					iqentry_a2   [tail0]    <=   fnIsShiftiop(opcode0) ? {58'b0,Rb0[5:0]} : rfob0;
					iqentry_a2_v [tail0]    <=   fnSource2_v( opcode0) | rf_v[Rb0];
					iqentry_a2_s [tail0]    <=   rf_source [Rb0];
					tail0 <= tail0 + 1;
					tail1 <= tail1 + 1;
					if (fetchbuf0_pfw) begin
						pf_v [Pt0] <= `INV;
						pf_source[Pt0] <= {fetchbuf0_mem, tail0};
					end
					if (fetchbuf0_rfw) begin
						rf_v[ fnTargetReg(fetchbuf0_instr) ] <= `INV;
						rf_source[ fnTargetReg(fetchbuf0_instr) ] <= { fetchbuf0_mem, tail0 };	// top bit indicates ALU/MEM bus
					end
				end
		
			2'b11: if (iqentry_v[tail0] == `INV) begin

			//
			// if the first instruction is a backwards branch, enqueue it & stomp on all following instructions
			//
			if ({fnIsBranch(opcode0), predict_taken0} == {`TRUE, `TRUE}) begin

				iqentry_v    [tail0]    <=	`VAL;
				iqentry_done [tail0]    <=	`INV;
				iqentry_cmt	 [tail0]    <=  `INV;
				iqentry_out  [tail0]    <=	`INV;
				iqentry_res  [tail0]    <=	`ZERO;
				iqentry_insnsz[tail0]   <=  fnInsnLength(fetchbuf0_instr);
				iqentry_op   [tail0]    <=	opcode0; 			// BEQ
				iqentry_cond [tail0]    <=   cond0;
				iqentry_bt   [tail0]    <=	`VAL;
				iqentry_agen [tail0]    <=	`INV;
				iqentry_pc   [tail0]    <=	fetchbuf0_pc;
				iqentry_mem  [tail0]    <=	fetchbuf0_mem;
				iqentry_jmp  [tail0]    <=	fetchbuf0_jmp;
				iqentry_rfw  [tail0]    <=	fetchbuf0_rfw;
				iqentry_tgt  [tail0]    <=	fnTargetReg(fetchbuf0_instr);
				iqentry_exc  [tail0]    <=	`EXC_NONE;
				// Look at the previous queue slot to see if an immediate prefix is enqueued
				if (iqentry_v[tail0-3'd1]==`VAL && iqentry_op[tail0-3'd1]==`IMM && !fnIsBranch(opcode0))
					iqentry_a0[tail0]   <=   {iqentry_a0[tail0-3'd1][DBW-1:8],fnImm(fetchbuf0_instr)};
				else
					iqentry_a0[tail0]   <=  fnIsBranch(opcode0) ? {{DBW-12{fetchbuf0_instr[11]}},fetchbuf0_instr[11:8],fetchbuf0_instr[23:16]} : 
											{{DBW-8{fnImmMSB(fetchbuf0_instr)}},fnImm(fetchbuf0_instr)};
				iqentry_a1   [tail0]    <=	fnIsFlowCtrl(opcode0) ? bregs0 : rfoa0;
				iqentry_a1_v [tail0]    <=	fnSource1_v( opcode0 ) | rf_v[ fnRa(fetchbuf0_instr) ];
				iqentry_a1_s [tail0]    <=	rf_source [fnRa(fetchbuf0_instr)];
				iqentry_a2   [tail0]    <=	fnIsShiftiop(opcode0) ? {58'b0,Rb0[5:0]} : rfob0;
				iqentry_a2_v [tail0]    <=	fnSource2_v( opcode0 ) | rf_v[ Rb0 ];
				iqentry_a2_s [tail0]    <=	rf_source[ Rb0 ];
				tail0 <= tail0 + 1;
				tail1 <= tail1 + 1;

			end

			else begin	// fetchbuf0 doesn't contain a backwards branch
				//
				// so -- we can enqueue 1 or 2 instructions, depending on space in the IQ
				// update tail0/tail1 separately (at top)
				// update the rf_v and rf_source bits separately (at end)
				//   the problem is that if we do have two instructions, 
				//   they may interact with each other, so we have to be
				//   careful about where things point.
				//

				if (iqentry_v[tail1] == `INV) begin
					tail0 <= tail0 + 2;
					tail1 <= tail1 + 2;
				end
				else begin
					tail0 <= tail0 + 1;
					tail1 <= tail1 + 1;
				end

				//
				// enqueue the first instruction ...
				//
				iqentry_v    [tail0]    <=   `VAL;
				iqentry_done [tail0]    <=   `INV;
				iqentry_cmt  [tail0]    <=   `INV;
				iqentry_out  [tail0]    <=   `INV;
				iqentry_res  [tail0]    <=   `ZERO;
				iqentry_insnsz[tail0]   <=  fnInsnLength(fetchbuf0_instr);
				iqentry_op   [tail0]    <=  opcode0;
				iqentry_cond [tail0]    <=   cond0;
				iqentry_bt   [tail0]    <=   `INV;
				iqentry_agen [tail0]    <=   `INV;
				iqentry_pc   [tail0]    <=   fetchbuf0_pc;
				iqentry_mem  [tail0]    <=   fetchbuf0_mem;
				iqentry_jmp  [tail0]    <=   fetchbuf0_jmp;
				iqentry_rfw  [tail0]    <=   fetchbuf0_rfw;
				iqentry_tgt  [tail0]    <=   fnTargetReg(fetchbuf0_instr);
				iqentry_exc  [tail0]    <=   `EXC_NONE;
				// Look at the previous queue slot to see if an immediate prefix is enqueued
				if (iqentry_v[tail0-3'd1]==`VAL && iqentry_op[tail0-3'd1]==`IMM && !fnIsBranch(opcode0))
					iqentry_a0[tail0]   <=   {iqentry_a0[tail0-3'd1][DBW-1:8],fnImm(fetchbuf0_instr)};
				else
					iqentry_a0[tail0]   <=  fnIsBranch(opcode0) ? {{DBW-12{fetchbuf0_instr[11]}},fetchbuf0_instr[11:8],fetchbuf0_instr[23:16]} : 
											{{DBW-8{fnImmMSB(fetchbuf0_instr)}},fnImm(fetchbuf0_instr)};
				iqentry_a1   [tail0]    <=   fnIsFlowCtrl(opcode0) ? bregs0 : rfoa0;
				iqentry_a1_v [tail0]    <=   fnSource1_v( opcode0 ) | rf_v[ fnRa(fetchbuf0_instr) ];
								
				iqentry_a1_s [tail0]    <=   rf_source [fnRa(fetchbuf0_instr)];
				iqentry_a2   [tail0]    <=   fnIsShiftiop(opcode0) ? {58'b0,Rb0[5:0]} : rfob0;
				iqentry_a2_v [tail0]    <=   fnSource2_v( opcode0 ) | rf_v[ Rb0 ];
				iqentry_a2_s [tail0]    <=   rf_source[Rb0];
				//
				// if there is room for a second instruction, enqueue it
				//
				if (iqentry_v[tail1] == `INV) begin

				iqentry_v    [tail1]    <=   `VAL;
				iqentry_done [tail1]    <=   `INV;
				iqentry_cmt  [tail1]    <=   `INV;
				iqentry_out  [tail1]    <=   `INV;
				iqentry_res  [tail1]    <=   `ZERO;
				iqentry_insnsz[tail1]   <=  fnInsnLength(fetchbuf1_instr);
				iqentry_op   [tail1]    <=   opcode1; 
				iqentry_cond [tail1]    <=   cond1;
				iqentry_bt   [tail1]    <=   fnIsFlowCtrl(opcode1) && predict_taken1; 
				iqentry_agen [tail1]    <=   `INV;
				iqentry_pc   [tail1]    <=   fetchbuf1_pc;
				iqentry_mem  [tail1]    <=   fetchbuf1_mem;
				iqentry_jmp  [tail1]    <=   fetchbuf1_jmp;
				iqentry_rfw  [tail1]    <=   fetchbuf1_rfw;
				iqentry_tgt  [tail1]    <=   fnTargetReg(fetchbuf1_instr);
				iqentry_exc  [tail1]    <=   `EXC_NONE;
				// Look at the previous queue slot to see if an immediate prefix is enqueued
				if (iqentry_v[tail0-3'd1]==`VAL && iqentry_op[tail0-3'd1]==`IMM && !fnIsBranch(opcode1))
					iqentry_a0[tail0]   <=   {iqentry_a0[tail0-3'd1][DBW-1:8],fnImm(fetchbuf1_instr)};
				else
					iqentry_a0[tail0]   <=  fnIsBranch(opcode1) ? {{DBW-12{fetchbuf1_instr[11]}},fetchbuf1_instr[11:8],fetchbuf1_instr[23:16]} : 
											{{DBW-8{fnImmMSB(fetchbuf1_instr)}},fnImm(fetchbuf1_instr)};
				iqentry_a1   [tail1]    <=   fnIsFlowCtrl(opcode1) ? bregs1 : rfoa1;
				iqentry_a2   [tail1]    <=   fnIsShiftiop(opcode1) ? {58'b0,Rb1[5:0]} : rfob1;
				// a1/a2_v and a1/a2_s values require a bit of thinking ...

				//
				// SOURCE 1 ... this is relatively straightforward, because all instructions
				// that have a source (i.e. every instruction but LUI) read from RB
				//
				// if the argument is an immediate or not needed, we're done
				if (fnSource1_v( opcode1 ) == `VAL) begin
					iqentry_a1_v [tail1] <= `VAL;
					iqentry_a1_s [tail1] <= 4'd0;
				end
				// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
				else if (~fetchbuf0_rfw) begin
					iqentry_a1_v [tail1]    <=   rf_v [fnRa(fetchbuf1_instr)];
					iqentry_a1_s [tail1]    <=   rf_source [fnRa(fetchbuf1_instr)];
				end
				// otherwise, previous instruction does write to RF ... see if overlap
				else if (fnTargetReg(fetchbuf0_instr) != 9'd0
					&& fnRa(fetchbuf1_instr) == fnTargetReg(fetchbuf0_instr)) begin
					// if the previous instruction is a LW, then grab result from memq, not the iq
					iqentry_a1_v [tail1]    <=   `INV;
					iqentry_a1_s [tail1]    <=   { fetchbuf0_mem, tail0 };
				end
				// if no overlap, get info from rf_v and rf_source
				else begin
					iqentry_a1_v [tail1]    <=   rf_v [fnRa(fetchbuf1_instr)];
					iqentry_a1_s [tail1]    <=   rf_source [fnRa(fetchbuf1_instr)];
				end

				//
				// SOURCE 2 ... this is more contorted than the logic for SOURCE 1 because
				// some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
				//
				// if the argument is an immediate or not needed, we're done
				if (fnSource2_v( opcode1 ) == `VAL) begin
					iqentry_a2_v [tail1] <= `VAL;
					iqentry_a2_s [tail1] <= 4'd0;
				end
				// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
				else if (~fetchbuf0_rfw) begin
					iqentry_a2_v [tail1] <= rf_v[ Rb1 ];
					iqentry_a2_s [tail1] <= rf_source[Rb1];
				end
				// otherwise, previous instruction does write to RF ... see if overlap
				else if (fnTargetReg(fetchbuf0_instr) != 9'd0 &&
					Rb1 == fnTargetReg(fetchbuf0_instr)) begin
					// if the previous instruction is a LW, then grab result from memq, not the iq
					iqentry_a2_v [tail1]    <=   `INV;
					iqentry_a2_s [tail1]    <=   { fetchbuf0_mem, tail0 };
				end
				// if no overlap, get info from rf_v and rf_source
				else begin
					iqentry_a2_v [tail1] <= rf_v[ Rb1 ];
					iqentry_a2_s [tail1] <= rf_source[Rb1];
				end

				//
				// if the two instructions enqueued target the same register, 
				// make sure only the second writes to rf_v and rf_source.
				// first is allowed to update rf_v and rf_source only if the
				// second has no target (BEQ or SW)
				//
				if (fnTargetReg(fetchbuf0_instr) == fnTargetReg(fetchbuf1_instr)) begin
					if (fetchbuf1_rfw) begin
						rf_v[ fnTargetReg(fetchbuf1_instr) ] <= `INV;
						rf_source[ fnTargetReg(fetchbuf1_instr) ] <= { fetchbuf1_mem, tail1 };
					end
					else if (fetchbuf0_rfw) begin
						rf_v[ fnTargetReg(fetchbuf0_instr) ] <= `INV;
						rf_source[ fnTargetReg(fetchbuf0_instr) ] <= { fetchbuf0_mem, tail0 };
					end
				end
				else begin
					if (fetchbuf0_rfw) begin
						rf_v[ fnTargetReg(fetchbuf0_instr) ] <= `INV;
						rf_source[ fnTargetReg(fetchbuf0_instr) ] <= { fetchbuf0_mem, tail0 };
					end
					if (fetchbuf1_rfw) begin
					rf_v[ fnTargetReg(fetchbuf1_instr) ] <= `INV;
					rf_source[ fnTargetReg(fetchbuf1_instr) ] <= { fetchbuf1_mem, tail1 };
					end
				end

				end	// ends the "if IQ[tail1] is available" clause
				else begin	// only first instruction was enqueued
				if (fetchbuf0_rfw) begin
					rf_v[ fnTargetReg(fetchbuf0_instr) ] <= `INV;
					rf_source[ fnTargetReg(fetchbuf0_instr) ] <= {fetchbuf0_mem, tail0};
				end
				end

			end	// ends the "else fetchbuf0 doesn't have a backwards branch" clause
			end
		endcase
		else begin	// if branchmiss
			if (iqentry_stomp[0] & ~iqentry_stomp[7]) begin
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
		end