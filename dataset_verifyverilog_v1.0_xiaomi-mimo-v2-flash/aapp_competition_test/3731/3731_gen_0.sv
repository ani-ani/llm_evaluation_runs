module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a_in,
    input wire [3:0] b_in,
    input wire [31:0] l_in,
    input wire [31:0] r_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] GENERATE_SEQ = 3'd1;
    localparam [2:0] CALCULATE    = 3'd2;
    localparam [2:0] DONE_STATE   = 3'd3;
    localparam [2:0] WAIT_DONE    = 3'd4;

    reg [2:0] state, next_state;
    
    // Configuration registers
    reg [3:0] a_reg, b_reg;
    reg [31:0] l_reg, r_reg;
    
    // Sequence storage: 48 entries max (Period <= 48)
    reg [3:0] seq_storage [0:47];
    
    // Generation counter
    reg [5:0] gen_idx; // 0 to 47
    
    // Calculation variables
    reg [31:0] period;
    reg [31:0] len_diff;
    reg [31:0] l_norm, r_norm;
    reg [31:0] calc_idx;
    reg [31:0] calc_end;
    reg [31:0] calc_start;
    reg calc_wrap;
    
    // Distinct counting: letter IDs 0 to a_reg (max 12)
    reg [12:0] seen_mask;
    reg [3:0] current_letter;
    
    // Cycle counter to prevent hangs
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Helper: Distinct count accumulator
    reg [7:0] distinct_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            a_reg <= 4'd0;
            b_reg <= 4'd0;
            l_reg <= 32'd0;
            r_reg <= 32'd0;
            gen_idx <= 6'd0;
            period <= 32'd0;
            len_diff <= 32'd0;
            l_norm <= 32'd0;
            r_norm <= 32'd0;
            calc_idx <= 32'd0;
            calc_start <= 32'd0;
            calc_end <= 32'd0;
            calc_wrap <= 1'b0;
            seen_mask <= 13'd0;
            current_letter <= 4'd0;
            cycle_count <= 8'd0;
            distinct_count <= 8'd0;
            // Initialize seq_storage to 0
            seq_storage[0] <= 4'd0; seq_storage[1] <= 4'd0; seq_storage[2] <= 4'd0; seq_storage[3] <= 4'd0;
            seq_storage[4] <= 4'd0; seq_storage[5] <= 4'd0; seq_storage[6] <= 4'd0; seq_storage[7] <= 4'd0;
            seq_storage[8] <= 4'd0; seq_storage[9] <= 4'd0; seq_storage[10] <= 4'd0; seq_storage[11] <= 4'd0;
            seq_storage[12] <= 4'd0; seq_storage[13] <= 4'd0; seq_storage[14] <= 4'd0; seq_storage[15] <= 4'd0;
            seq_storage[16] <= 4'd0; seq_storage[17] <= 4'd0; seq_storage[18] <= 4'd0; seq_storage[19] <= 4'd0;
            seq_storage[20] <= 4'd0; seq_storage[21] <= 4'd0; seq_storage[22] <= 4'd0; seq_storage[23] <= 4'd0;
            seq_storage[24] <= 4'd0; seq_storage[25] <= 4'd0; seq_storage[26] <= 4'd0; seq_storage[27] <= 4'd0;
            seq_storage[28] <= 4'd0; seq_storage[29] <= 4'd0; seq_storage[30] <= 4'd0; seq_storage[31] <= 4'd0;
            seq_storage[32] <= 4'd0; seq_storage[33] <= 4'd0; seq_storage[34] <= 4'd0; seq_storage[35] <= 4'd0;
            seq_storage[36] <= 4'd0; seq_storage[37] <= 4'd0; seq_storage[38] <= 4'd0; seq_storage[39] <= 4'd0;
            seq_storage[40] <= 4'd0; seq_storage[41] <= 4'd0; seq_storage[42] <= 4'd0; seq_storage[43] <= 4'd0;
            seq_storage[44] <= 4'd0; seq_storage[45] <= 4'd0; seq_storage[46] <= 4'd0; seq_storage[47] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= GENERATE_SEQ;
                        a_reg <= a_in;
                        b_reg <= b_in;
                        l_reg <= l_in;
                        r_reg <= r_in;
                        gen_idx <= 6'd0;
                    end
                end

                GENERATE_SEQ: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Generate sequence based on a and b
                    // Rules:
                    // If b >= a: 2a + 2b length
                    // If b < a: 2a + 2b length (same formula generally holds, but logic differs slightly)
                    // We construct the sequence entry by entry
                    
                    // Simple generation logic based on the problem's periodic nature:
                    // Period = 2*(a+b)
                    // The sequence pattern is roughly:
                    // 0..a-1, then a..2a+b-1, then (2a+b)..(2a+2b-1) (descending), then (2a+2b-1-a)..0
                    // Actually, standard solution logic:
                    // The sequence consists of blocks.
                    // Let's implement a flexible generator.
                    
                    // Calculate period length
                    period <= (a_reg + b_reg) * 2;
                    
                    // Generate character for current gen_idx
                    // We handle the generation in one cycle or split if needed. Since Period <= 48, we can do it in a loop if we were allowed, 
                    // but FSM usually implies state transitions. We will generate one per cycle.
                    
                    // Logic derived from constraints:
                    // Phase 1: 0 to a-1
                    // Phase 2: a to 2a+b-1 (increasing letter count)
                    // Phase 3: 2a+b to 2a+2b-1 (decreasing letter count)
                    // Phase 4: 2a+2b to 2a+3b-1 (decreasing letter count part 2?)
                    // Let's use the standard constructive approach:
                    // Construct sequence T of length Period.
                    // T[i] = i % (a+1) for i in [0, a-1]
                    // T[a + i] = a + 1 + (i % b) ? No, letters are 0..a.
                    // Optimal strategy uses a + 1 distinct letters.
                    // Sequence:
                    // 0..a-1
                    // a..2a+b-1 (values 0..a)
                    // ...
                    // Actually, let's use the explicit construction used in competitive programming solutions for "Mister B and Boring Game":
                    // Sequence S:
                    // Prefix: 0, 1, ..., a-1 (Length a)
                    // Middle: 0, 1, ..., a, ... (Length a+b)
                    // Suffix: ...
                    // Refined Algorithm:
                    // 1. If b >= a: 
                    //    Sequence: 0..a-1, then block of length a+b where letters 0..a appear, then block of length b where letters decrease.
                    //    Actually, the periodic sequence T:
                    //    T = (0, 1, ..., a-1, 0, 1, ..., a) followed by (a, a-1, ..., 0) repeated appropriately to fill period 2(a+b).
                    //    Let's construct T explicitly.
                    
                    if (gen_idx < (a_reg + b_reg)) begin
                        // First half of period: 0..a+b-1
                        // Values: 0, 1, ..., a-1, 0, 1, ..., a
                        if (gen_idx < a_reg) begin
                            seq_storage[gen_idx] <= gen_idx;
                        end else begin
                            // gen_idx >= a
                            // Map (a ... a+b-1) to 0...a
                            // We want to fill with 0..a cyclically.
                            // Simple mapping: (gen_idx - a) % (a+1)
                            seq_storage[gen_idx] <= (gen_idx - a_reg) % (a_reg + 1'b1);
                        end
                    end else begin
                        // Second half of period: a+b .. 2a+2b-1
                        // Values: a, a-1, ..., 0, a, a-1, ...
                        // Index relative to start of second half: k = gen_idx - (a+b)
                        // We want to cycle a..0.
                        // Value = a - (k % (a+1))
                        if (a_reg == 4'd0) begin
                            seq_storage[gen_idx] <= 4'd0;
                        end else begin
                            reg [5:0] k;
                            reg [3:0] val;
                            k = gen_idx - (a_reg + b_reg);
                            val = a_reg - (k % (a_reg + 1'b1));
                            seq_storage[gen_idx] <= val;
                        end
                    end
                    
                    if (gen_idx < 6'd47) begin
                        gen_idx <= gen_idx + 6'd1;
                    end else begin
                        state <= CALCULATE;
                        // Setup calculation vars
                        period <= (a_reg + b_reg) * 2;
                        // Check if range spans full period
                        len_diff <= (r_reg > l_reg) ? (r_reg - l_reg) : (32'd0);
                        
                        // Calculate l_norm and r_norm
                        // (val - 1) % period + 1
                        // We need division for modulo. Since Period is small (<=48), we can do it manually or assume synthesizable modulo.
                        // In Verilog, % is synthesizable for constants/small vars usually, but good to be safe.
                        // We will rely on the synthesizer for 32-bit modulo by small numbers.
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate Normalized Indices (1-based)
                    l_norm <= ((l_reg - 32'd1) % period) + 32'd1;
                    r_norm <= ((r_reg - 32'd1) % period) + 32'd1;
                    
                    // Check full period coverage
                    // If length >= period, distinct count is a_reg + 1
                    if ((r_reg - l_reg) >= period) begin
                        result <= a_reg + 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        // Setup for iteration
                        seen_mask <= 13'd0;
                        distinct_count <= 8'd0;
                        
                        if (l_norm <= r_norm) begin
                            // Normal range
                            calc_start <= l_norm;
                            calc_end <= r_norm;
                            calc_wrap <= 1'b0;
                            calc_idx <= l_norm;
                        end else begin
                            // Wrap around
                            // First segment: l_norm to period
                            // Second segment: 1 to r_norm
                            // We handle first segment then set up for second
                            calc_start <= l_norm;
                            calc_end <= period;
                            calc_wrap <= 1'b1;
                            calc_idx <= l_norm;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= WAIT_DONE;
                end

                WAIT_DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Iterative counting logic (combinational inside sequential)
            // We update during CALCULATE state if we are iterating.
            if (state == CALCULATE && !((r_reg - l_reg) >= period)) begin
                // We need to iterate. Since we are in a sequential block, we can use calc_idx to track.
                // But we need to ensure we don't jump ahead too fast.
                // Wait, in CALCULATE state, we initialize. Then we need to transition to a counting state or count inside CALCULATE.
                // To keep it simple and robust: Add a sub-state or handle iteration in CALCULATE with a flag.
                // Since cycle_count is bounded, we can iterate here. But standard FSM style: 
                // CALCULATE sets up start/end. Then we transition to a counting loop or do it in one go if possible.
                // Given small period, let's just add a COUNTING state.
            end
        end
    end

    // Separate block for counting iteration to avoid single-cycle complexity issues
    // We refine the FSM: CALCULATE sets up, then we go to a COUNTING state.
    // Actually, let's put the counting logic in the CALCULATE block but controlled by a flag.
    // To strictly follow the FSM structure, let's add a COUNT state.
    
    // Modifying the logic:
    // State CALCULATE -> Setup variables -> State COUNT
    // State COUNT -> Iterate -> State DONE
    
    // Let's rewrite the CALCULATE state to handle the iteration or transition to COUNT.
    // I will integrate a simple loop counter in CALCULATE state since max 48 cycles is fine.
    
    // Revising the always block to include COUNTING logic cleanly:
    // Note: The previous CALCULATE state only initialized. 
    // Let's add a flag 'counting' or just transition to a new state.
    
endmodule

// The logic above is incomplete for iteration. Let's rewrite the module cleanly with proper iteration states.

module TopModule_Fixed (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a_in,
    input wire [3:0] b_in,
    input wire [31:0] l_in,
    input wire [31:0] r_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] GENERATE_SEQ = 3'd1;
    localparam [2:0] CALCULATE    = 3'd2;
    localparam [2:0] COUNTING     = 3'd3;
    localparam [2:0] DONE_STATE   = 3'd4;

    reg [2:0] state;
    
    // Registers
    reg [3:0] a_reg, b_reg;
    reg [31:0] l_reg, r_reg;
    reg [31:0] period;
    reg [31:0] l_norm, r_norm;
    
    // Sequence Storage (LUT logic or Array)
    reg [3:0] seq_storage [0:47];
    reg [5:0] gen_idx;
    
    // Counting Variables
    reg [31:0] curr_idx;
    reg [31:0] end_idx;
    reg [12:0] seen_mask;
    reg [7:0] temp_result;
    reg wrap_phase; // 0: first segment, 1: second segment (if wrapped)

    // Helper for modulo (synthesizable for small divisors)
    wire [31:0] l_mod = ((l_reg - 32'd1) % period) + 32'd1;
    wire [31:0] r_mod = ((r_reg - 32'd1) % period) + 32'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            a_reg <= 4'd0;
            b_reg <= 4'd0;
            l_reg <= 32'd0;
            r_reg <= 32'd0;
            period <= 32'd0;
            gen_idx <= 6'd0;
            l_norm <= 32'd0;
            r_norm <= 32'd0;
            curr_idx <= 32'd0;
            end_idx <= 32'd0;
            seen_mask <= 13'd0;
            temp_result <= 8'd0;
            wrap_phase <= 1'b0;
            // Initialize seq_storage to avoid X
            seq_storage[0] <= 4'd0; seq_storage[1] <= 4'd0; seq_storage[2] <= 4'd0; seq_storage[3] <= 4'd0;
            seq_storage[4] <= 4'd0; seq_storage[5] <= 4'd0; seq_storage[6] <= 4'd0; seq_storage[7] <= 4'd0;
            seq_storage[8] <= 4'd0; seq_storage[9] <= 4'd0; seq_storage[10] <= 4'd0; seq_storage[11] <= 4'd0;
            seq_storage[12] <= 4'd0; seq_storage[13] <= 4'd0; seq_storage[14] <= 4'd0; seq_storage[15] <= 4'd0;
            seq_storage[16] <= 4'd0; seq_storage[17] <= 4'd0; seq_storage[18] <= 4'd0; seq_storage[19] <= 4'd0;
            seq_storage[20] <= 4'd0; seq_storage[21] <= 4'd0; seq_storage[22] <= 4'd0; seq_storage[23] <= 4'd0;
            seq_storage[24] <= 4'd0; seq_storage[25] <= 4'd0; seq_storage[26] <= 4'd0; seq_storage[27] <= 4'd0;
            seq_storage[28] <= 4'd0; seq_storage[29] <= 4'd0; seq_storage[30] <= 4'd0; seq_storage[31] <= 4'd0;
            seq_storage[32] <= 4'd0; seq_storage[33] <= 4'd0; seq_storage[34] <= 4'd0; seq_storage[35] <= 4'd0;
            seq_storage[36] <= 4'd0; seq_storage[37] <= 4'd0; seq_storage[38] <= 4'd0; seq_storage[39] <= 4'd0;
            seq_storage[40] <= 4'd0; seq_storage[41] <= 4'd0; seq_storage[42] <= 4'd0; seq_storage[43] <= 4'd0;
            seq_storage[44] <= 4'd0; seq_storage[45] <= 4'd0; seq_storage[46] <= 4'd0; seq_storage[47] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= GENERATE_SEQ;
                        a_reg <= a_in;
                        b_reg <= b_in;
                        l_reg <= l_in;
                        r_reg <= r_in;
                        gen_idx <= 6'd0;
                        period <= (a_in + b_in) << 1; // 2*(a+b)
                    end
                end

                GENERATE_SEQ: begin
                    // Generate one sequence element per cycle
                    if (gen_idx < 6'd48) begin
                        // Logic to fill seq_storage[gen_idx]
                        // Period P = 2*(a+b)
                        // Construct optimal sequence:
                        // 1. 0..a-1
                        // 2. 0..a (repeated b times)
                        // 3. a..0 (repeated b times)
                        // Total length = a + b + b = a + 2b (Wait, optimal is 2a+2b)
                        // Let's use the explicit construction for the periodic T.
                        // T has length 2(a+b).
                        // T[0...a-1] = 0, 1, ..., a-1
                        // T[a...a+b-1] = 0, 1, ..., a-1, a (repeated)
                        // Actually, simpler pattern for this problem:
                        // Cycle of 2(a+b).
                        // First part (length a+b): 0, 1, ..., a, ... (cyclic)
                        // Second part (length a+b): a, a-1, ..., 0, ... (cyclic)
                        
                        if (gen_idx < (a_reg + b_reg)) begin
                            // First half
                            // 0..a-1: index
                            // a..a+b-1: (index-a)%(a+1)
                            if (gen_idx < a_reg)
                                seq_storage[gen_idx] <= gen_idx;
                            else
                                seq_storage[gen_idx] <= (gen_idx - a_reg) % (a_reg + 1'b1);
                        end else begin
                            // Second half (indices a+b to 2a+2b-1)
                            // Indices 0 to a+b-1 in second half
                            // Map to a..0 cyclically
                            if (a_reg > 0) begin
                                reg [5:0] k;
                                k = gen_idx - (a_reg + b_reg);
                                seq_storage[gen_idx] <= a_reg - (k % (a_reg + 1'b1));
                            end else begin
                                seq_storage[gen_idx] <= 4'd0;
                            end
                        end
                        
                        if (gen_idx == (period - 1)) begin
                            state <= CALCULATE;
                        end else begin
                            gen_idx <= gen_idx + 6'd1;
                        end
                    end
                end

                CALCULATE: begin
                    // Determine range and check for full period
                    // Use l_mod and r_mod wires
                    l_norm <= l_mod;
                    r_norm <= r_mod;
                    
                    if ((r_reg - l_reg) >= period) begin
                        // Full period covered
                        result <= a_reg + 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        // Initialize counting
                        seen_mask <= 13'd0;
                        temp_result <= 8'd0;
                        wrap_phase <= 1'b0;
                        
                        if (l_norm <= r_norm) begin
                            // Normal range
                            curr_idx <= l_norm;
                            end_idx <= r_norm;
                        end else begin
                            // Wraps around
                            // First segment: l_norm to period
                            curr_idx <= l_norm;
                            end_idx <= period;
                            wrap_phase <= 1'b1; // Mark that we need a second pass
                        end
                        state <= COUNTING;
                    end
                end

                COUNTING: begin
                    // Process element at curr_idx
                    // Note: curr_idx is 1-based, array is 0-based
                    if (curr_idx <= period && curr_idx > 0) begin
                        // Get letter ID (0..a_reg)
                        // Access seq_storage[curr_idx - 1]
                        // Check if bit is already set in seen_mask
                        // Current letter is seq_storage[curr_idx - 1]
                        // We need to index into seq_storage. 
                        // Since curr_idx changes every cycle, we can use it directly.
                        // seq_storage is indexed by 0..period-1
                        if (seen_mask[seq_storage[curr_idx - 1]] == 1'b0) begin
                            seen_mask[seq_storage[curr_idx - 1]] <= 1'b1;
                            temp_result <= temp_result + 8'd1;
                        end
                        
                        if (curr_idx < end_idx) begin
                            curr_idx <= curr_idx + 32'd1;
                        end else begin
                            // Segment done
                            if (wrap_phase) begin
                                // Start second segment: 1 to r_norm
                                wrap_phase <= 1'b0;
                                curr_idx <= 32'd1;
                                end_idx <= r_norm;
                                // Continue counting
                            end else begin
                                // All done
                                result <= temp_result;
                                state <= DONE_STATE;
                            end
                        end
                    end else begin
                        // Safety
                        state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE; // Return to IDLE immediately, done pulse lasts 1 cycle
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule