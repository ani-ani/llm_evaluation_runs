module find_T (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [15:0] L,
    input wire [7:0] transitions_0_0, transitions_0_1, transitions_0_2, transitions_0_3,
    input wire [7:0] transitions_0_4, transitions_0_5, transitions_0_6, transitions_0_7,
    input wire [7:0] transitions_1_0, transitions_1_1, transitions_1_2, transitions_1_3,
    input wire [7:0] transitions_1_4, transitions_1_5, transitions_1_6, transitions_1_7,
    input wire [7:0] transitions_2_0, transitions_2_1, transitions_2_2, transitions_2_3,
    input wire [7:0] transitions_2_4, transitions_2_5, transitions_2_6, transitions_2_7,
    input wire [7:0] transitions_3_0, transitions_3_1, transitions_3_2, transitions_3_3,
    input wire [7:0] transitions_3_4, transitions_3_5, transitions_3_6, transitions_3_7,
    input wire [7:0] transitions_4_0, transitions_4_1, transitions_4_2, transitions_4_3,
    input wire [7:0] transitions_4_4, transitions_4_5, transitions_4_6, transitions_4_7,
    input wire [7:0] transitions_5_0, transitions_5_1, transitions_5_2, transitions_5_3,
    input wire [7:0] transitions_5_4, transitions_5_5, transitions_5_6, transitions_5_7,
    input wire [7:0] transitions_6_0, transitions_6_1, transitions_6_2, transitions_6_3,
    input wire [7:0] transitions_6_4, transitions_6_5, transitions_6_6, transitions_6_7,
    input wire [7:0] transitions_7_0, transitions_7_1, transitions_7_2, transitions_7_3,
    input wire [7:0] transitions_7_4, transitions_7_5, transitions_7_6, transitions_7_7,
    output reg done,
    output reg result_valid,
    output reg [15:0] T_out
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] NORMALIZE = 3'd1;
    localparam [2:0] ITERATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Constants
    localparam [15:0] TARGET = 16'd62259; // 0.95 * 65536
    localparam [15:0] MAX_T = 16'd10;     // Check 10 values (L to L+9)
    localparam [7:0] MAX_CYCLES = 8'd200; // Safety timeout

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [7:0] row_idx, col_idx, acc_idx; // Loop counters
    reg [7:0] max_row; // Node count - 1 (N-1)
    reg [15:0] current_t;
    reg [31:0] transition_matrix [0:7][0:7]; // Q16.16 normalized probabilities
    reg [31:0] state_vec [0:7]; // Q16.16 probabilities
    reg [31:0] next_state_vec [0:7];
    reg [31:0] row_sum;
    reg [31:0] mult_temp;
    reg [31:0] acc;
    reg match_found;

    // Combinational logic for normalization and transitions
    wire [7:0] trans_in [0:7][0:7];
    assign trans_in[0][0] = transitions_0_0;
    assign trans_in[0][1] = transitions_0_1;
    assign trans_in[0][2] = transitions_0_2;
    assign trans_in[0][3] = transitions_0_3;
    assign trans_in[0][4] = transitions_0_4;
    assign trans_in[0][5] = transitions_0_5;
    assign trans_in[0][6] = transitions_0_6;
    assign trans_in[0][7] = transitions_0_7;
    assign trans_in[1][0] = transitions_1_0;
    assign trans_in[1][1] = transitions_1_1;
    assign trans_in[1][2] = transitions_1_2;
    assign trans_in[1][3] = transitions_1_3;
    assign trans_in[1][4] = transitions_1_4;
    assign trans_in[1][5] = transitions_1_5;
    assign trans_in[1][6] = transitions_1_6;
    assign trans_in[1][7] = transitions_1_7;
    assign trans_in[2][0] = transitions_2_0;
    assign trans_in[2][1] = transitions_2_1;
    assign trans_in[2][2] = transitions_2_2;
    assign trans_in[2][3] = transitions_2_3;
    assign trans_in[2][4] = transitions_2_4;
    assign trans_in[2][5] = transitions_2_5;
    assign trans_in[2][6] = transitions_2_6;
    assign trans_in[2][7] = transitions_2_7;
    assign trans_in[3][0] = transitions_3_0;
    assign trans_in[3][1] = transitions_3_1;
    assign trans_in[3][2] = transitions_3_2;
    assign trans_in[3][3] = transitions_3_3;
    assign trans_in[3][4] = transitions_3_4;
    assign trans_in[3][5] = transitions_3_5;
    assign trans_in[3][6] = transitions_3_6;
    assign trans_in[3][7] = transitions_3_7;
    assign trans_in[4][0] = transitions_4_0;
    assign trans_in[4][1] = transitions_4_1;
    assign trans_in[4][2] = transitions_4_2;
    assign trans_in[4][3] = transitions_4_3;
    assign trans_in[4][4] = transitions_4_4;
    assign trans_in[4][5] = transitions_4_5;
    assign trans_in[4][6] = transitions_4_6;
    assign trans_in[4][7] = transitions_4_7;
    assign trans_in[5][0] = transitions_5_0;
    assign trans_in[5][1] = transitions_5_1;
    assign trans_in[5][2] = transitions_5_2;
    assign trans_in[5][3] = transitions_5_3;
    assign trans_in[5][4] = transitions_5_4;
    assign trans_in[5][5] = transitions_5_5;
    assign trans_in[5][6] = transitions_5_6;
    assign trans_in[5][7] = transitions_5_7;
    assign trans_in[6][0] = transitions_6_0;
    assign trans_in[6][1] = transitions_6_1;
    assign trans_in[6][2] = transitions_6_2;
    assign trans_in[6][3] = transitions_6_3;
    assign trans_in[6][4] = transitions_6_4;
    assign trans_in[6][5] = transitions_6_5;
    assign trans_in[6][6] = transitions_6_6;
    assign trans_in[6][7] = transitions_6_7;
    assign trans_in[7][0] = transitions_7_0;
    assign trans_in[7][1] = transitions_7_1;
    assign trans_in[7][2] = transitions_7_2;
    assign trans_in[7][3] = transitions_7_3;
    assign trans_in[7][4] = transitions_7_4;
    assign trans_in[7][5] = transitions_7_5;
    assign trans_in[7][6] = transitions_7_6;
    assign trans_in[7][7] = transitions_7_7;

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = NORMALIZE;
                else next_state = IDLE;
            end
            NORMALIZE: begin
                // Normalize takes 64 cycles (row_idx 0-7, col_idx 0-7)
                if (row_idx == 8'd7 && col_idx == 8'd7) next_state = ITERATE;
                else next_state = NORMALIZE;
            end
            ITERATE: begin
                // Multiply takes 64 cycles per iteration (row_idx 0-7, acc_idx 0-7)
                // Check match takes 1 cycle
                // If match found or T > L+9, go to DONE
                // Note: row_idx resets to 0 for next iteration or check
                if (match_found || current_t >= (L + 16'd9) || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else if (row_idx == 8'd7 && acc_idx == 8'd7) begin
                    // Done with multiply for this T, next T
                    if (col_idx == 8'd7) next_state = DONE_STATE; // Wait for check
                    else next_state = ITERATE; // Keep in ITERATE state, counters advance
                end else begin
                    next_state = ITERATE;
                end
            end
            DONE_STATE: begin
                if (!start) next_state = IDLE; // Wait for start to go low
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            T_out <= 16'd0;
            done <= 1'b0;
            row_idx <= 8'd0;
            col_idx <= 8'd0;
            acc_idx <= 8'd0;
            current_t <= 16'd0;
            match_found <= 1'b0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                state_vec[i] <= 32'd0;
                next_state_vec[i] <= 32'd0;
                max_row <= 8'd0;
                for (int j = 0; j < 8; j = j + 1) begin
                    transition_matrix[i][j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    T_out <= 16'd0;
                    cycle_count <= 8'd0;
                    match_found <= 1'b0;
                    if (start) begin
                        // Initialize logic for new start
                        max_row <= (N > 4'd0) ? (N - 4'd1) : 8'd7; // Max index to check
                        current_t <= L;
                        // Set initial state: 1.0 at node 1 (index 0)
                        state_vec[0] <= 32'd65536;
                        for (int k = 1; k < 8; k = k + 1) begin
                            state_vec[k] <= 32'd0;
                        end
                        row_idx <= 8'd0;
                        col_idx <= 8'd0;
                    end
                end

                NORMALIZE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute row sum
                    if (col_idx == 8'd0) row_sum <= 32'd0;
                    
                    row_sum <= row_sum + {24'd0, trans_in[row_idx][col_idx]};

                    // Compute prob and store
                    // We need to wait until row_sum is complete. 
                    // However, unrolled loop means we process one element per cycle.
                    // To be safe and correct: Sum all 8 elements first? 
                    // Requirement says 64 cycles. We can accumulate sum on the fly if we assume trans_in is available immediately.
                    // Let's re-calculate sum in parallel or just accept 1 cycle delay for sum.
                    // Optimized: We can compute the inverse of the sum or just store raw counts then divide.
                    // To fit 64 cycles: We must compute sum in parallel or use previous cycle's sum.
                    // Actually, a better approach for unrolled loop:
                    // Just do: prob = count * 65536 / sum.
                    // We need the sum first. Let's do a separate sum pass (8 cycles) then normalization pass (64 cycles)?
                    // Too many cycles. 
                    // Let's cheat: Sum is at most 8*255=2040. 65536/sum can be precalculated if we had a divider.
                    // We don't have a divider. 
                    // Let's use a sequential divider or calculate sum first.
                    // To fit 64 cycles exactly: we need to calculate sum in row_idx=0, col_idx=0..7 (8 cycles) -> wait.
                    // Let's change FSM logic slightly: 
                    // In NORMALIZE state:
                    // If row_idx < 8: accumulate sum. If col_idx == 7: switch to computing probabilities for this row.
                    // Let's stick to the 64 cycle requirement. 
                    // Assume we can calculate sum in the first 8 cycles of the row.
                    // We will calculate sum in the first 8 cycles, then compute probabilities in the next 8 cycles? 
                    // That's 16 cycles per row = 128 cycles. Too slow.
                    // Alternative: Use row_sum accumulated from previous iterations (rolling sum).
                    // Since we reset row_idx to 0 each time, we need to recalculate sum.
                    // Let's calculate sum in the first 8 cycles of the iteration (row_idx fixed, col_idx 0-7).
                    // Then compute probs in next 8 cycles (row_idx fixed, col_idx 8-15).
                    // This requires extending the state or changing counters.
                    // Given strict cycle constraints, let's assume we can do sum calculation in parallel with previous iteration or use a smaller bit width for sum.
                    // Let's use a helper counter for normalization.
                    
                    // Revised Normalization Logic:
                    // We will use row_idx as the row index (0-7).
                    // We will use col_idx to count 0-15.
                    // 0-7: Accumulate sum.
                    // 8-15: Compute probability and store.
                    
                    if (col_idx < 8'd8) begin
                        // Accumulating sum phase
                        if (col_idx == 8'd0) row_sum <= {24'd0, trans_in[row_idx][0]};
                        else row_sum <= row_sum + {24'd0, trans_in[row_idx][col_idx]};
                    end else begin
                        // Computing probability phase
                        // col_idx 8 -> element 0, col_idx 15 -> element 7
                        if (row_sum > 32'd0) begin
                            // prob = (count * 65536) / sum
                            // Integer division: (count << 16) / sum
                            // We don't have a divider unit. 
                            // To avoid division, we must use a shift approximation or precomputed table.
                            // Or, we can use the fact that we just need to multiply by inverse.
                            // Let's do standard integer division (iterative) but that takes cycles.
                            // To meet 64 cycles: we must skip division or use a simpler approximation.
                            // Given constraints, let's assume we can use a lookup table for 1/sum (Q16.16).
                            // But sum varies.
                            // Let's use a simple divider logic. 
                            // Since we have 8 cycles per row for calculation, we can do a 16-bit shift subtract divider in 8 cycles.
                            // Let's implement a simplified division: count * 65536 / sum.
                            // We will compute this using a temporary register `mult_temp`.
                            
                            // Actually, the prompt says "8x8 unrolled loops (max 64 ops)".
                            // This implies we can do one multiply-accumulate per cycle.
                            // Normalization is separate.
                            // Let's just perform normalization in 64 cycles using a simplified division or shift.
                            // We will use the formula: Prob = (Edges * 65536) / Sum.
                            // We will calculate this in the 8 cycles after sum accumulation.
                            
                            // Let's assume we have a multiplier (standard in ASIC).
                            // Mult = Edges * Inverse(Sum).
                            // We can't compute Inverse(Sum) without a divider.
                            // We will implement a sequential divider.
                            
                            // Let's calculate: (Edges << 16) / Sum.
                            // We will use `acc` as the division accumulator.
                            // Actually, let's stick to the prompt's "64 cycles" constraint.
                            // Maybe they mean 64 multiplies, not strictly 64 cycles for normalization.
                            // But prompt says: "Normalization: 8*8 = 64 cycles".
                            
                            // Let's use a simpler approach: Prob = Edges * (65536 / Sum).
                            // Since Sum is small (<= 2040), 65536/Sum is large (>= 32).
                            // We can precompute a LUT for 65536/Sum if Sum is limited.
                            // Or, we can accept 2 cycles per element: 1 for sum, 1 for mult.
                            // Let's just store the raw counts in transition_matrix for now and normalize during multiplication.
                            // Wait, "Normalize transition matrix" is step 1.
                            
                            // Let's do this: 
                            // Row Sum calculation: 8 cycles (fixed loop).
                            // Prob Calculation: 8 cycles (fixed loop).
                            // Total 16 cycles per row = 128 cycles. 
                            // If we must do 64 cycles total, we must overlap.
                            // Let's assume we compute the sum in the first 8 cycles of the whole matrix (row 0).
                            // Then we compute probs for row 0 in the next 8. 
                            // Then row 1... 
                            // This is 16*8 = 128 cycles.
                            // To fit 64 cycles: We can use a look-up table for division (1/Sum).
                            // Since Sum is 8-bit, 1/Sum can be approximated.
                            // Let's implement a simple LUT for 1/Sum (scaled by 65536).
                            // Actually, we can just use a 16-bit divider implementation.
                            
                            // Let's try to fit it in 64 cycles by doing:
                            // Cycle 0-7: Calculate sums for all rows in parallel? No, 8 rows.
                            // Let's just do it in 64 cycles assuming we have a fast divider.
                            // We will use a state counter `norm_state` (0-63).
                            // norm_state 0-7: Sum row 0
                            // norm_state 8-15: Prob row 0
                            // ...
                            // We need more counters.
                            
                            // Let's simplify: Store raw counts. 
                            // During Iteration, multiply by (65536 / Sum).
                            // This requires division every multiply. Too slow.
                            
                            // Let's assume standard divider latency is acceptable or we use a LUT.
                            // I will use a LUT approximation or just standard division if space permits.
                            // Given Verilog, I will write the division logic.
                            
                            // Revision: 
                            // 1. Calculate Sum of Row X (8 cycles).
                            // 2. Compute Prob = (Edge * 65536) / Sum (8 cycles).
                            // This takes 16 cycles per row. 128 cycles total.
                            // The prompt allows 800 cycles. "Total < 800 cycles".
                            // 128 + 640 = 768. This fits!
                            // So we can use 128 cycles for normalization.
                            // The prompt says "Normalization: 8*8 = 64 cycles". This is likely an estimation.
                            // Let's try to be efficient. 
                            // We will use `col_idx` 0-7 for accumulation, 8-15 for computation.
                        end
                        
                        // Logic for division:
                        // We need to compute (trans_in[row_idx][col_idx-8] * 65536) / row_sum.
                        // We will use a shift-add divider.
                    end
                    
                    // To strictly follow the "64 cycles" hint, let's assume a simplified scenario:
                    // We store the normalized value directly.
                    // Let's implement the division.
                    
                    // Accumulate Sum
                    if (col_idx < 8'd8) begin
                        if (col_idx == 8'd0) row_sum <= 32'd0;
                        row_sum <= row_sum + {24'd0, trans_in[row_idx][col_idx]};
                        // Move to next element
                        if (col_idx == 8'd7) begin
                            col_idx <= 8'd8; // Switch to calc phase
                        end else begin
                            col_idx <= col_idx + 8'd1;
                        end
                    end else begin
                        // Calculation phase (col_idx 8 to 15)
                        // Element index = col_idx - 8
                        // We need a divider. 
                        // Since we have 8 cycles (for col_idx 8-15), we can run a divider for 8 bits.
                        // Let's use a sequential divider.
                        
                        // We will use `mult_temp` as the dividend (edges << 16).
                        // We will use `acc` as the quotient.
                        // We will use `row_sum` as the divisor.
                        // We need a counter for the division steps.
                        // Let's use `acc_idx` for division steps (0-15).
                        
                        if (col_idx == 8'd8) begin
                            // Start new division
                            mult_temp <= {trans_in[row_idx][0], 16'd0}; // edges * 65536
                            acc <= 32'd0;
                            acc_idx <= 8'd16; // 16-bit division
                        end
                        
                        // Division Logic (Restoring)
                        if (acc_idx > 8'd0) begin
                            acc <= {acc[30:0], 1'b0};
                            mult_temp <= {mult_temp[30:0], 1'b0};
                            acc_idx <= acc_idx - 8'd1;
                            
                            if (mult_temp[31:16] >= row_sum[15:0]) begin // Check overflow of 16-bit portion
                                // Correction: Mult_temp is 32-bit? No, edges << 16 is 24-bit.
                                // Let's treat mult_temp as 32-bit total.
                                // Divisor is row_sum (32-bit value).
                                // If mult_temp >= row_sum:
                                acc[0] <= 1'b1;
                                mult_temp <= mult_temp - row_sum;
                            end
                        end else begin
                            // Division complete for current element
                            // Store result
                            transition_matrix[row_idx][col_idx - 8'd8] <= acc;
                            
                            // Next element
                            if (col_idx < 8'd15) begin
                                col_idx <= col_idx + 8'd1;
                                // Reset for next element division
                                mult_temp <= {trans_in[row_idx][col_idx - 8'd7], 16'd0};
                                acc <= 32'd0;
                                acc_idx <= 8'd16;
                            end else begin
                                // Next row
                                col_idx <= 8'd0;
                                if (row_idx < 8'd7) begin
                                    row_idx <= row_idx + 8'd1;
                                end else begin
                                    // Normalization complete
                                    row_idx <= 8'd0; // Reset for iteration
                                end
                            end
                        end
                    end
                end

                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Matrix Multiplication: next_state_vec = state_vec * transition_matrix
                    // next_state_vec[j] = sum_i (state_vec[i] * transition_matrix[i][j])
                    // We iterate over target node j (col_idx 0-7)
                    // and source node i (row_idx 0-7)
                    // Accumulation over i (acc_idx 0-7)
                    
                    // Logic:
                    // Reset accumulator when acc_idx == 0 for a specific col_idx.
                    // Multiply state_vec[row_idx] * transition_matrix[row_idx][col_idx].
                    // Accumulate.
                    // When row_idx == max_row (N-1), we stop accumulation (transitions from non-existent nodes are 0).
                    
                    if (acc_idx == 8'd0) begin
                        // Start of accumulation for this column (col_idx)
                        // Initialize accumulator for next_state_vec[col_idx]
                        // We need to update next_state_vec array.
                        // Since we can't easily update a specific element of next_state_vec array in place with accumulation,
                        // we can use a temporary accumulator register `acc`.
                        // Wait, we need to store the result in next_state_vec[col_idx].
                        // We can write to next_state_vec[col_idx] when acc_idx wraps around.
                        // Actually, let's compute one element per pass.
                        
                        // Let's iterate:
                        // Outer loop: col_idx (0 to max_row) - Target node
                        // Inner loop: row_idx (0 to max_row) - Source node
                        // Accumulator: acc
                        
                        // If col_idx changed, reset acc to 0.
                        if (col_idx != 8'd7) begin // If this is a new column (not waiting for check)
                             // But we need to handle state updates.
                        end
                    end
                    
                    // We will use a more direct approach:
                    // Cycle 0-63: Compute products and accumulate.
                    // We need to store results in next_state_vec.
                    // Since we can't easily index arrays dynamically in always blocks with complex logic,
                    // let's unroll the loop logic.
                    
                    // State Update Logic:
                    // We have a current state vector `state_vec` (Q16.16).
                    // We have transition matrix `transition_matrix` (Q16.16).
                    // Result is `next_state_vec` (Q16.16).
                    
                    // We will use `col_idx` to select which output node we are calculating (0..7).
                    // We will use `row_idx` to iterate through input nodes (0..7).
                    // We will use `acc` to accumulate the sum.
                    
                    // Reset `acc` when `row_idx` is 0.
                    if (row_idx == 8'd0) begin
                        // For L=0 case, state_vec[0] is 1.0, others 0.
                        // We only multiply if state_vec[row_idx] is non-zero.
                        // But generally, we iterate all.
                        
                        // We need to clear acc before summing for this col_idx.
                        // But col_idx might stay same if we are processing different row_idx.
                        // Actually, standard order: for j in 0..7, sum over i in 0..7.
                        // So: 
                        // Start T iteration:
                        // col_idx = 0, row_idx = 0, acc = 0
                        // Cycle 1: acc += state_vec[0] * trans[0][0]
                        // ...
                        // Cycle 8: acc += state_vec[7] * trans[7][0]. Store to next_state_vec[0]. Reset acc.
                        // Cycle 9: col_idx = 1, row_idx = 0.
                        
                        // In hardware, we can parallelize, but here we are sequential.
                        
                        // Let's track progress with `acc_idx` which represents (col_idx * 8 + row_idx).
                        // But we need to reset acc for each col_idx.
                        
                        if (acc_idx == 8'd0) acc <= 32'd0;
                    end
                    
                    // Multiply and Accumulate
                    // We only process up to max_row (N-1).
                    // If row_idx > max_row, the transition probability is effectively 0.
                    
                    if (row_idx <= max_row) begin
                        // Check if state_vec[row_idx] is non-zero to save power, but let's just compute.
                        // Q16.16 multiply: (A * B) >> 16
                        // Take upper 32 bits of 64-bit result.
                        // A is state_vec[row_idx], B is transition_matrix[row_idx][col_idx].
                        // Intermediate is 64-bit.
                        // Result is 32-bit.
                        
                        // We will use a temporary 64-bit wire for multiplication if available,
                        // or split into logic.
                        // Since we are in a sequential block, let's use a helper or just logic.
                        // Let's assume we have a multiplier.
                        
                        // mult_temp = state_vec[row_idx] * transition_matrix[row_idx][col_idx]
                        // We need to shift right by 16.
                        
                        // We'll calculate: 
                        // acc = acc + ((state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16)
                        
                        // To avoid overflow: acc is 32-bit, but intermediate is larger.
                        // Let's use a 48-bit accumulator `acc_full`.
                        
                        // Since we don't have `acc_full` defined, let's use `acc`.
                        // The result of multiplication is Q32.32. We take Q16.16.
                        // Upper 32 bits of the product.
                        
                        // Let's compute product in combinational logic or use sequential steps.
                        // To save logic, let's use sequential steps.
                        // We will use a multiplier state.
                        // But prompt says "max 64 multiply-accumulate ops".
                        // We'll assume a single-cycle multiply is possible (typical in ASIC).
                        
                        // We will use a helper wire for multiplication result.
                        // Wire [63:0] product = state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                        // Wire [31:0] term = product[47:16];
                        
                        // We need to handle the combinational logic for multiply.
                        // Since we are writing sequential code, we calculate term on the fly.
                        
                        // Note: Verilog multiplication in always block creates latches if not careful.
                        // We will use a separate combinational block for the multiply.
                    end
                    
                    // Logic for the Iterate state:
                    // We use col_idx (0..7) for output node.
                    // We use row_idx (0..7) for input node.
                    // When row_idx wraps, we store acc to next_state_vec[col_idx], then increment col_idx.
                    
                    // If we are at the start of a new column (row_idx == 0):
                    // acc = 0;
                    
                    // Product calculation:
                    // We will use a temporary wire defined outside the always block for product.
                    // But we need to index arrays. 
                    // Let's do it inside using logic.
                    
                    // Calculate product term:
                    // term = (state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16
                    // We'll assume we have a function or block for this.
                    
                    // To implement in pure Verilog without functions (to be safe):
                    // We can use a temporary register `mult_result`.
                    
                    // However, to keep it simple and efficient:
                    // We will update `next_state_vec` at the end of each column calculation.
                    
                    // Iterate Logic:
                    // 1. If row_idx == 0: acc <= 0;
                    // 2. Calculate product = state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                    // 3. acc <= acc + product[47:16];
                    // 4. If row_idx == max_row: next_state_vec[col_idx] <= acc; (Store result)
                    // 5. Increment row_idx.
                    // 6. If row_idx > max_row: set row_idx = 0, increment col_idx.
                    // 7. If col_idx > max_row: Done with multiplication for this T.
                    
                    // Note on max_row: The problem states N nodes. Indices 0..N-1.
                    // We iterate rows 0..N-1.
                    
                    // Check for match:
                    // Once next_state_vec is calculated (i.e., after col_idx wraps),
                    // we compare next_state_vec[N-1] with TARGET.
                    
                    // Refining the loop:
                    // We will use `acc_idx` to track progress (0 to 63).
                    // `acc_idx` = row_idx + col_idx * 8.
                    // But simpler:
                    
                    // Start of ITERATE:
                    // row_idx = 0, col_idx = 0, acc = 0.
                    
                    // Multiply step:
                    // acc = acc + ((state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16)
                    
                    // If row_idx < max_row:
                    //   row_idx = row_idx + 1
                    // Else:
                    //   next_state_vec[col_idx] = acc
                    //   If col_idx < max_row:
                    //     col_idx = col_idx + 1
                    //     row_idx = 0
                    //     acc = 0
                    //   Else:
                    //     Multiplication complete.
                    //     Check match: if next_state_vec[N-1] == TARGET
                    //       T_out = current_t, result_valid = 1
                    //     Update state_vec = next_state_vec
                    //     current_t = current_t + 1
                    //     Reset row_idx = 0, col_idx = 0 (for next iteration)
                    
                    // We need to handle L=0 case specially if we start at IDLE.
                    // In IDLE, we set state_vec[0]=1.0.
                    // If L=0, we should check T=0 immediately?
                    // Yes, "T in [L, L+9]". If L=0, check T=0.
                    
                    // Let's add a check at the beginning of ITERATE or handle T=0 in IDLE.
                    // It's cleaner to handle it in ITERATE state.
                    
                    // Let's use `acc_idx` as the main loop counter (0..63 for 8x8 matrix).
                    // But we need to reset acc for each column.
                    // Let's use `col_idx` and `row_idx`.
                    
                    // If we just entered ITERATE state:
                    // If we need to check T=0 (and state is initial), we should do so.
                    // The prompt implies "For each day t from L to L+9".
                    // If L=0, we check probability at day 0.
                    // Initial state is at day 0.
                    
                    // Let's add a flag `checked_current_t`.
                    // Or simpler: 
                    // At start of ITERATE (for a specific T):
                    // If T == 0 (initial state), check immediately.
                    // Else, compute.
                    
                    // Let's modify the state machine flow in ITERATE:
                    // 1. Check if we need to check current_t (if we haven't computed it yet, or if it's T=0).
                    //    Actually, `state_vec` holds the probability distribution for `current_t`.
                    //    We check `state_vec[N-1]`.
                    //    If `current_t` is within [L, L+9] and matches, we are done.
                    
                    // So, in ITERATE:
                    // We need to check `state_vec[N-1]` vs TARGET.
                    // If match:
                    //   T_out = current_t, result_valid = 1, go to DONE.
                    // If not match:
                    //   If current_t < L+9:
                    //     Compute next_state (matrix multiply).
                    //     Update state_vec.
                    //     current_t++.
                    //     Repeat.
                    //   Else:
                    //     Done (no match).
                    
                    // To avoid timeout, we use `cycle_count`.
                    
                    // Implementation of Matrix Multiply:
                    // We will use a nested loop structure using `row_idx` and `col_idx`.
                    // `row_idx` iterates 0..max_row.
                    // `col_idx` iterates 0..max_row.
                    // `acc` accumulates.
                    
                    // We need a separate flag to know if we are checking or computing.
                    // Let's use `match_found` flag.
                    
                    // Logic:
                    // If we just entered ITERATE for the first time for this T:
                    // Check `state_vec[N-1]`.
                    // If match: `match_found` = 1, go to DONE.
                    // Else: Start computation.
                    
                    // We will use `row_idx` and `col_idx` to traverse the matrix.
                    // `acc_idx` can be used for the inner multiply loop if needed, but we can just do it sequentially.
                    
                    // Let's define the multiplication step:
                    // We compute `next_state_vec[j]` = sum_{i=0}^{max_row} `state_vec[i]` * `transition_matrix[i][j]`.
                    
                    // We will use `col_idx` as j (0 to max_row).
                    // We will use `row_idx` as i (0 to max_row).
                    // We will use `acc` as the accumulator.
                    
                    // Flow in ITERATE state:
                    // 1. Check if `checked_current` is false.
                    //    If false, check `state_vec[N-1]`.
                    //    If match: `match_found` = 1.
                    //    If not match and `current_t == L+9`: We are done (no match).
                    //    Else: Set `checked_current` = true, `row_idx` = 0, `col_idx` = 0, `acc` = 0.
                    // 
                    // 2. If `checked_current` is true:
                    //    Compute `acc = acc + ((state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16)`.
                    //    `row_idx` ++.
                    //    If `row_idx` > `max_row`:
                    //      `next_state_vec[col_idx]` = `acc`.
                    //      `col_idx` ++.
                    //      `row_idx` = 0.
                    //      `acc` = 0.
                    //      If `col_idx` > `max_row`:
                    //        Update `state_vec` = `next_state_vec`.
                    //        `current_t` ++.
                    //        Reset `checked_current` = false.
                    //        (Loop back to check for next T)
                    
                    // To implement this cleanly:
                    // We'll use temporary registers for the multiplication result.
                    
                    // Helper wires for multiplication (combinational):
                    // We need to compute (A * B) >> 16.
                    // Since we are inside a sequential block, we might create unintended latches if we don't assign to a reg.
                    // Let's use a temporary reg `mult_term`.
                    
                    // Note: We can't easily do `state_vec[row_idx] * transition_matrix[row_idx][col_idx]` in a sequential block
                    // without generating a latch warning if indices are variable, unless we use a full case statement.
                    // To avoid this, we can use a helper function or unroll the loops.
                    // Given the complexity, let's use a helper block or explicit indexing.
                    
                    // Since we can't use functions with unpacked arrays easily, let's use a case statement or logic.
                    // Actually, synthesizable Verilog allows array indexing in always blocks if the index is a register.
                    // It infers a multiplexer.
                    
                    // Let's declare:
                    // wire [63:0] product = state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                    // wire [31:0] term = product[47:16];
                    // This should be fine.
                    
                    // We need to handle the check phase.
                    // We will introduce a state variable `phase` (CHECK or COMPUTE).
                    // Or just use the logic flow.
                    
                    // Let's use `acc_idx` as a flag: 0 = check, 1 = compute.
                    // But we need multiple compute cycles.
                    
                    // Let's use `match_found` to indicate we found a match.
                    // Let's use `current_t` to track time.
                    
                    // If we just entered ITERATE:
                    // If we haven't checked this T yet:
                    //   Check `state_vec[N-1]`.
                    //   If match: `match_found` = 1.
                    //   Else if `current_t` >= (L + 9): We are done (no match).
                    //   Else: Start computation for next T.
                    // 
                    // If we are computing:
                    //   Run the matrix multiply loop.
                    //   When loop finishes, update `state_vec`, increment `current_t`, reset loop.
                    //   If `current_t` > (L + 9) after increment, we are done (no match).
                    
                    // Let's implement the loop.
                    // We will use `row_idx` and `col_idx`.
                    // `row_idx` goes 0 -> max_row.
                    // `col_idx` goes 0 -> max_row.
                    
                    // We need to handle the reset of `acc` correctly.
                    // `acc` should reset when `row_idx` is 0 for a specific `col_idx`.
                    
                    // Let's define a localparam for states inside ITERATE if needed, but let's try to keep it flat.
                    
                    // We'll use `acc_idx` to track which part of the iteration we are in.
                    // 0: Check
                    // 1: Compute
                    
                    // Let's refine the state transitions for ITERATE.
                    // We need to stay in ITERATE for multiple cycles.
                    
                    // In ITERATE:
                    // If (acc_idx == 0) begin // Check Phase
                    //   if (state_vec[N-1] == TARGET) match_found <= 1;
                    //   else if (current_t >= L + 9) done_flag <= 1; // No match
                    //   else acc_idx <= 1; // Switch to Compute
                    // end
                    // else begin // Compute Phase
                    //   // Matrix multiply logic
                    //   // When finished, update state_vec, current_t++, acc_idx <= 0
                    // end
                    
                    // We need to be careful with the loop counters for matrix multiply.
                    // We will use `col_idx` (0..max_row) and `row_idx` (0..max_row).
                    
                    // Let's use `acc` to store the accumulator for the current column.
                    // We need to clear `acc` when starting a new column.
                    
                    // Optimization: Since N <= 8, we can unroll the outer loop (col_idx) partially.
                    // But let's stick to the loop.
                    
                    // Let's use a dedicated register `compute_state` to track matrix multiply progress.
                    // 0: Idle (waiting for check to finish)
                    // 1: Accumulating
                    // 2: Storing result
                    
                    // To save registers and complexity, let's just use `row_idx` and `col_idx`.
                    
                    // Check logic:
                    // We need to compare `state_vec[N-1]` with TARGET.
                    // `state_vec` is 32-bit. TARGET is 16-bit (but represents Q16.16 0.95).
                    // `state_vec` is Q16.16. 0.95 is 62259/65536.
                    // So we compare `state_vec[N-1]` with {16'd0, TARGET} ?
                    // No, 0.95 is a fraction. In Q16.16, 0.95 is 62259.
                    // Wait. 1.0 is 65536. 0.95 is 62259.
                    // `state_vec` stores probability * 65536.
                    // So we compare `state_vec[N-1]` with 32'd62259.
                    
                    // Let's define TARGET_Q16 = 32'd62259.
                    
                    // Implementation details:
                    // 1. Check:
                    //    if (state_vec[N-1] == 32'd62259) match_found <= 1;
                    //    else if (current_t >= L + 9) goto DONE (no match).
                    //    else goto Compute.
                    // 
                    // 2. Compute:
                    //    Initialize `col_idx` = 0, `row_idx` = 0.
                    //    Loop:
                    //      `acc` = `acc` + ((state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16)
                    //      `row_idx` ++
                    //      if `row_idx` > `max_row`:
                    //        `next_state_vec[col_idx]` = `acc`
                    //        `col_idx` ++
                    //        `row_idx` = 0
                    //        `acc` = 0
                    //        if `col_idx` > `max_row`:
                    //          Done with compute.
                    //          `state_vec` = `next_state_vec`
                    //          `current_t` ++
                    //          Go to Check.
                    
                    // We will use `row_idx` and `col_idx` registers.
                    
                    // To avoid complex state machine within ITERATE, let's just use the counters directly.
                    
                    // If `match_found` is 0 and `current_t` is within range:
                    //   If `state_vec` is already set for `current_t` (initially true for L):
                    //     Check match.
                    //     If no match:
                    //       Compute next state.
                    //       Update `state_vec`.
                    //       Increment `current_t`.
                    //       
                    // We need to be careful about when we check.
                    // At the start of ITERATE, `state_vec` represents probability at `current_t`.
                    // We check it.
                    // If match, done.
                    // If not, we compute for `current_t + 1`.
                    
                    // Let's use `acc_idx` to indicate if we have checked the current state.
                    // acc_idx = 0: Need to check
                    // acc_idx = 1: Computing next state
                    
                    // Cycle 1 (ITERATE enter):
                    // Check `state_vec[N-1]`.
                    // If match: `match_found` = 1.
                    // Else: `acc_idx` = 1. Initialize `row_idx`=0, `col_idx`=0.
                    // 
                    // Cycle 2+:
                    // If `acc_idx` == 1:
                    //   `acc` += product
                    //   `row_idx` ++
                    //   If `row_idx` > `max_row`:
                    //     Store to `next_state_vec[col_idx]`.
                    //     `col_idx` ++
                    //     `row_idx` = 0.
                    //     If `col_idx` > `max_row`:
                    //       Copy `next_state_vec` to `state_vec`.
                    //       `current_t` ++.
                    //       `acc_idx` = 0. (Check next)
                    
                    // We need to handle the copy operation.
                    // We can do it in one cycle or multiple. Given 8 elements, one cycle is fine.
                    
                    // We need to ensure we don't check `current_t` if it goes out of bounds.
                    // Bounds check: `current_t` <= L + 9.
                    
                    // Let's implement this.
                    
                    // Pre-calculate target limit.
                    // localparam TARGET_Q16 = 32'd62259;
                    
                    // Helper wire for multiplication.
                    // We must declare this outside the always block or calculate inside.
                    // Let's calculate inside using a temporary register to avoid combinational logic issues in synthesis.
                    // Actually, standard multiplier in always block is okay if fully assigned.
                    
                    // We will use `mult_temp` to hold the 64-bit product.
                    // `mult_term` will hold the 32-bit shifted result.
                    
                    // Note: We need to handle the case where N=1. `max_row` = 0.
                    
                    // Let's code the logic.
                    
                    // If match_found is 1, we don't do anything.
                    // If `current_t` > L + 9, we are done (no match).
                    
                    // We will use `acc_idx` as the state for ITERATE.
                    // acc_idx 0: Check
                    // acc_idx 1: Compute
                    // acc_idx 2: Update
                    // acc_idx 3: Increment T
                    
                    // To save cycles, we can merge Update and Increment T.
                    
                    // Let's use `row_idx` for the product calculation step.
                    // When row_idx wraps, we store.
                    
                    // Let's refine the state transitions inside ITERATE.
                    // We need to stay in ITERATE state for multiple cycles.
                    
                    // If `match_found` is true, go to DONE.
                    if (match_found) begin
                        // Should be handled by next_state logic, but safe to clear here if stuck
                    end else if (current_t > (L + 9'd9)) begin
                        // Timeout (no match)
                    end else begin
                        // Check phase
                        if (acc_idx == 8'd0) begin
                            // Check if state_vec[N-1] == TARGET
                            // We need to index N-1.
                            // N is 4-bit, N-1 is max_row.
                            if (state_vec[max_row] == 32'd62259) begin
                                match_found <= 1'b1;
                                T_out <= current_t;
                                result_valid <= 1'b1;
                            end else begin
                                // If not match, and current_t is L+9, we are done (no result).
                                // Actually, we check T in [L, L+9].
                                // If current_t == L+9 and no match, we are done.
                                // If current_t < L+9, we compute next.
                                
                                if (current_t == (L + 9'd9)) begin
                                    // No match found, go to DONE
                                    // next_state logic will handle this because match_found is 0 and current_t is at limit
                                    // We need to make sure we exit ITERATE.
                                    // Let's set a flag or just rely on next_state logic.
                                    // next_state logic: if match_found OR current_t >= L+9 -> DONE.
                                    // We are in ITERATE. We checked current_t. No match.
                                    // We should move to next state.
                                    // Since we can't update current_t anymore, we just go to DONE.
                                    // But we need to stay in ITERATE for one cycle to process the "No Match" event.
                                    // We can set a flag `done_compute`.
                                end else begin
                                    // Start computation for next T
                                    acc_idx <= 8'd1;
                                    row_idx <= 8'd0;
                                    col_idx <= 8'd0;
                                    acc <= 32'd0;
                                end
                            end
                        end else if (acc_idx == 8'd1) begin
                            // Compute Phase
                            // Calculate product and accumulate
                            // term = (state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16
                            
                            // Multiply
                            // We need to be careful about array indexing in combinational logic.
                            // Let's use a helper always block or just do it here.
                            // Since `state_vec` and `transition_matrix` are regs, we can index them.
                            
                            // product = state_vec[row_idx] * transition_matrix[row_idx][col_idx]
                            // We need 64-bit product.
                            // We'll use a temporary 64-bit register `mult_temp_reg`.
                            
                            // Actually, Verilog multiplication of two 32-bit regs produces a 64-bit result.
                            // We can assign it to a 64-bit register.
                            
                            // Note: We must ensure we don't access indices out of bounds.
                            // row_idx goes 0..max_row. 
                            // transition_matrix indices are valid 0..7.
                            // state_vec indices are valid 0..7.
                            
                            // We will calculate `term` using a blocking assignment in a combinational sense or sequential.
                            // Let's use a separate combinational block for the multiplier to avoid timing loops, 
                            // but since we are in a sequential block, we calculate in the current cycle.
                            
                            // Mult logic:
                            // mult_temp_reg = state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                            // term = mult_temp_reg[47:16];
                            
                            // We will use `mult_temp` (defined as 32-bit in port list? No, let's use local param or reg)
                            // Actually, I declared `mult_temp` as 32-bit reg. I need 64-bit for multiplication.
                            // Let's use `acc` which is 32-bit? No `acc` is accumulator.
                            // Let's declare `product` as 64-bit internal variable.
                            
                            // Since we can't easily declare 64-bit registers without changing interface, 
                            // let's use logic [63:0] product.
                            
                            // Wait, `state_vec` is 32-bit. `transition_matrix` is 32-bit.
                            // Product is 64-bit.
                            
                            // We will use a temporary variable.
                            // To avoid defining new regs (which adds state), we can perform the operation directly.
                            // But we need to store intermediate accumulator `acc`.
                            
                            // Let's assume `acc` holds the sum (Q16.16).
                            
                            // Optimization: 
                            // We can use `mult_temp` to hold the upper 32 bits of the product (Q16.16 result).
                            // But `mult_temp` is 32-bit. The product of two 32-bit numbers is 64-bit.
                            // The upper 32 bits (bits 63:32) are the integer part (mostly 0).
                            // The next 32 bits (bits 31:0) are the fractional/integer part.
                            // We want bits 47:16 (Q32.32 -> Q16.16).
                            
                            // We will use a temporary 64-bit wire `product_wire` for calculation.
                            // But inside an always block, we need to use registers.
                            // Let's use a 64-bit temporary register `temp_prod`.
                            // Wait, I don't want to add too many registers.
                            // Let's just calculate it.
                            
                            // Logic for `acc` update:
                            // acc <= acc + ((state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16);
                            
                            // To avoid latch warnings, we must assign to `acc` or keep it unchanged.
                            // We update `acc` every cycle in Compute phase.
                            
                            // We need to handle `state_vec` indexing safely.
                            // If `row_idx > max_row`, we treat contribution as 0.
                            // Since we loop 0 to max_row, this is safe.
                            
                            // Let's implement the multiply and shift.
                            // We will use a blocking assignment for the intermediate product calculation to keep it within one time unit.
                            // But synthesizers might not like complex expressions in always blocks.
                            
                            // Let's use a helper always block for the multiplier output.
                            // Actually, we can just do:
                            // acc <= acc + (state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16;
                            // This might be interpreted as (acc + product) >> 16. 
                            // We need (product >> 16).
                            
                            // Correct logic:
                            // acc <= acc + {(state_vec[row_idx] * transition_matrix[row_idx][col_idx]) >> 16};
                            // But bit slicing on the result of multiplication is fine.
                            
                            // However, `state_vec` is 32-bit. Multiplication 32x32 -> 64-bit.
                            // We need to cast or slice.
                            
                            // Let's use a temporary 64-bit register `product_reg`.
                            // `product_reg = state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                            // `acc <= acc + product_reg[47:16];
                            
                            // We need to declare `product_reg` as `reg [63:0]`.
                            // Let's add it to the register list.
                            // `reg [63:0] product_reg;`
                            
                            // Update `product_reg`.
                            // product_reg <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                            // acc <= acc + product_reg[47:16];
                            
                            // We also need to handle `state_vec` update.
                            // `state_vec` is an unpacked array. We can't assign `state_vec <= next_state_vec` in one go in Icarus Verilog.
                            // We must assign element by element.
                            // `state_vec[0] <= next_state_vec[0];` etc.
                            
                            // We also need to handle `next_state_vec` initialization/copy.
                            // When computing, we write to `next_state_vec[col_idx]`.
                            // When finished, we copy `next_state_vec` to `state_vec`.
                            
                            // Let's refine the flow in Compute phase (acc_idx == 1):
                            // 1. Calculate product.
                            // 2. Add to acc.
                            // 3. Increment row_idx.
                            // 4. If row_idx > max_row:
                            //    Store acc to next_state_vec[col_idx].
                            //    If col_idx > max_row: 
                            //      Copy next_state_vec to state_vec.
                            //      current_t++.
                            //      acc_idx = 0.
                            //    Else:
                            //      row_idx = 0.
                            //      acc = 0.
                            //      (Loop continues)
                            
                            // We need to be careful with the copy operation.
                            // Copy: state_vec[i] <= next_state_vec[i] for i=0..max_row.
                            // For i > max_row (up to 7), we can set to 0 or don't care.
                            // Let's set them to 0 for cleanliness.
                            
                            // Let's code this.
                            
                            // We will use `temp_prod` register (64-bit).
                            // `temp_prod <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                            // `acc <= acc + temp_prod[47:16];
                            
                            // We need to ensure `state_vec` and `transition_matrix` are indexed correctly.
                            // N is 1-based input. Indices are 0-based internal.
                            // If N=1, max_row=0. We iterate row_idx=0.
                            
                            // We will update `next_state_vec[col_idx]` when row_idx wraps.
                            // But `next_state_vec` is also an unpacked array.
                            
                            // We need to handle the update of `next_state_vec`.
                            // `next_state_vec[col_idx] <= acc;`
                            // This is valid if we index with a register.
                            
                            // We need to initialize `next_state_vec` elements?
                            // No, we overwrite them.
                            
                            // Let's add `product_reg` to the register list.
                            // `reg [63:0] product_reg;`
                            
                            // Logic:
                            // product_reg <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                            // acc <= acc + product_reg[47:16];
                            
                            // Then check row_idx.
                            
                            // We need to handle `row_idx` and `col_idx` increment logic.
                            
                            // If `row_idx` == `max_row`:
                            //   `next_state_vec[col_idx]` = `acc`.
                            //   `row_idx` = 0.
                            //   `col_idx` = `col_idx` + 1.
                            //   `acc` = 0.
                            //   If `col_idx` > `max_row`:
                            //     // Copy phase (can be done in same cycle or next)
                            //     // Let's do it in a separate phase or increment `acc_idx`.
                            //     // Let's add a phase `acc_idx` = 2 for Update.
                            // end else begin
                            //   `row_idx` = `row_idx` + 1.
                            // end
                            
                            // We need `acc_idx` = 2 for Update/Copy.
                            
                            // Let's define `acc_idx` states:
                            // 0: Check
                            // 1: Compute
                            // 2: Copy & Next T
                            
                            // In `acc_idx` = 1 (Compute):
                            // `product_reg <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];`
                            // `acc <= acc + product_reg[47:16];`
                            // `row_idx <= row_idx + 1;`
                            // if (`row_idx` == `max_row`):
                            //   `next_state_vec[col_idx] <= acc;` (Note: acc includes this cycle's product? Yes)
                            //   `col_idx <= col_idx + 1;`
                            //   `row_idx <= 0;`
                            //   `acc <= 0;`
                            //   if (`col_idx` == `max_row`):
                            //     `acc_idx <= 2;` // Switch to Copy
                            
                            // In `acc_idx` = 2 (Copy):
                            // `state_vec[0] <= next_state_vec[0];`
                            // ...
                            // `state_vec[max_row] <= next_state_vec[max_row];`
                            // `state_vec[max_row+1..7] <= 0;` (Optional, but clean)
                            // `current_t <= current_t + 1;`
                            // `acc_idx <= 0;` // Go back to Check
                            
                            // This looks correct.
                            
                            // We need to be careful with the `max_row` logic.
                            // `max_row` is N-1.
                            // If N=1, `max_row`=0.
                            // In Compute:
                            // row_idx = 0. product calculated. acc updated.
                            // row_idx becomes 1. But we check `row_idx == max_row` (0). False.
                            // Wait, if `max_row`=0, we iterate `row_idx` from 0 to 0.
                            // So we check `row_idx == max_row` AFTER increment?
                            // No, we check before increment or at the end of iteration.
                            
                            // Let's use `row_idx` to track current row being added.
                            // We add `state_vec[row_idx]`.
                            // Then increment `row_idx`.
                            // If `row_idx` > `max_row`, we are done with this column.
                            
                            // So:
                            // `product_reg <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];`
                            // `acc <= acc + product_reg[47:16];`
                            // `row_idx <= row_idx + 1;`
                            // if (`row_idx` == `max_row`):
                            //   // After this cycle, next cycle row_idx will be max_row+1.
                            //   // But we need to store `acc`.
                            //   // Let's store `acc` in the cycle where `row_idx == max_row`.
                            //   // Wait, if we increment `row_idx` first, we lose the current index.
                            
                            // Let's structure it:
                            // 1. Use `row_idx` as index.
                            // 2. Compute product with `row_idx`.
                            // 3. Update `acc`.
                            // 4. Check if `row_idx == max_row`.
                            //    If yes: 
                            //      `next_state_vec[col_idx] <= acc;`
                            //      `col_idx <= col_idx + 1;`
                            //      `row_idx <= 0;`
                            //      `acc <= 0;`
                            //      if `col_idx == max_row`: `acc_idx <= 2;`
                            //    Else:
                            //      `row_idx <= row_idx + 1;`
                            
                            // This works.
                            
                            // We need to handle `product_reg`.
                            // `product_reg` is 64-bit. Let's declare it.
                            
                            // One issue: `transition_matrix` is indexed by `row_idx` and `col_idx`.
                            // `col_idx` is the target node.
                            // `row_idx` is the source node.
                            // Correct.
                            
                            // Let's code it.
                        end else if (acc_idx == 8'd2) begin
                            // Copy phase
                            // state_vec[i] <= next_state_vec[i]
                            // Since we can't loop over arrays easily in sequential logic without generating latches or complex logic,
                            // we explicitly assign.
                            // Also update `current_t`.
                            
                            state_vec[0] <= next_state_vec[0];
                            state_vec[1] <= next_state_vec[1];
                            state_vec[2] <= next_state_vec[2];
                            state_vec[3] <= next_state_vec[3];
                            state_vec[4] <= next_state_vec[4];
                            state_vec[5] <= next_state_vec[5];
                            state_vec[6] <= next_state_vec[6];
                            state_vec[7] <= next_state_vec[7];
                            
                            current_t <= current_t + 16'd1;
                            acc_idx <= 8'd0; // Back to Check
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // result_valid and T_out are already set in ITERATE or IDLE
                    if (!start) begin
                        // Wait for start to go low
                    end
                end
            endcase
        end
    end
    
    // Combinational logic for multiplication helper
    // We need to compute product safely.
    // We will use an always @(*) block for the product calculation to avoid timing issues.
    // But we need to index `state_vec` and `transition_matrix`.
    // If we are in ITERATE state, we need the product for the current `row_idx` and `col_idx`.
    
    // Since we update `product_reg` in the sequential block, we don't strictly need a combinational block.
    // We can just do: `product_reg <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];`
    // This is valid Verilog.
    
    // However, to ensure we don't generate latches for `product_reg`, we must assign it in all branches of the case statement.
    // In IDLE and NORMALIZE, we might not want to compute the product.
    // So we should default `product_reg` or only update it in ITERATE.
    
    // Let's declare `product_reg` inside the always block or as a separate reg.
    // I'll add it to the register list: `reg [63:0] product_reg;`
    
    // We need to handle the array updates in the COPY phase.
    // `next_state_vec` is updated in the Compute phase.
    // `next_state_vec` is an unpacked array. We update it element by element.
    
    // We need to be careful about initializing `next_state_vec`.
    // It is updated element-wise. Elements not updated retain old values.
    // When we copy `next_state_vec` to `state_vec`, we copy all 8 elements.
    // This is fine.
    
    // We need to handle the case where `max_row` < 7.
    // When we compute `next_state_vec[j]` for `j > max_row`, we should probably set it to 0.
    // The loop runs `col_idx` from 0 to `max_row`.
    // So `next_state_vec` for indices > `max_row` are not updated in this iteration.
    // They contain values from the previous iteration (or initial 0).
    // This is incorrect. Probabilities for non-existent nodes should be 0.
    // We should clear `next_state_vec` before the multiplication loop or clear unused indices after.
    
    // Let's clear `next_state_vec` at the start of the compute phase.
    // But we enter compute phase multiple times (for each T).
    // We can clear it in `acc_idx = 1` (start of compute) or `acc_idx = 0` (check).
    
    // Let's clear `next_state_vec` in `acc_idx = 0` if we are about to start compute.
    // Or just clear it before setting `acc_idx = 1`.
    
    // Let's add logic to clear `next_state_vec`.
    // In `acc_idx = 0` (Check phase), if we decide to compute, we should clear `next_state_vec`.
    
    // Logic in Check phase:
    // if (match_found) ...
    // else if (current_t > L+9) ...
    // else begin
    //   if (state_vec[max_row] == TARGET) ...
    //   else if (current_t == L+9) ...
    //   else begin
    //     // Start compute
    //     // Clear next_state_vec
    //     for (int i=0; i<8; i++) next_state_vec[i] <= 0;
    //     acc_idx <= 1;
    //     ...
    //   end
    // end
    
    // We need a loop to clear. Since 8 is small, we can unroll it or use a for-loop.
    // For-loops in always blocks are synthesizable if unrolled or if the synthesis tool supports it.
    // Icarus Verilog supports for-loops in sequential logic (they unroll).
    
    // So, in the Check phase (acc_idx == 0), when starting compute:
    // if (state_vec[max_row] != TARGET && current_t < L+9) begin
    //   for (int k=0; k<8; k++) next_state_vec[k] <= 0;
    //   acc_idx <= 1;
    //   ...
    // end
    
    // This solves the `next_state_vec` accumulation issue.
    
    // Let's refine the product calculation.
    // `product_reg <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];`
    // `acc <= acc + product_reg[47:16];`
    // Note: `product_reg` is 64-bit. `state_vec` is 32-bit.
    // If `state_vec` contains raw probabilities (Q16.16), the product is Q32.32.
    // We want the result to be Q16.16.
    // Taking `product_reg[47:16]` gives us Q16.16 (assuming we shift right by 16).
    // Yes.
    
    // One detail: `transition_matrix` stores Q16.16 probabilities.
    // `state_vec` stores Q16.16 probabilities.
    // `acc` stores Q16.16 accumulator.
    // `next_state_vec` stores Q16.16 probabilities.
    
    // All types match.
    
    // Let's write the final code.
    
    // We need to handle the DONE state transition.
    // In ITERATE, if `match_found` becomes true, we should transition to DONE.
    // In ITERATE, if `current_t` exceeds L+9 (and we checked T=L+9), we transition to DONE.
    
    // We need to make sure `result_valid` is set correctly.
    // `result_valid` is 1 if match_found, 0 otherwise.
    // We set `result_valid` and `T_out` when `match_found` becomes true.
    // If we reach DONE without match, `result_valid` should be 0.
    // `T_out` should be 0.
    // In IDLE, we reset `result_valid` to 0 and `T_out` to 0.
    
    // We need to make sure we don't set `result_valid` to 1 prematurely.
    // We set it in ITERATE when match is found.
    
    // Let's handle the case where we don't find a match.
    // If `current_t` > L+9 and we haven't found a match, we go to DONE.
    // In this case, `match_found` is 0, `result_valid` is 0 (from IDLE reset or not set).
    // `T_out` is 0 (from IDLE reset).
    
    // We need to ensure `current_t` logic is correct.
    // `current_t` starts at L.
    // We check `current_t`.
    // If no match, we compute for `current_t + 1`.
    // We increment `current_t` after copying.
    
    // So if `current_t == L+9` and we check (no match), we stop.
    // If `current_t < L+9`, we compute next.
    
    // Let's implement the specific logic in ITERATE state.
    
    // We need `product_reg` for multiplication.
    // Add `reg [63:0] product_reg;`
    
    // Also need to handle the `next_state_vec` update in Compute phase.
    // `next_state_vec[col_idx] <= acc;`
    // `acc` contains the sum.
    
    // We need to ensure `acc` is updated with the *current* product before storing.
    // In the cycle where `row_idx == max_row`:
    // `acc = acc + product`.
    // Then we store `acc`.
    
    // One detail: `next_state_vec` is an unpacked array.
    // We update it element-wise: `next_state_vec[col_idx] <= acc;`
    // This is fine.
    
    // We need to make sure we don't update `next_state_vec` for `col_idx > max_row`.
    // The loop only runs for `col_idx` 0 to `max_row`.
    
    // Let's code the final version.
    
    // We need to be careful with `max_row` logic when N=1.
    // `max_row` = N-1.
    // If N=1, `max_row`=0.
    // We need to check `state_vec[0]`.
    // If no match, compute next.
    // Compute loop: `col_idx` 0 to 0. `row_idx` 0 to 0.
    // This works.
    
    // We need to declare `product_reg`.
    
    // Let's write the code.
    
    // Note: We need to use `indexed_name` syntax for arrays in assignments.
    
    // We will use `next_state_vec[col_idx]` inside the always block.
    
    // One more thing: `next_state_vec` needs to be cleared before accumulation.
    // We can clear it in the Check phase when we decide to compute.
    
    // We need to handle the `cycle_count` timeout.
    // If `cycle_count` >= `MAX_CYCLES`, we should go to DONE.
    // The `next_state` logic handles this: `cycle_count >= MAX_CYCLES` -> `next_state = DONE_STATE`.
    // In DONE_STATE, `result_valid` remains 0.
    
    // Let's refine the `next_state` logic for ITERATE.
    // `if (match_found || current_t >= (L + 16'd9) || cycle_count >= MAX_CYCLES)` -> `DONE_STATE`.
    // Note: `current_t >= (L + 9)` means we have checked T=L+9.
    // We check `current_t`. If it matches, `match_found` is set.
    // If it doesn't match and `current_t == L+9`, we are done.
    // So the condition `current_t >= (L + 9)` is correct for termination if no match found.
    // Wait, if `current_t == L+9`, we check it. If no match, we should stop.
    // So `current_t > (L + 9)` or (`current_t == (L + 9)` and check done).
    // But `match_found` prevents going to DONE if we just found it.
    
    // Let's use `current_t > (L + 9)` as the termination condition (no match).
    // We check `current_t` when it is <= L+9.
    // If `current_t == L+9` and no match, we compute next? No, we stop.
    // So we check `current_t`. If no match and `current_t == L+9`, we go to DONE.
    // Or simpler: 
    // In Check phase: if `current_t > L+9` -> DONE.
    // We start with `current_t = L`.
    // We check `current_t`. 
    // If no match:
    //   If `current_t == L+9`: DONE.
    //   Else: Compute.
    
    // So `next_state` logic should check `current_t > (L + 9)` or `match_found`.
    // Also `cycle_count >= MAX_CYCLES`.
    
    // Let's adjust `next_state` logic for ITERATE.
    // `if (match_found || current_t > (L + 9'd9) || cycle_count >= MAX_CYCLES)` -> `DONE_STATE`.
    // But we need to finish the computation for the current cycle.
    // `next_state` logic runs in parallel with the current state's actions.
    // If we are in ITERATE, we are processing a specific T or computing the next one.
    // If we are checking T and it matches, we set `match_found`.
    // `next_state` sees `match_found` and goes to DONE.
    // If we are checking T and it doesn't match, `match_found` is 0.
    // If `current_t == L+9`, we should go to DONE.
    // `next_state` logic: `if (current_t >= (L + 9))` -> `DONE_STATE`.
    // If we are computing (acc_idx != 0), `current_t` represents the time of the *current* state vector.
    // If we are computing, we are calculating for `current_t + 1`.
    // So we should not stop computing if `current_t == L+9` and we are in the middle of computing for `L+10`?
    // No, we only compute if `current_t < L+9`.
    // So `next_state` logic is safe.
    
    // Let's write the code with `product_reg`.
    
    // We need to handle `state_vec` and `next_state_vec` updates carefully.
    // `state_vec[i] <= next_state_vec[i]` in `acc_idx = 2`.
    
    // We also need to handle `transition_matrix` update in NORMALIZE state.
    // `transition_matrix[row_idx][col_idx] <= acc;` (where `acc` holds the division result).
    // In NORMALIZE, we used `mult_temp` and `acc` for division.
    // Let's clarify the division logic in NORMALIZE.
    // We used `mult_temp` as dividend (edges << 16) and `acc` as quotient.
    // We need to store the result in `transition_matrix[row_idx][col_idx]`.
    // `col_idx` ranges 8..15 in the calculation phase.
    // `col_idx - 8` is the element index.
    // `transition_matrix[row_idx][col_idx - 8] <= acc;`
    
    // We need to handle the division loop.
    // `acc_idx` was used for division steps (0-16).
    // We need to make sure `acc_idx` is distinct from `acc_idx` in ITERATE.
    // In ITERATE, `acc_idx` is 0, 1, 2.
    // In NORMALIZE, `acc_idx` is used as a counter (16 steps).
    // This is fine as long as we reset it when leaving NORMALIZE.
    
    // Let's verify the division logic.
    // `mult_temp` (32-bit) holds (edges << 16).
    // `row_sum` (32-bit) holds sum.
    // We do 16 steps of restoring division.
    // Result is 16-bit integer (shifted left 16? No, we want Q16.16).
    // Edges is 8-bit. Sum is <= 2040.
    // (Edges * 65536) / Sum.
    // Result is Q16.16.
    // `acc` accumulates the quotient.
    // We shift `mult_temp` left (actually we shift `mult_temp` and `acc` left together).
    // Standard restoring division:
    // Shift `mult_temp` and `acc` left.
    // If `mult_temp` (high bits) >= divisor, subtract and set bit.
    
    // In our case, `mult_temp` starts at {edges, 16'd0}.
    // We want 16 bits of precision.
    // So we run 16 iterations.
    // `acc` starts at 0.
    // In each step:
    // `mult_temp` <= `mult_temp` << 1.
    // `acc` <= `acc` << 1.
    // If `mult_temp[31:0] >= row_sum`: 
    //   `mult_temp` <= `mult_temp - row_sum`.
    //   `acc[0]` <= 1.
    
    // Note: `row_sum` is 32-bit but small.
    // `mult_temp` is 32-bit (edges << 16).
    // We need to check `mult_temp >= row_sum`.
    // We can use `mult_temp[31:0]`.
    
    // Wait, `mult_temp` is 32-bit. `edges << 16` is 24-bit.
    // If we shift `mult_temp` 16 times, we need more bits.
    // We need a wider register for `mult_temp` to hold the shifting bits.
    // 32-bit + 16 shifts = 48-bit.
    // Or we can just use 32-bit `mult_temp` and accept some precision loss or change logic.
    // Actually, we are calculating (Edges * 65536) / Sum.
    // This is equivalent to (Edges / Sum) * 65536.
    // Or Edges * (65536 / Sum).
    // Since Sum is small, 65536/Sum is large.
    // We can precompute 65536/Sum if Sum is constant. But it varies.
    
    // Let's use a 48-bit `mult_temp` for division.
    // `mult_temp = {edges, 16'd0};` (24 bits).
    // We shift left 16 times.
    // Result fits in 40 bits.
    // Let's use `reg [47:0] mult_temp_div;` and `reg [15:0] acc_div;` for the division.
    // Wait, I declared `mult_temp` as 32-bit and `acc` as 32-bit in the port list context.
    // I can reuse them if I'm careful, but let's add specific divider registers to avoid confusion.
    // `reg [47:0] div_mult_temp;`
    // `reg [15:0] div_acc;`
    
    // Let's stick to the prompt's "Q16.16 arithmetic".
    // Edges is 8-bit. Sum is 16-bit.
    // Result is 32-bit (Q16.16).
    // We can compute this using a sequential divider.
    
    // To save registers, let's use `mult_temp` and `acc` for the division, 
    // but extend `mult_temp` to 48 bits if needed or just use 32 bits carefully.
    // Actually, (Edges * 65536) / Sum.
    // Max Edges = 255. Max Sum = 2040.
    // 255 * 65536 / 1 ≈ 16M. Fits in 24 bits.
    // 255 * 65536 / 2040 ≈ 8200. Fits in 16 bits.
    // So the result fits in 24 bits.
    // We can use 32-bit arithmetic.
    
    // Let's use `mult_temp` (32-bit) and `acc` (32-bit) for the division.
    // `mult_temp` = Edges << 16.
    // `acc` = 0.
    // Loop 16 times:
    // `mult_temp` <= {`mult_temp`[30:0], 1'b0};
    // `acc` <= {`acc`[30:0], 1'b0};
    // If `mult_temp` >= `row_sum`:
    //   `mult_temp` <= `mult_temp - row_sum`.
    //   `acc` <= `acc` | 1; (or set LSB)
    
    // This uses 32-bit `mult_temp`. 
    // Start: {edges, 16'd0}. Max 24 bits. 
    // Shift left 16 times. Max 40 bits.
    // If `mult_temp` is 32-bit, we lose precision after 32-24=8 shifts.
    // We need 48-bit `mult_temp`.
    
    // Okay, let's add `reg [47:0] div_temp;` and `reg [15:0] div_quot;`.
    // We will use these for normalization.
    
    // In NORMALIZE state:
    // We calculate sum in 0-7.
    // We calculate prob in 8-15.
    // In prob calculation (col_idx 8-15):
    // Element index = col_idx - 8.
    // If col_idx == 8: 
    //   `div_temp` <= {trans_in[row_idx][0], 16'd0}; // 24 bits
    //   `div_quot` <= 0;
    //   `div_step` <= 16.
    //   
    // If `div_step` > 0:
    //   `div_temp` <= `div_temp` << 1;
    //   `div_quot` <= `div_quot` << 1;
    //   if (`div_temp[47:16] >= row_sum[15:0]): // Check upper bits against sum
    //     `div_temp` <= `div_temp - {row_sum, 16'd0}`; // Subtract scaled sum
    //     `div_quot` <= `div_quot` | 1;
    //   `div_step` <= `div_step` - 1;
    //   
    // If `div_step` == 0:
    //   Store `div_quot` (which is 16-bit) into `transition_matrix[row_idx][col_idx-8]` as 32-bit.
    //   Wait, `div_quot` is 16-bit (0-65535). We want Q16.16.
    //   The result is `div_quot` << 16? No.
    //   (Edges * 65536) / Sum.
    //   We shifted `div_temp` left. 
    //   `div_temp` started at {Edges, 16'd0}.
    //   We shifted left 16 times. 
    //   We did 16 steps.
    //   Result is in `div_temp`? No, in `div_quot`.
    //   Actually, standard division:
    //   Dividend = Numerator << 16.
    //   Quotient = 0.
    //   Iterate 16 times:
    //     Shift Dividend, Shift Quotient.
    //     If Dividend >= Divisor: Sub, set bit.
    //   Result Quotient is the integer part. (Here, it's the fractional part of Edges/Sum scaled by 65536).
    //   Wait. We want (Edges * 65536) / Sum.
    //   Dividend = Edges * 65536.
    //   Divisor = Sum.
    //   We perform division.
    //   Quotient = Dividend / Divisor.
    //   This is exactly what we want.
    //   `div_quot` will hold the result.
    //   But `div_quot` is 16-bit in my sketch. Edges*65536/Sum can be > 65535 (if Sum is small).
    //   Max value: 255*65536/1 = 16,711,680. Fits in 24 bits.
    //   So `div_quot` needs to be 32-bit or 24-bit.
    
    //   Let's make `div_quot` 32-bit.
    //   `reg [31:0] div_quot;`
    
    //   Division Logic:
    //   `div_temp` (48-bit) = {Edges, 16'd0}. 
    //   `div_quot` (32-bit) = 0.
    //   Loop 16 times:
    //     `div_temp` <= `div_temp` << 1;
    //     `div_quot` <= `div_quot` << 1;
    //     if (`div_temp[47:16] >= {16'd0, row_sum[15:0]}`): 
    //       `div_temp` <= `div_temp - {row_sum, 16'd0}`; // Sum is 16-bit, shift left 16 to match alignment
    //       `div_quot` <= `div_quot` + 1; // Or set LSB: `div_quot[0] <= 1;`
    //       Wait, `div_quot` is shifted first. So set LSB.
    //       `div_quot` <= `div_quot` | 1;
    
    //   Result: `div_quot`.
    //   Store `div_quot` into `transition_matrix`.
    
    //   We need 16 cycles for division.
    //   We have 8 cycles (col_idx 8-15).
    //   This doesn't fit.
    
    //   To fit 16 divisions into 8 cycles, we need 2 divisions per cycle or a pipelined divider.
    //   Or we can skip the division and store raw counts, then normalize during multiplication.
    //   Let's normalize during multiplication.
    //   Store `transition_matrix` as raw counts (8-bit).
    //   During multiplication:
    //     `product = state_vec[row_idx] * transition_matrix[row_idx][col_idx];`
    //     `scaled_product = product >> 16;` (This is probability * count)
    //     `normalized_product = scaled_product / row_sum;`
    //     Wait, `state_vec` is Q16.16. `transition_matrix` is count (8-bit).
    //     Result is `state_vec * count / Sum`.
    //     This requires division in the inner loop. Too slow.
    
    //   Let's go back to normalizing the matrix first.
    //   We need 16 cycles for division. 
    //   We can do it in 16 cycles per element? No, total.
    //   We have 8 elements per row. 16*8 = 128 cycles per row.
    //   Too slow.
    
    //   Alternative: Store `1/Sum` (Q16.16) in `row_sum` register instead of sum.
    //   `row_sum` is 32-bit. `1/Sum` is Q16.16.
    //   Multiplication: `state_vec[i] * transition_matrix[i][j] * (1/Sum)`.
    //   This is `(state_vec[i] * transition_matrix[i][j]) >> 16` * `(1/Sum)`.
    //   Or `(state_vec[i] * transition_matrix[i][j]) * (1/Sum)` >> 16.
    //   We need to compute `1/Sum`.
    //   `1/Sum` in Q16.16 = 65536 / Sum.
    //   This is the same division problem.
    
    //   Let's optimize the division.
    //   Since Sum is small (<= 2040), we can use a lookup table (LUT) for `1/Sum`.
    //   LUT size: 2040 entries * 16 bits = 32KB. Too big for small FPGA/ASIC.
    //   Approximation: Shift and add.
    
    //   Let's assume we have a fast divider or we can do the division in 8 cycles (not 16).
    //   We can use a non-restoring division algorithm which might be faster or more efficient.
    //   Or we can use the fact that we just need to store the normalized probability.
    
    //   Let's reconsider the constraint: "Normalization: 8*8 = 64 cycles".
    //   This implies we don't do full precision division or we do it in parallel.
    //   Maybe we use a shift approximation: `prob = (edges << 16) / sum`.
    //   We can approximate `1/sum` using `1/sum ≈ 1/(2^k)`.
    //   But we need exact match for 0.95.
    
    //   Let's use a simplified division:
    //   `prob = (edges << 8) / sum` then shift left 8. 
    //   Or `prob = (edges * 256) / sum`.
    //   This loses precision.
    
    //   Let's use the standard division but unroll it.
    //   We have 8 cycles per element. 
    //   If we do 2 cycles of division per element, we can fit 16 steps over 8 elements? No.
    
    //   Let's use a LUT for `1/Sum` if Sum is 8-bit (0-255).
    //   Sum of 8 edges, each 8-bit. Max sum 2040.
    //   If we scale edges differently or cap sum.
    
    //   Let's stick to the math.
    //   `prob = (edges * 65536) / sum`.
    //   We will use the `NORMALIZE` state to compute this.
    //   To meet 64 cycles, we might need to relax precision or assume a hardware divider with < 8 cycle latency.
    //   But the prompt asks for Verilog.
    
    //   Let's implement a sequential divider that runs in the background or use a state machine.
    //   We can do: Sum row (8 cycles). Then for each element, run division (8 cycles * 8 elements = 64 cycles).
    //   Total 72 cycles.
    //   If we overlap sum calculation with division of previous row, we can fit.
    
    //   Let's refine the NORMALIZE loop:
    //   We use `col_idx` 0-15.
    //   0-7: Sum accumulation.
    //   8-15: Division (for elements 0-7).
    
    //   Division logic:
    //   We need 16 steps. We have 8 cycles.
    //   We can do 2 steps per cycle?
    //   Or we can use a smaller divisor representation.
    
    //   Let's use the fact that we just need to store the matrix.
    //   We will store `transition_matrix` as Q16.16.
    //   We will use a `div_step` counter (0-15).
    //   In the calculation phase (col_idx 8-15):
    //     We are calculating for element `col_idx - 8`.
    //     We need 16 cycles for division.
    //     We can extend the state.
    
    //   Let's change the state machine slightly.
    //   NORMALIZE: 
    //     Row 0: Sum (8 cycles).
    //     Row 0: Divide Element 0 (16 cycles).
    //     ...
    //     Row 0: Divide Element 7 (16 cycles).
    //   This is 8 + 8*16 = 136 cycles.
    
    //   To reduce cycles, we can share the divider.
    //   Or we can compute `prob = edges << 16 / sum`.
    //   Since `sum` is small, `prob` is large.
    //   We can use a shift-add divider.
    
    //   Let's try to fit it in 64 cycles by doing partial calculation.
    //   Or we can accept that 64 cycles is for a simpler case.
    //   We will implement a divider that takes 16 cycles total for all elements? No.
    
    //   Let's use a trick:
    //   `prob = (edges * 65536) / sum`.
    //   We can precompute `1/sum` using Newton-Raphson or lookup.
    //   Given the constraints, let's use a simple shift-based division.
    
    //   Actually, we can use the following:
    //   Store `edges` in `transition_matrix` initially.
    //   In the multiplication step:
    //   `term = state_vec[i] * transition_matrix[i][j] / row_sum`.
    //   We can compute `row_sum` once per row.
    //   This moves the division to the inner loop.
    //   Inner loop has 64 multiplies and 64 divisions. Too slow.
    
    //   Let's stick to normalizing the matrix.
    //   We will use a 16-bit LUT for `1/Sum` if Sum is 12-bit.
    //   Since Sum is 16-bit, LUT is too big.
    
    //   Let's implement a sequential divider in NORMALIZE state.
    //   We will use the `col_idx` loop.
    //   0-7: Calculate Sum.
    //   8-15: Calculate Prob.
    //   But we need 16 cycles for Prob.
    //   We can use `col_idx` to indicate which element we are calculating.
    //   And `div_step` for the division steps.
    
    //   Let's use `col_idx` 0-7 for element index.
    //   And `div_step` 0-15 for division steps.
    //   This gives 8 * 16 = 128 cycles.
    //   We can speed this up by calculating Sum in parallel for all rows? No.
    
    //   Let's reconsider the prompt's "64 cycles".
    //   Maybe they mean 64 multiply-accumulate operations for normalization.
    //   Division is separate.
    //   But the prompt says "Normalization: 8*8 = 64 cycles".
    
    //   Let's use a simplified normalization:
    //   `prob = (edges * 256) << 8 / sum`.
    //   Or just store raw edges and normalize in multiplication.
    
    //   Wait, if we normalize in multiplication:
    //   We need `row_sum` for each row.
    //   We can compute `row_sum` in NORMALIZE state (8 cycles).
    //   Then store `row_sum` and `edges` in `transition_matrix` (packed).
    //   This fits 64 cycles.
    
    //   Let's do that.
    //   NORMALIZE state:
    //   Calculate `row_sum` for each row.
    //   Store `row_sum` and `edges`.
    //   We need `transition_matrix` to hold `edges` (8-bit) and `row_sum` (16-bit) for each row.
    //   We can pack them.
    //   Or store `edges` in `transition_matrix` and `row_sum` in a separate array `row_sums[8]`.
    
    //   This is much better.
    //   In ITERATE:
    //   `prob = (state_vec[i] * edges) >> 16 / row_sum`.
    //   Wait, `(state_vec[i] * edges) >> 16` is `state_vec[i] * (edges / 65536)`.
    //   We want `state_vec[i] * edges / row_sum`.
    //   So `term = (state_vec[i] * edges) / row_sum`.
    //   We still need division.
    
    //   But `row_sum` is constant for a row.
    //   We can precompute `1/row_sum` (Q16.16) in NORMALIZE state.
    //   `inv_row_sum = 65536 / row_sum`.
    //   We can compute this in 16 cycles per row. 128 cycles total.
    //   Still slow.
    
    //   Let's use the normalized matrix.
    //   We will use a divider in NORMALIZE.
    //   We will use a 16-step divider.
    //   We will run the divider for 8 elements.
    //   Total 16 * 8 = 128 steps.
    //   We can do this in 128 cycles.
    //   The prompt allows 800 cycles. 128 + 640 = 768.
    //   So we can use 128 cycles for normalization.
    //   The "64 cycles" in the prompt is likely an estimate or for a simpler implementation.
    //   Let's proceed with the 128 cycle normalization (8 rows * 16 cycles).
    
    //   We need to change the NORMALIZE state logic.
    //   We will use `row_idx` (0-7), `col_idx` (0-7 for element), `div_step` (0-15).
    //   Or we can iterate linearly.
    
    //   Let's use `acc_idx` as the linear counter (0 to 127).
    //   `row_idx = acc_idx / 16`.
    //   `col_idx = acc_idx % 16`.
    //   If `col_idx < 8`: Accumulate sum.
    //   If `col_idx >= 8`: Division step for element `col_idx - 8`.
    
    //   Wait, we need to accumulate sum for the row first.
    //   Row 0: Sum (cycles 0-7). Div E0 (8-23). Div E1 (24-39)...
    //   Total cycles: 8 + 8*16 = 136.
    
    //   Let's use a two-stage approach.
    //   Stage 1: Compute sums for all rows (8 cycles).
    //   Store sums in `row_sums[8]`.
    //   Stage 2: Normalize matrix (8*8 = 64 cycles).
    //   Total 72 cycles.
    
    //   Stage 1: 8 cycles.
    //     `row_sums[row_idx]` accumulates.
    //   Stage 2: 64 cycles.
    //     `transition_matrix[row_idx][col_idx] <= (trans_in[row_idx][col_idx] * 65536) / row_sums[row_idx]`.
    
    //   We still need division in Stage 2.
    //   We have 64 cycles for 64 elements.
    //   1 cycle per element. No time for 16-step division.
    
    //   We must use a faster method or shared hardware.
    //   Let's use a lookup table for `1/row_sum`.
    //   Row sum is 16-bit (0-2040).
    //   We can use a 1024-entry LUT for `1/x` (approximation).
    //   Or we can use a multiplier: `prob = edges * (65536 / row_sum)`.
    //   We need to compute `65536 / row_sum` first.
    
    //   Let's use the normalization trick:
    //   `prob = (edges << 16) / row_sum`.
    //   We will use a 16-bit integer division unit.
    //   We can implement a sequential divider.
    //   If we want to fit 64 cycles, we can't do 16 steps per element.
    
    //   Let's assume we have a single-cycle divider (unlikely for Verilog).
    //   Or we can relax the precision.
    //   The prompt says "fixed-point Q16.16 arithmetic".
    
    //   Let's go with the 128 cycle normalization (8 rows * 16 cycles).
    //   We will use `NORMALIZE` state for 128 cycles.
    //   We will iterate `row_idx` 0-7.
    //   For each row, we calculate sum (8 cycles), then normalize 8 elements (8*16 cycles).
    //   Total 128 cycles.
    
    //   We need to modify the FSM.
    //   NORMALIZE state:
    //   If `row_idx` < 8:
    //     If `col_idx` < 8: Accumulate sum.
    //     Else: Run divider.
    
    //   We need to manage `div_step` (0-15).
    //   We need `div_temp` and `div_quot`.
    
    //   Let's refine the NORMALIZE logic.
    //   We will use `col_idx` to track which element we are normalizing (0-7).
    //   And `div_step` to track division progress (0-15).
    
    //   We will use `row_idx` to track the current row.
    
    //   Logic:
    //   If `row_idx` < 8:
    //     If `col_idx` == 0 && `div_step` == 0: 
    //       // Calculate sum for this row
    //       // We can do this in first 8 cycles of the row.
    //       // Let's dedicate cycles 0-7 to sum, 8-127 to div.
    //       
    //   This is getting complex.
    
    //   Let's simplify. 
    //   We will calculate sums in the first 8 cycles of NORMALIZE.
    //   Then we will calculate probs for 64 cycles.
    //   Total 72 cycles.
    //   For the prob calculation, we will use a sequential divider.
    //   We will use `row_idx` and `col_idx`.
    //   We will use `div_step`.
    //   We will iterate `row_idx` 0-7.
    //   Inside, iterate `col_idx` 0-7.
    //   For each element, run divider for 16 steps.
    //   This takes 128 cycles.
    
    //   Okay, let's accept 128 cycles for normalization.
    //   Prompt says "8*8 = 64 cycles". 
    //   Maybe they imply 1 cycle per element.
    //   We can use a shift-based approximation: `prob = edges << (16 - log2(sum))`.
    //   But we need exact match for 0.95.
    
    //   Let's implement the divider.
    //   We will use `NORMALIZE` state for 128 cycles.
    //   We will use `row_idx` (0-7), `col_idx` (0-7), `div_step` (0-15).
    //   We need a flag to know if we are summing or dividing.
    
    //   Let's use `acc_idx` as the main counter (0 to 127).
    //   `row_idx = acc_idx / 16`.
    //   `sub_idx = acc_idx % 16`.
    //   If `sub_idx < 8`: We are summing row `row_idx`. (Actually we need to sum BEFORE dividing).
    //   Let's change the order.
    
    //   We will use a separate pass for sums (8 cycles) and a pass for division (64 cycles with 16 steps each is 1024 cycles? No).
    
    //   Let's just do the division in the ITERATE state.
    //   Store raw edges in `transition_matrix`.
    //   Store `row_sum` in `row_sums`.
    //   In ITERATE, calculate `term = (state_vec[i] * transition_matrix[i][j]) / row_sums[j]`? No, sum over i.
    //   `next_state_vec[j] += state_vec[i] * transition_matrix[i][j] / row_sum_i`.
    //   Wait, `row_sum` depends on the source node `i`.
    //   So we need `row_sum[i]`.
    
    //   In ITERATE:
    //   `product = state_vec[i] * transition_matrix[i][j]`.
    //   `term = product / row_sum[i]`.
    //   This requires division in the inner loop.
    
    //   We need to pre-normalize.
    
    //   Let's go back to 128 cycle normalization.
    //   We will use `row_idx`, `col_idx`, `div_step`.
    //   We need to calculate sums first.
    
    //   We can do:
    //   Cycles 0-7: Calculate sums for all rows (parallel or sequential).
    //   Sequential: 
    //     `row_sums[row_idx]` += `trans_in[row_idx][col_idx]`.
    //     If `col_idx` == 7: next row.
    //   This takes 8*8 = 64 cycles.
    //   Then we calculate probs.
    //   64 elements. 16 cycles each? 1024 cycles. Too many.
    
    //   We must reduce the division complexity.
    //   Use `prob = (edges * 65536) / row_sum`.
    //   Use a single-cycle divider if possible (ASIC) or assume small latency.
    
    //   Given this is a text response, I will implement a sequential divider.
    //   I will try to fit it in the time budget by optimizing the state machine.
    
    //   Let's use a simple approach:
    //   NORMALIZE state:
    //   We iterate `row_idx` 0-7.
    //   For each row:
    //     1. Compute `row_sum` (8 cycles). Store in `row_sums[row_idx]`.
    //     2. For each `col_idx` 0-7:
    //        Compute `prob = (trans_in[row_idx][col_idx] * 65536) / row_sum`.
    //        Store in `transition_matrix[row_idx][col_idx]`.
    
    //   Step 2 takes 8*16 = 128 cycles (if 16 steps/div).
    //   Total 136 cycles.
    
    //   To reduce this, we can use a lookup table for `1/row_sum`.
    //   Since `row_sum` <= 2040, we can use a small LUT (2040 entries).
    //   Or we can use an approximation: `1/x ≈ 1/(2^k)`.
    
    //   Let's assume we have a function `inv_q16(x)` that returns 65536/x in 1 cycle.
    //   This is not realistic in basic Verilog.
    
    //   Let's implement the sequential divider.
    //   We will use `NORMALIZE` state for 136 cycles.
    //   We will use `row_idx` (0-7), `col_idx` (0-7), `div_step` (0-15).
    
    //   We need to manage the state transitions carefully.
    
    //   Let's define the `NORMALIZE` sub-states:
    //   State A: Calculate Sum (row_idx fixed, col_idx 0-7).
    //   State B: Divide (row_idx fixed, col_idx 0-7, div_step 0-15).
    
    //   We can merge them into one loop:
    //   We need to calculate Sum for a row before dividing its elements.
    
    //   We will use `row_idx` to iterate rows.
    //   We will use `col_idx` to iterate columns.
    //   We will use `div_step` to iterate division steps.
    
    //   Flow:
    //   Start Row `row_idx`:
    //     Calculate Sum: 8 cycles. Store in `row_sum`.
    //     For `col_idx` 0 to 7:
    //       Calculate Prob: 16 cycles.
    //       Store in `transition_matrix[row_idx][col_idx]`.
    
    //   Total cycles: 8 + 8*16 = 136.
    
    //   To implement this in one state (NORMALIZE), we need counters.
    //   `row_idx`: 0-7
    //   `col_idx`: 0-7 (for both sum and div, but sum uses it differently)
    //   `div_step`: 0-15
    
    //   Let's use `acc_idx` (0-135) to track progress.
    //   `acc_idx` 0-7: Sum row 0
    //   `acc_idx` 8-23: Div row 0, col 0
    //   ...
    
    //   This is getting complicated to decode.
    
    //   Let's use a simpler normalization:
    //   Store `raw_edges` in `transition_matrix`.
    //   Store `row_sum` in `row_sums`.
    //   In ITERATE, do: `term = (state_vec[i] * raw_edges) >> 16;` then `term = term / row_sum`.
    //   This is still division in the critical path.
    
    //   Let's optimize the division.
    //   Since `row_sum` is small, `1/row_sum` is large.
    //   `prob = edges * (65536 / row_sum)`.
    //   We can compute `inv_sum = 65536 / row_sum`.
    //   Then `prob = edges * inv_sum`.
    //   `edges` is 8-bit. `inv_sum` is 16-bit (Q16.16).
    //   `prob` is 32-bit (Q16.16).
    
    //   We need `inv_sum`. Division again.
    
    //   Let's stick to the prompt's constraints. "Normalization: 8*8 = 64 cycles".
    //   This strongly suggests 1 cycle per element.
    //   Maybe they imply `prob = (edges << 16) / sum` can be done in 1 cycle with a hardware divider.
    //   Or we can approximate.
    
    //   Let's use a shift approximation.
    //   `sum` is 16-bit. Find MSB of `sum`.
    //   `prob ≈ (edges << 16) >> msb`.
    //   This is `edges << (16 - msb)`.
    //   This is not accurate enough for 0.95.
    
    //   Let's assume a hardware divider with 8-cycle latency.
    //   We can pipeline the division.
    //   For 64 elements, 8 cycle latency means 64 + 8 = 72 cycles.
    //   This fits "64 cycles" loosely.
    
    //   We will implement a divider with 16-cycle latency (to be safe and exact).
    //   We will accept 128 cycles for normalization.
    //   The prompt says "Total < 800 cycles". 128 + 640 = 768.
    //   This is acceptable.
    
    //   We will use `NORMALIZE` state for 128 cycles.
    //   We will use `row_idx`, `col_idx`, `div_step`.
    
    //   Let's code the state machine for NORMALIZE.
    //   We need to calculate sums first.
    //   Let's use a flag `mode`: 0 for sum, 1 for div.
    
    //   We can do sum for row 0 (8 cycles), div row 0 (128 cycles? No, 8*16=128).
    //   Wait, sum for row 0 takes 8 cycles.
    //   Div for row 0 takes 8 * 16 = 128 cycles.
    //   Total 136 cycles.
    
    //   We can overlap sum calculation for row N with division for row N-1.
    //   This reduces cycles to 128 + 8 = 136.
    
    //   Let's use `col_idx` 0-15 for the combined cycle count per row.
    //   `col_idx` 0-7: Accumulate sum for current row (and maybe start division for previous row).
    //   `col_idx` 8-15: Division steps for current row.
    
    //   This requires storing `row_sum` from previous row.
    
    //   Let's keep it simple:
    //   Cycle 0-63: Calculate sums for all 8 rows (8 cycles/row).
    //   Cycle 64-191: Calculate probabilities (16 cycles/element * 8 elements/row * 8 rows).
    //   Total 192 cycles.
    
    //   To reduce this, we can calculate sums and probabilities row by row.
    //   Row 0: Sum (8) -> Div (128). Total 136.
    
    //   Let's go with the 136 cycle approach.
    //   We need to manage `row_idx`, `col_idx`, `div_step`.
    
    //   We will use `NORMALIZE` state.
    //   We need to detect when we are summing vs dividing.
    
    //   Let's use a 3-bit `norm_phase`.
    //   0: Sum row
    //   1: Div row
    
    //   We will iterate `row_idx` 0-7.
    //   For each row:
    //     `norm_phase` = 0. `col_idx` = 0-7. Accumulate `row_sum`.
    //     `norm_phase` = 1. `col_idx` = 0-7. `div_step` = 0-15.
    
    //   This is 8 + 8*16 = 136 cycles.
    
    //   We need to be careful with `div_step`.
    //   In phase 1, we iterate `col_idx` 0-7. For each `col_idx`, we iterate `div_step` 0-15.
    
    //   We can flatten this into a single counter `k` (0 to 135).
    //   `row_idx` = `k` / 136? No.
    
    //   Let's use nested loops in the code (which are unrolled).
    
    //   We will use `row_idx`, `col_idx`, `div_step`.
    //   We will use `norm_state` to track progress.
    //   `norm_state` 0: Sum (row_idx, col_idx).
    //   `norm_state` 1: Div (row_idx, col_idx, div_step).
    
    //   To make it fit in 64 cycles, maybe we should just store raw data and normalize during multiplication.
    //   But we established that's too slow for the inner loop.
    
    //   Let's assume the prompt's "64 cycles" is a typo or refers to a simpler case.
    //   We will implement the exact division.
    
    //   We need to handle the `done` signal.
    //   In `IDLE`, `done` is 0.
    //   In `DONE_STATE`, `done` is 1.
    
    //   We need to handle `start` pulse.
    //   `start` is 1-cycle pulse.
    //   In `IDLE`, if `start` is high, go to `NORMALIZE`.
    
    //   We need to handle `L` input.
    //   `current_t` starts at `L`.
    
    //   Let's finalize the code structure.
    
    //   Registers needed:
    //   `state`, `next_state`
    //   `cycle_count`
    //   `row_idx`, `col_idx`, `acc_idx` (used for various loops)
    //   `max_row`
    //   `current_t`
    //   `transition_matrix` (32-bit packed array)
    //   `state_vec` (32-bit packed array)
    //   `next_state_vec` (32-bit packed array)
    //   `row_sum` (32-bit accumulator)
    //   `mult_temp` (32-bit or 64-bit)
    //   `acc` (32-bit accumulator)
    //   `match_found`
    //   `product_reg` (64-bit for multiplication)
    //   `div_temp` (48-bit for division)
    //   `div_quot` (32-bit for division)
    //   `div_step` (4-bit for division counter)
    
    //   We need to be careful about variable reuse to save space.
    
    //   Let's write the code now.
    //   We will use the logic derived above.
    
    //   One detail: The prompt says "transitions[8][8]: 64 ports, each 8-bit".
    //   We defined them as `transitions_i_j`.
    //   We mapped them to `trans_in[i][j]`.
    
    //   We need to handle `N` input. `N` is 4-bit (1-8).
    //   `max_row` = `N - 1`.
    //   If `N` is 0 (invalid), we might need to handle it. Prompt says N<=8.
    //   We will assume `N` is valid.
    
    //   Let's code the normalization.
    //   We will use `norm_phase` register (1 bit): 0 for sum, 1 for div.
    //   We will use `row_idx` (0-7), `col_idx` (0-7), `div_step` (0-15).
    
    //   In NORMALIZE state:
    //   If `norm_phase` == 0:
    //     `row_sum` accumulates.
    //     If `col_idx` == 7: `norm_phase` <= 1; `col_idx` <= 0; `div_step` <= 0;
    //     Else: `col_idx` <= `col_idx` + 1.
    //   Else:
    //     Calculate division.
    //     If `div_step` == 0: Init `div_temp` and `div_quot`.
    //     Update `div_temp` and `div_quot`.
    //     `div_step` <= `div_step` + 1.
    //     If `div_step` == 15:
    //       Store result `div_quot` to `transition_matrix[row_idx][col_idx]`.
    //       `col_idx` <= `col_idx` + 1.
    //       `div_step` <= 0.
    //       If `col_idx` == 7:
    //         `norm_phase` <= 0; // Next row
    //         `row_idx` <= `row_idx` + 1.
    //         If `row_idx` == 7: Go to ITERATE.
    
    //   We need to handle `row_sum` reset for each row.
    //   In `norm_phase` == 0, `col_idx` == 0: `row_sum` <= 0.
    
    //   This seems feasible.
    
    //   Let's write the Verilog.

    // Internal variables for product and division
    reg [63:0] product_reg;
    reg [47:0] div_temp;
    reg [31:0] div_quot;
    reg [3:0] div_step;
    reg norm_phase; // 0: sum, 1: div

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            T_out <= 16'd0;
            done <= 1'b0;
            row_idx <= 8'd0;
            col_idx <= 8'd0;
            acc_idx <= 8'd0;
            current_t <= 16'd0;
            match_found <= 1'b0;
            norm_phase <= 1'b0;
            div_step <= 4'd0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                state_vec[i] <= 32'd0;
                next_state_vec[i] <= 32'd0;
                row_sums[i] <= 32'd0;
                for (int j = 0; j < 8; j = j + 1) begin
                    transition_matrix[i][j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    T_out <= 16'd0;
                    cycle_count <= 8'd0;
                    match_found <= 1'b0;
                    row_idx <= 8'd0;
                    col_idx <= 8'd0;
                    if (start) begin
                        max_row <= (N > 4'd0) ? (N - 4'd1) : 8'd7;
                        current_t <= L;
                        state_vec[0] <= 32'd65536;
                        for (int k = 1; k < 8; k = k + 1) begin
                            state_vec[k] <= 32'd0;
                        end
                        state <= NORMALIZE;
                        norm_phase <= 1'b0; // Start with sum
                        row_idx <= 8'd0;
                        col_idx <= 8'd0;
                    end
                end

                NORMALIZE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (norm_phase == 1'b0) begin // Sum phase
                        if (col_idx == 8'd0) begin
                            row_sum <= 32'd0;
                        end
                        row_sum <= row_sum + {24'd0, trans_in[row_idx][col_idx]};
                        
                        if (col_idx == 8'd7) begin
                            // Done with sum for this row
                            row_sums[row_idx] <= row_sum + {24'd0, trans_in[row_idx][7]}; // Add last element
                            norm_phase <= 1'b1; // Switch to div phase
                            col_idx <= 8'd0;
                            div_step <= 4'd0;
                        end else begin
                            col_idx <= col_idx + 8'd1;
                        end
                    end else begin // Div phase
                        if (div_step == 4'd0) begin
                            // Init division
                            div_temp <= {trans_in[row_idx][col_idx], 16'd0}; // 24 bits in lower part
                            div_quot <= 32'd0;
                        end
                        
                        // Division step
                        div_temp <= {div_temp[46:0], 1'b0}; // Shift left
                        div_quot <= {div_quot[30:0], 1'b0}; // Shift left
                        
                        // Check if we can subtract
                        // We compare upper 32 bits of div_temp (mostly 0) with row_sum
                        // Actually div_temp is 48-bit. row_sum is 16-bit effective.
                        // We need to align them.
                        // div_temp[47:16] contains the current dividend (scaled).
                        // row_sums[row_idx] is 32-bit but small.
                        
                        if (div_temp[47:16] >= row_sums[row_idx]) begin
                            div_temp[47:16] <= div_temp[47:16] - row_sums[row_idx];
                            div_quot[0] <= 1'b1;
                        end
                        
                        if (div_step == 4'd15) begin
                            // Division complete
                            // Store result
                            // div_quot is Q16.16 result.
                            transition_matrix[row_idx][col_idx] <= div_quot;
                            
                            if (col_idx == 8'd7) begin
                                // Done with this row
                                if (row_idx == 8'd7) begin
                                    // Done with all rows
                                    state <= ITERATE;
                                    row_idx <= 8'd0;
                                    col_idx <= 8'd0;
                                    acc_idx <= 8'd0; // Check phase
                                end else begin
                                    row_idx <= row_idx + 8'd1;
                                    norm_phase <= 1'b0; // Next row sum
                                    col_idx <= 8'd0;
                                end
                            end else begin
                                col_idx <= col_idx + 8'd1;
                                div_step <= 4'd0;
                            end
                        end else begin
                            div_step <= div_step + 4'd1;
                        end
                    end
                end

                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (match_found) begin
                        // Already found, waiting for next_state logic to move to DONE
                    end else if (current_t > (L + 9'd9)) begin
                        // No match found in range, waiting for next_state logic
                    end else begin
                        // Check phase or Compute phase
                        
                        if (acc_idx == 8'd0) begin // Check phase
                            // Check if state_vec[N-1] == TARGET (62259)
                            // Note: TARGET is 16-bit 62259. state_vec is 32-bit Q16.16.
                            // 0.95 is 62259/65536.
                            // So we compare with 32'd62259.
                            
                            if (state_vec[max_row] == 32'd62259) begin
                                match_found <= 1'b1;
                                T_out <= current_t;
                                result_valid <= 1'b1;
                            end else begin
                                if (current_t == (L + 9'd9)) begin
                                    // No match at the end of range
                                    // next_state logic will handle transition to DONE
                                end else begin
                                    // Start computation for next T
                                    // Clear next_state_vec
                                    for (int k = 0; k < 8; k = k + 1) begin
                                        next_state_vec[k] <= 32'd0;
                                    end
                                    acc_idx <= 8'd1; // Compute phase
                                    row_idx <= 8'd0;
                                    col_idx <= 8'd0;
                                    acc <= 32'd0;
                                end
                            end
                        end else if (acc_idx == 8'd1) begin // Compute phase
                            // Matrix Multiply: next_state_vec[col_idx] += state_vec[row_idx] * transition_matrix[row_idx][col_idx]
                            
                            // Multiply
                            // We need to compute product = state_vec[row_idx] * transition_matrix[row_idx][col_idx]
                            // Then shift right by 16.
                            // Add to acc.
                            
                            // Use product_reg (64-bit) for intermediate
                            // Note: We must handle the case where row_idx > max_row (effectively 0).
                            // Since we loop only to max_row, this is handled by loop bounds.
                            
                            if (row_idx <= max_row) begin
                                product_reg <= state_vec[row_idx] * transition_matrix[row_idx][col_idx];
                                // Accumulate upper 32 bits (Q16.16 result)
                                // product_reg[47:16] is the Q16.16 product.
                                acc <= acc + product_reg[47:16];
                            end
                            
                            // Increment row_idx
                            if (row_idx == max_row) begin
                                // Finished summing for this column
                                next_state_vec[col_idx] <= acc; // Store accumulated result
                                
                                // Move to next column
                                if (col_idx == max_row) begin
                                    // Finished all columns
                                    // Copy next_state_vec to state_vec
                                    // And increment current_t
                                    acc_idx <= 8'd2; // Copy phase
                                end else begin
                                    col_idx <= col_idx + 8'd1;
                                    row_idx <= 8'd0;
                                    acc <= 32'd0;
                                end
                            end else begin
                                row_idx <= row_idx + 8'd1;
                            end
                        end else if (acc_idx == 8'd2) begin // Copy phase
                            state_vec[0] <= next_state_vec[0];
                            state_vec[1] <= next_state_vec[1];
                            state_vec[2] <= next_state_vec[2];
                            state_vec[3] <= next_state_vec[3];
                            state_vec[4] <= next_state_vec[4];
                            state_vec[5] <= next_state_vec[5];
                            state_vec[6] <= next_state_vec[6];
                            state_vec[7] <= next_state_vec[7];
                            
                            current_t <= current_t + 16'd1;
                            acc_idx <= 8'd0; // Back to check
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Wait for start to go low
                end
            endcase
        end
    end
    
    // Internal array for row sums
    reg [31:0] row_sums [0:7];

endmodule
