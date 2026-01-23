module string_filter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str_in,
    input wire [127:0] filter_str,
    input wire [4:0] str_len,
    output reg [127:0] result,
    output reg [4:0] result_len,
    output reg done
);

    // State encoding
    localparam IDLE      = 3'b000;
    localparam INIT_LUT  = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam PACKING   = 3'b100;
    localparam DONE      = 3'b101;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // LUT: 256-entry lookup table
    reg [0:0] lut [0:255];
    
    // Intermediate output buffer: 16 bytes
    reg [7:0] out_buffer [0:15];
    
    // Counters and indices
    reg [3:0] idx;             // General index (0-15)
    reg [3:0] proc_idx;        // Processing index for str_in
    reg [3:0] write_idx;       // Write index for out_buffer
    reg [4:0] valid_len;       // Valid length tracking

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            result <= 128'b0;
            result_len <= 5'b0;
            done <= 1'b0;
            idx <= 4'b0;
            proc_idx <= 4'b0;
            write_idx <= 4'b0;
            valid_len <= 5'b0;
            // Clear LUT
            // Note: In synthesizable code, we usually don't reset arrays explicitly in block
            // But we rely on the FSM to manage states correctly.
            // To strictly follow reset requirements, we might need a loop, but unrolling is safer for synthesis.
            lut[0] <= 1'b0; lut[1] <= 1'b0; lut[2] <= 1'b0; lut[3] <= 1'b0;
            lut[4] <= 1'b0; lut[5] <= 1'b0; lut[6] <= 1'b0; lut[7] <= 1'b0;
            lut[8] <= 1'b0; lut[9] <= 1'b0; lut[10] <= 1'b0; lut[11] <= 1'b0;
            lut[12] <= 1'b0; lut[13] <= 1'b0; lut[14] <= 1'b0; lut[15] <= 1'b0;
            lut[16] <= 1'b0; lut[17] <= 1'b0; lut[18] <= 1'b0; lut[19] <= 1'b0;
            lut[20] <= 1'b0; lut[21] <= 1'b0; lut[22] <= 1'b0; lut[23] <= 1'b0;
            lut[24] <= 1'b0; lut[25] <= 1'b0; lut[26] <= 1'b0; lut[27] <= 1'b0;
            lut[28] <= 1'b0; lut[29] <= 1'b0; lut[30] <= 1'b0; lut[31] <= 1'b0;
            lut[32] <= 1'b0; lut[33] <= 1'b0; lut[34] <= 1'b0; lut[35] <= 1'b0;
            lut[36] <= 1'b0; lut[37] <= 1'b0; lut[38] <= 1'b0; lut[39] <= 1'b0;
            lut[40] <= 1'b0; lut[41] <= 1'b0; lut[42] <= 1'b0; lut[43] <= 1'b0;
            lut[44] <= 1'b0; lut[45] <= 1'b0; lut[46] <= 1'b0; lut[47] <= 1'b0;
            lut[48] <= 1'b0; lut[49] <= 1'b0; lut[50] <= 1'b0; lut[51] <= 1'b0;
            lut[52] <= 1'b0; lut[53] <= 1'b0; lut[54] <= 1'b0; lut[55] <= 1'b0;
            lut[56] <= 1'b0; lut[57] <= 1'b0; lut[58] <= 1'b0; lut[59] <= 1'b0;
            lut[60] <= 1'b0; lut[61] <= 1'b0; lut[62] <= 1'b0; lut[63] <= 1'b0;
            lut[64] <= 1'b0; lut[65] <= 1'b0; lut[66] <= 1'b0; lut[67] <= 1'b0;
            lut[68] <= 1'b0; lut[69] <= 1'b0; lut[70] <= 1'b0; lut[71] <= 1'b0;
            lut[72] <= 1'b0; lut[73] <= 1'b0; lut[74] <= 1'b0; lut[75] <= 1'b0;
            lut[76] <= 1'b0; lut[77] <= 1'b0; lut[78] <= 1'b0; lut[79] <= 1'b0;
            lut[80] <= 1'b0; lut[81] <= 1'b0; lut[82] <= 1'b0; lut[83] <= 1'b0;
            lut[84] <= 1'b0; lut[85] <= 1'b0; lut[86] <= 1'b0; lut[87] <= 1'b0;
            lut[88] <= 1'b0; lut[89] <= 1'b0; lut[90] <= 1'b0; lut[91] <= 1'b0;
            lut[92] <= 1'b0; lut[93] <= 1'b0; lut[94] <= 1'b0; lut[95] <= 1'b0;
            lut[96] <= 1'b0; lut[97] <= 1'b0; lut[98] <= 1'b0; lut[99] <= 1'b0;
            lut[100] <= 1'b0; lut[101] <= 1'b0; lut[102] <= 1'b0; lut[103] <= 1'b0;
            lut[104] <= 1'b0; lut[105] <= 1'b0; lut[106] <= 1'b0; lut[107] <= 1'b0;
            lut[108] <= 1'b0; lut[109] <= 1'b0; lut[110] <= 1'b0; lut[111] <= 1'b0;
            lut[112] <= 1'b0; lut[113] <= 1'b0; lut[114] <= 1'b0; lut[115] <= 1'b0;
            lut[116] <= 1'b0; lut[117] <= 1'b0; lut[118] <= 1'b0; lut[119] <= 1'b0;
            lut[120] <= 1'b0; lut[121] <= 1'b0; lut[122] <= 1'b0; lut[123] <= 1'b0;
            lut[124] <= 1'b0; lut[125] <= 1'b0; lut[126] <= 1'b0; lut[127] <= 1'b0;
            lut[128] <= 1'b0; lut[129] <= 1'b0; lut[130] <= 1'b0; lut[131] <= 1'b0;
            lut[132] <= 1'b0; lut[133] <= 1'b0; lut[134] <= 1'b0; lut[135] <= 1'b0;
            lut[136] <= 1'b0; lut[137] <= 1'b0; lut[138] <= 1'b0; lut[139] <= 1'b0;
            lut[140] <= 1'b0; lut[141] <= 1'b0; lut[142] <= 1'b0; lut[143] <= 1'b0;
            lut[144] <= 1'b0; lut[145] <= 1'b0; lut[146] <= 1'b0; lut[147] <= 1'b0;
            lut[148] <= 1'b0; lut[149] <= 1'b0; lut[150] <= 1'b0; lut[151] <= 1'b0;
            lut[152] <= 1'b0; lut[153] <= 1'b0; lut[154] <= 1'b0; lut[155] <= 1'b0;
            lut[156] <= 1'b0; lut[157] <= 1'b0; lut[158] <= 1'b0; lut[159] <= 1'b0;
            lut[160] <= 1'b0; lut[161] <= 1'b0; lut[162] <= 1'b0; lut[163] <= 1'b0;
            lut[164] <= 1'b0; lut[165] <= 1'b0; lut[166] <= 1'b0; lut[167] <= 1'b0;
            lut[168] <= 1'b0; lut[169] <= 1'b0; lut[170] <= 1'b0; lut[171] <= 1'b0;
            lut[172] <= 1'b0; lut[173] <= 1'b0; lut[174] <= 1'b0; lut[175] <= 1'b0;
            lut[176] <= 1'b0; lut[177] <= 1'b0; lut[178] <= 1'b0; lut[179] <= 1'b0;
            lut[180] <= 1'b0; lut[181] <= 1'b0; lut[182] <= 1'b0; lut[183] <= 1'b0;
            lut[184] <= 1'b0; lut[185] <= 1'b0; lut[186] <= 1'b0; lut[187] <= 1'b0;
            lut[188] <= 1'b0; lut[189] <= 1'b0; lut[190] <= 1'b0; lut[191] <= 1'b0;
            lut[192] <= 1'b0; lut[193] <= 1'b0; lut[194] <= 1'b0; lut[195] <= 1'b0;
            lut[196] <= 1'b0; lut[197] <= 1'b0; lut[198] <= 1'b0; lut[199] <= 1'b0;
            lut[200] <= 1'b0; lut[201] <= 1'b0; lut[202] <= 1'b0; lut[203] <= 1'b0;
            lut[204] <= 1'b0; lut[205] <= 1'b0; lut[206] <= 1'b0; lut[207] <= 1'b0;
            lut[208] <= 1'b0; lut[209] <= 1'b0; lut[210] <= 1'b0; lut[211] <= 1'b0;
            lut[212] <= 1'b0; lut[213] <= 1'b0; lut[214] <= 1'b0; lut[215] <= 1'b0;
            lut[216] <= 1'b0; lut[217] <= 1'b0; lut[218] <= 1'b0; lut[219] <= 1'b0;
            lut[220] <= 1'b0; lut[221] <= 1'b0; lut[222] <= 1'b0; lut[223] <= 1'b0;
            lut[224] <= 1'b0; lut[225] <= 1'b0; lut[226] <= 1'b0; lut[227] <= 1'b0;
            lut[228] <= 1'b0; lut[229] <= 1'b0; lut[230] <= 1'b0; lut[231] <= 1'b0;
            lut[232] <= 1'b0; lut[233] <= 1'b0; lut[234] <= 1'b0; lut[235] <= 1'b0;
            lut[236] <= 1'b0; lut[237] <= 1'b0; lut[238] <= 1'b0; lut[239] <= 1'b0;
            lut[240] <= 1'b0; lut[241] <= 1'b0; lut[242] <= 1'b0; lut[243] <= 1'b0;
            lut[244] <= 1'b0; lut[245] <= 1'b0; lut[246] <= 1'b0; lut[247] <= 1'b0;
            lut[248] <= 1'b0; lut[249] <= 1'b0; lut[250] <= 1'b0; lut[251] <= 1'b0;
            lut[252] <= 1'b0; lut[253] <= 1'b0; lut[254] <= 1'b0; lut[255] <= 1'b0;
            
            // Clear output buffer (optional but good practice)
            out_buffer[0] <= 8'b0; out_buffer[1] <= 8'b0; out_buffer[2] <= 8'b0; out_buffer[3] <= 8'b0;
            out_buffer[4] <= 8'b0; out_buffer[5] <= 8'b0; out_buffer[6] <= 8'b0; out_buffer[7] <= 8'b0;
            out_buffer[8] <= 8'b0; out_buffer[9] <= 8'b0; out_buffer[10] <= 8'b0; out_buffer[11] <= 8'b0;
            out_buffer[12] <= 8'b0; out_buffer[13] <= 8'b0; out_buffer[14] <= 8'b0; out_buffer[15] <= 8'b0;

        end else begin
            // Default next state assignment
            next_state = current_state;

            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state = INIT_LUT;
                        idx <= 4'b0;
                        done <= 1'b0;
                    end
                end

                INIT_LUT: begin
                    // Build LUT from filter_str
                    // Cycle 1: Read byte 0, set lut
                    if (idx < 16) begin
                        lut[filter_str[idx*8 +: 8]] <= 1'b1;
                        idx <= idx + 1'b1;
                        // Keep staying in this state until all 16 bytes are processed?
                        // With the constraint "1 cycle for initialization", we usually do it in one cycle using a loop.
                        // However, standard synthesizable Verilog prefers sequential execution or unrolled assignment.
                        // Since we need to stay in the state for 1 cycle (as per description), we can unroll the initialization 
                        // in the combinational block for next_state transition or handle it sequentially over multiple cycles.
                        // The requirement says: "1 cycle for initialization (reading filter_str and building LUT)".
                        // This implies a single cycle logic. We will use a combinational logic to update all LUT entries in one cycle 
                        // when entering the state, then move to next state immediately in the same cycle or next.
                        // But since this is a sequential FSM block, we can only do one update per cycle.
                        // Let's interpret the requirement as: 1 cycle latency.
                        // We will unroll the logic to set all LUT bits in this state.
                        // To make it a single cycle operation in FSM context:
                        // We can use combinational logic outside the block or unrolled assignments here.
                        // But we are in a sequential block. 
                        // To strictly follow "1 cycle", we assume we set all bits using combinational-like assignments inside the block.
                        // But 'lut' is a memory. Writing to it takes logic.
                        // Let's change approach: Use combinational logic for LUT initialization or unroll in FSM.
                        // Given the example asks for FSM states, we might need multiple cycles if strictly sequential.
                        // BUT the prompt says "Total latency: 18 cycles (1+16+1)".
                        // This confirms 1 cycle for Init. 
                        // So, in state INIT_LUT, we should trigger the load and move to PROCESSING immediately (or next cycle).
                        // Wait, if we move immediately, we might miss the write enable. 
                        // Let's assume the LUT update happens in the same cycle as the state is active if we are smart about it,
                        // or we use a combinational always block for LUT updates.
                        // However, 'lut' is reg array. 
                        // Alternative: Keep idx, increment every cycle. This takes 16 cycles. 
                        // This would violate the 1 cycle requirement.
                        // To meet 1 cycle requirement for initialization, we must unroll the writes or use a vector assignment.
                        // Since 'lut' is indexed by byte value, we can't easily vectorize it.
                        // Let's assume the requirement implies we can hardcode the updates for the 16 positions.
                        // But we don't know which positions are valid. 
                        // Wait, the prompt says "Read each byte from filter_str (0 to 15)". 
                        // This implies we process 16 bytes. 
                        // Let's reconsider: Is it possible to do it in 1 cycle? 
                        // Yes, by unrolling the assignments for all 16 indices in the combinational logic or sequential block.
                        // But since we are in a sequential block, we can't easily loop. 
                        // I will assume the state transition happens after 1 clock edge. 
                        // I will change the FSM to use 'idx' to process one byte per cycle if that is the only way, 
                        // BUT the requirement is very specific: "1 cycle for initialization".
                        // Let's look at the state list: IDLE, INIT_LUT, PROCESSING, PACKING, DONE.
                        // If INIT_LUT is a state, and latency is 1 cycle, we spend 1 cycle in this state.
                        // During this cycle, we need to load the LUT.
                        // We can do: 
                        // lut[filter_str[7:0]] <= 1;
                        // lut[filter_str[15:8]] <= 1;
                        // ... up to 127:120.
                        // This is verbose but valid.
                        // Let's do that.
                        
                        lut[filter_str[7:0]] <= 1'b1;
                        lut[filter_str[15:8]] <= 1'b1;
                        lut[filter_str[23:16]] <= 1'b1;
                        lut[filter_str[31:24]] <= 1'b1;
                        lut[filter_str[39:32]] <= 1'b1;
                        lut[filter_str[47:40]] <= 1'b1;
                        lut[filter_str[55:48]] <= 1'b1;
                        lut[filter_str[63:56]] <= 1'b1;
                        lut[filter_str[71:64]] <= 1'b1;
                        lut[filter_str[79:72]] <= 1'b1;
                        lut[filter_str[87:80]] <= 1'b1;
                        lut[filter_str[95:88]] <= 1'b1;
                        lut[filter_str[103:96]] <= 1'b1;
                        lut[filter_str[111:104]] <= 1'b1;
                        lut[filter_str[119:112]] <= 1'b1;
                        lut[filter_str[127:120]] <= 1'b1;
                        
                        // Transition immediately to PROCESSING
                        next_state = PROCESSING;
                        proc_idx <= 5'b0;
                        write_idx <= 5'b0;
                        valid_len <= 5'b0;
                        
                        // Clear output buffer indices
                        // Note: We should also clear the output buffer content, or at least track valid entries.
                        // We will overwrite entries as we write.
                        
                    end else begin
                        // Should not happen
                        next_state = PROCESSING;
                        proc_idx <= 5'b0;
                        write_idx <= 5'b0;
                        valid_len <= 5'b0;
                    end
                end

                PROCESSING: begin
                    // Iterate through str_in characters
                    // We need to process str_len characters
                    if (proc_idx < str_len) begin
                        // Check current character
                        // Character is at str_in[proc_idx*8 +: 8]
                        if (!lut[str_in[proc_idx*8 +: 8]]) begin
                            // Not in filter, copy to output buffer
                            out_buffer[write_idx] <= str_in[proc_idx*8 +: 8];
                            write_idx <= write_idx + 1'b1;
                            valid_len <= valid_len + 1'b1;
                        end
                        proc_idx <= proc_idx + 1'b1;
                        // Stay in this state
                    end else begin
                        // Finished processing all characters
                        next_state = PACKING;
                    end
                end

                PACKING: begin
                    // Pack output buffer into result
                    // We need to pack valid_len bytes from out_buffer into result[127:0]
                    // Since out_buffer is an array, we need to assign each byte individually or use a loop in combinational logic.
                    // However, we are in a sequential block. We can unroll the packing if we want to do it in 1 cycle.
                    // Prompt says "1 cycle for packing".
                    // So we must unroll the assignments.
                    // We need to be careful: valid_len determines how many bytes are valid.
                    // The result should be packed to LSB.
                    // Example: out_buffer[0] -> result[7:0], out_buffer[1] -> result[15:8], etc.
                    // We can assign all 16 bytes, but effectively only valid_len matters for result_len.
                    // However, the prompt says "Pack output buffer into result".
                    // Let's assign bytes 0 to 15.
                    
                    result[7:0]   <= out_buffer[0];
                    result[15:8]  <= out_buffer[1];
                    result[23:16] <= out_buffer[2];
                    result[31:24] <= out_buffer[3];
                    result[39:32] <= out_buffer[4];
                    result[47:40] <= out_buffer[5];
                    result[55:48] <= out_buffer[6];
                    result[63:56] <= out_buffer[7];
                    result[71:64] <= out_buffer[8];
                    result[79:72] <= out_buffer[9];
                    result[87:80] <= out_buffer[10];
                    result[95:88] <= out_buffer[11];
                    result[103:96] <= out_buffer[12];
                    result[111:104] <= out_buffer[13];
                    result[119:112] <= out_buffer[14];
                    result[127:120] <= out_buffer[15];
                    
                    result_len <= valid_len;
                    
                    next_state = DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low before accepting new start
                         next_state = IDLE;
                         done <= 1'b0; // Optional: deassert done when returning to idle
                    end else begin
                         // Keep done high until start goes low, or just transition immediately?
                         // Usually, done is high for 1 cycle or until acknowledged.
                         // Prompt says "High when computation complete". 
                         // If we stay in DONE, done stays high. 
                         // Let's transition to IDLE immediately after one cycle, or wait for start to fall.
                         // Let's return to IDLE and deassert done.
                         // The example timing is 18 cycles. Done likely pulses high.
                         // We will stay in DONE for 1 cycle, then go to IDLE.
                    end
                    // Actually, simpler logic: Go to IDLE immediately if start is low, else wait.
                    // Or just stay in DONE until next start.
                    // Let's stay in DONE for 1 clock cycle, then move to IDLE.
                    // But wait, if we are in DONE, on next clock edge, we go to IDLE.
                    // So done will be high for 1 cycle.
                    // Let's implement that.
                    if (start) next_state = DONE; // Hold if start still high? No, usually FSMs need reset or start to low.
                    else next_state = IDLE; // Or go back to IDLE immediately to be ready.
                    // Let's go to IDLE on next cycle.
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

endmodule
