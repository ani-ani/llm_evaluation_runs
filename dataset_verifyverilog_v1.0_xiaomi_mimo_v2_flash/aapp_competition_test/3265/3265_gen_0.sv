module vacation_planner(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] L,
    input wire [15:0] trans_matrix [63:0],  // 8x8 flattened
    output reg [5:0] T,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] UPDATE  = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] DONE    = 3'd4;
    
    // Constants
    localparam [7:0] N = 8'd8;
    localparam [7:0] TOLERANCE = 8'd2;  // 1/256 tolerance
    localparam [7:0] TARGET_LOW = 8'd242;
    localparam [7:0] TARGET_HIGH = 8'd244;
    localparam [7:0] MAX_DAY = 8'd25;  // L + 9 where L max is 16
    localparam [7:0] ABSORBING_STATE = 8'd256;
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] day;
    reg [7:0] day_L_plus_9;
    reg [7:0] t_candidate;
    reg [7:0] state_reg [0:7];  // Current state vector (8 elements, Q8.8)
    reg [7:0] next_state_reg [0:7];  // New state vector
    reg [15:0] sum_temp;  // For accumulation
    reg [7:0] i;  // Loop counter for nodes
    reg [7:0] j;  // Loop counter for nodes (inner loop)
    reg [7:0] idx;  // Index for trans_matrix
    
    // Combinational logic for state update calculation
    wire [15:0] matrix_val [0:7][0:7];
    genvar g_i, g_j;
    generate
        for (g_i = 0; g_i < 8; g_i = g_i + 1) begin : gen_matrix
            for (g_j = 0; g_j < 8; g_j = g_j + 1) begin : gen_inner
                assign matrix_val[g_i][g_j] = trans_matrix[g_i * 8 + g_j];
            end
        end
    endgenerate
    
    // Next state logic
    always @(*) begin
        next_state = state;  // Default
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: next_state = UPDATE;
            UPDATE: next_state = CHECK;
            CHECK: begin
                if (day < day_L_plus_9) begin
                    next_state = UPDATE;
                end else begin
                    next_state = DONE;
                end
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Combinational logic for next state calculation
    reg [15:0] calc_sum;
    reg [7:0] new_val;
    reg [7:0] j_temp;
    integer k;
    
    always @(*) begin
        calc_sum = 16'd0;
        new_val = 8'd0;
        
        // Default: keep next_state_reg = state_reg
        for (k = 0; k < 8; k = k + 1) begin
            next_state_reg[k] = state_reg[k];
        end
        
        if (state == UPDATE) begin
            for (k = 0; k < 8; k = k + 1) begin
                calc_sum = 16'd0;
                // Sum over i: state[i] * trans_matrix[i][k]
                // state[i] is Q8.8, matrix is Q8.8, product is Q16.16
                // We need Q16.8 (shift right by 8) = sum >> 8
                // Actually: (state[i] * matrix) >> 8
                // state[i] = state_reg[k_val] (8-bit)
                // matrix[i][k] = trans_matrix[i*8 + k] (16-bit, Q8.8)
                // product = state_reg[k_val] * matrix[i][k] (16-bit * 8-bit = 24-bit)
                // Wait, spec says trans_matrix is 16-bit Q8.8
                // state is Q8.8 (8-bit, assuming only fractional part is stored)
                // So product = state[i] * matrix[i][k] >> 8
                // matrix[i][k] is 16-bit Q8.8, state[i] is 8-bit Q8.8 (implicitly 0.
                // Actually, Q8.8 means 8 integer, 8 fractional.
                // If we store in 16-bit: s[15:8] = int, s[7:0] = frac.
                // But state_reg is 8-bit. Spec says "state vector: [256, 0, ..., 0] (Q8.8)"
                // 256 in Q8.8 is 256.0 = 0x0100. This requires 9 bits minimum.
                // Let's assume state stores the *value* directly in Q8.8 format in a wider register.
                // The spec says "Use 32-bit state vector registers for intermediate calculations"
                // So state_reg should be 32-bit. Let's fix this.
                // Re-interpreting: state_reg[i] stores value in Q8.8 format in 32 bits.
                // 256.0 = 256 * 256 = 65536 decimal = 0x00010000.
                // matrix is 16-bit Q8.8. Value 256.0 = 0x0100.
                // Update: new_state[j] = sum_i (state[i] * trans_matrix[i][j]) >> 8
                // state[i] is Q8.8 in 32 bits. matrix is Q8.8 in 16 bits.
                // product is Q16.16 in 32 bits. >> 8 makes it Q16.8.
                // We want to keep Q8.8? No, intermediate calculations grow.
                // Spec says "32-bit state vector registers". So state_reg[i] is 32-bit.
            end
        end
    end
    
    // REDO LOGIC WITH 32-BIT STATE REGISTERS
    reg [31:0] state_reg_32 [0:7];
    reg [31:0] next_state_reg_32 [0:7];
    reg [31:0] sum_32;
    reg [31:0] prod_32;
    reg [31:0] matrix_val_ext;
    
    // Matrix extraction (comb)
    always @(*) begin
        // Reset sum accumulators
        for (k = 0; k < 8; k = k + 1) begin
            sum_32 = 32'd0;
        end
    end
    
    // Main sequential logic
    integer m, n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            T <= 6'b111111;
            done <= 1'b0;
            day <= 8'd0;
            day_L_plus_9 <= 8'd0;
            t_candidate <= 8'd0;
            for (m = 0; m < 8; m = m + 1) begin
                state_reg_32[m] <= 32'd0;
                next_state_reg_32[m] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    T <= 6'b111111;  // Default to -1
                    if (start) begin
                        // Initialize t_candidate
                        t_candidate <= 8'd0;
                    end
                end
                
                INIT: begin
                    day <= 8'd1;
                    day_L_plus_9 <= L + 9'd9;
                    // Initialize state vector: [256, 0, ..., 0]
                    // 256.0 in Q8.8 = 256 * 256 = 65536
                    state_reg_32[0] <= 32'd65536;
                    for (m = 1; m < 8; m = m + 1) begin
                        state_reg_32[m] <= 32'd0;
                    end
                end
                
                UPDATE: begin
                    day <= day + 8'd1;
                    // Compute next_state from state_reg_32 and trans_matrix
                    // For each j (0 to 7):
                    // new_state[j] = sum_i (state[i] * trans_matrix[i][j]) >> 8
                    // trans_matrix[i][j] is 16-bit Q8.8. 256.0 = 0x0100.
                    // state[i] is 32-bit Q8.8. 256.0 = 0x00010000.
                    // product = state[i] * matrix_val
                    // state[i] (Q16.16) * matrix_val (Q8.8) = Q24.24
                    // >> 8 -> Q24.16
                    // We store in Q8.8? No, spec says 32-bit vector.
                    // Let's assume we keep it in high bits.
                    // matrix_val is 16-bit. Extended to 32-bit: {16'b0, val}.
                    // product = state_reg_32[m] * {16'b0, matrix_val}
                    // Result is 48-bit. We take [47:16] (Q24.24 to Q24.16? No)
                    // state (32b Q16.16) * matrix (16b Q8.8) = 48b Q24.24
                    // >> 8 -> 48b Q24.16. Keep 32 bits (MSB part) or LSB part?
                    // Spec says ">> 8". This is integer division or shift.
                    // If values are Q8.8, multiplication gives Q16.16.
                    // Summing these gives wider range.
                    // Let's use 64-bit accumulator for sum.
                    // Accumulator per j.
                    for (n = 0; n < 8; n = n + 1) begin
                        // Calculate sum for new_state[n]
                        next_state_reg_32[n] <= 32'd0;  // Reset previous
                        next_state_reg_32[n] <= next_state_reg_32[n] + 32'd0; // Dummy
                    end
                    
                    // Execute calculation in this cycle (combinational logic needed)
                    // Since it's sequential, we do one term per cycle or unroll?
                    // To be safe and small, let's do inner loop in UPDATE state.
                    // But UPDATE is one state. We need multiple cycles.
                    // Let's use i and j counters.
                    // We will compute one element per cycle using i/j registers.
                end
                
                CHECK: begin
                    // If day is in range [L, L+9] (inclusive)
                    // day counts from 1 to L+9.
                    // Check if day >= L and day <= L+9
                    // And check state_reg_32[N-1] value.
                    // Value is in Q8.8. Target 0.95 = 242/256.
                    // 242/256 * 256 = 242.
                    // Stored as 242 * 256 = 61952.
                    // Tolerance 1/256 * 256 = 1.
                    // Range [61952 - 256, 61952 + 256] = [61696, 62208].
                    // Wait, 242/256 * 256 = 242. So value is 242.
                    // No, Q8.8 means integer part is upper 8 bits.
                    // 0.95 is fraction. 0.95 * 256 = 242. So lower 8 bits are 242.
                    // Integer part is 0.
                    // Value is 0.95 -> 0x00F2 (242 decimal).
                    // Target range [242, 244] in lower 8 bits.
                    // Check state_reg_32[7][15:0] (assuming Q8.8 fits in 16 bits)
                    // But state_reg_32 is 32-bit. Let's check the magnitude.
                    // 256.0 = 65536. 0.95 = 242.
                    // It seems state_reg stores value * 256.
                    // So 242 <= state_reg_32[7] <= 244 (approx, depending on exact format)
                    // Spec says Q8.8. 242 = 242.0? No, 242/256 = 0.945.
                    // Target 0.95 is 243.2/256. So [242, 244].
                    // If value is 242, it is stored as 242.
                    // If value is 0.95 * 256 = 243.2 -> 243.
                    // So check state_reg_32[7] directly (since integer part is 0).
                    
                    if (day >= L && day <= day_L_plus_9) begin
                        if (state_reg_32[7] >= 32'd242 && state_reg_32[7] <= 32'd244) begin
                            // If we haven't found a T yet, or if this day is smaller
                            if (t_candidate == 8'd0) begin
                                t_candidate <= day;
                            end
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (t_candidate != 8'd0) begin
                        T <= t_candidate;  // T is 6-bit, day is up to 25
                    end else begin
                        T <= 6'b111111;  // -1
                    end
                end
            endcase
        end
    end
    
    // Combinational logic for UPDATE state (iterative)
    // We need to handle the loops. Unrolling is hard for 8x8 in one cycle.
    // Let's use a counter-based approach for UPDATE.
    // UPDATE state will take 64 cycles (8x8) to compute new state.
    // We need a new state to track this computation phase.
    // Let's refine the FSM.
    // States: IDLE, INIT, CALC_ROW (loop i), CALC_COL (loop j), APPLY, CHECK, DONE
    // To minimize states, let's do i loop in one state, j loop inside.
    // Actually, simpler: IDLE -> INIT -> CALC_START -> CALC_LOOP -> CHECK -> DONE
    
    // Redefining FSM for clarity
    // State 0: IDLE
    // State 1: INIT (set day=1, state[0]=256)
    // State 2: CALC_START (reset inner counters)
    // State 3: CALC_LOOP (compute new_state[j] for current i, or accumulate)
    // State 4: APPLY_STATE (move new_state -> state)
    // State 5: CHECK_DAY (check if in range)
    // State 6: LOOP_CTRL (increment day, check if done)
    // State 7: FINISH
    
    // Re-writing logic with explicit counters
    reg [2:0] calc_state;
    localparam [2:0] C_IDLE = 3'd0;
    localparam [2:0] C_INIT = 3'd1;
    localparam [2:0] C_ACCUM = 3'd2;
    localparam [2:0] C_APPLY = 3'd3;
    localparam [2:0] C_CHECK = 3'd4;
    localparam [2:0] C_NEXT_DAY = 3'd5;
    localparam [2:0] C_DONE = 3'd6;
    
    // Helper registers for calculation
    reg [7:0] row_idx;  // i
    reg [7:0] col_idx;  // j
    reg [31:0] acc_val; // Accumulator for new_state[j]
    reg [31:0] new_state_vec [0:7];
    
    // Matrix value lookup (comb)
    wire [15:0] m_val;
    assign m_val = trans_matrix[{row_idx[2:0], col_idx[2:0]}];  // row*8 + col
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc_state <= C_IDLE;
            T <= 6'b111111;
            done <= 1'b0;
            day <= 8'd0;
            day_L_plus_9 <= 8'd0;
            t_candidate <= 8'd0;
            row_idx <= 8'd0;
            col_idx <= 8'd0;
            acc_val <= 32'd0;
            for (m = 0; m < 8; m = m + 1) begin
                state_reg_32[m] <= 32'd0;
                new_state_vec[m] <= 32'd0;
            end
        end else begin
            case (calc_state)
                C_IDLE: begin
                    done <= 1'b0;
                    T <= 6'b111111;
                    t_candidate <= 8'd0;
                    if (start) calc_state <= C_INIT;
                end
                
                C_INIT: begin
                    day <= 8'd1;
                    day_L_plus_9 <= L + 9'd9;
                    state_reg_32[0] <= 32'd65536;  // 256.0 * 256
                    for (m = 1; m < 8; m = m + 1) begin
                        state_reg_32[m] <= 32'd0;
                    end
                    calc_state <= C_CHECK;  // Go check day 1 immediately? 
                    // Spec says "For day = 1 to L+9". Check if day in [L, L+9].
                    // Since L >= 1, day 1 is usually not in range.
                    // But we should check.
                end
                
                C_CHECK: begin
                    // Check condition for current day/state
                    if (day >= L && day <= day_L_plus_9) begin
                        // Check state[N-1] (node 7) is in [242, 244]
                        // state_reg_32[7] is value * 256 (Q8.8)
                        // 242/256 -> 242. 244/256 -> 244.
                        // Wait, 0.95 * 256 = 243.2. Range is 0.95 ± 1/256.
                        // Lower: 0.95 - 1/256 = (243.2 - 1)/256 = 242.2/256.
                        // Upper: 0.95 + 1/256 = (243.2 + 1)/256 = 244.2/256.
                        // Integer value in Q8.8 (assuming no integer part): 242 to 244.
                        // So check if 242 <= state_reg_32[7] <= 244.
                        // BUT: state_reg stores value * 256.
                        // So 242.2/256 * 256 = 242.2. 
                        // Actually, standard Q8.8 format stores value * 256 as integer.
                        // So check 242 <= value <= 244.
                        // Since we multiplied by 256 earlier: 256.0 is 65536.
                        // Wait. 256.0 is 65536 / 256 = 256.
                        // The state vector [256, 0, ...] is in Q8.8.
                        // 256.0 has integer part 256, fractional 0.
                        // 256.0 in Q8.8 is 0x0100 (16 bits).
                        // 256.0 in Q8.8 is 65536 in integer (32 bits).
                        // 0.95 in Q8.8 is 0.95 * 256 = 243.2 -> 243.
                        // Tolerance 1/256 = 1.
                        // Range [242, 244] in integer representation.
                        // So check state_reg_32[7] directly against 242, 244.
                        // BUT! state_reg_32 was initialized to 65536 (256.0).
                        // This implies state_reg stores value * 256.
                        // 0.95 * 256 = 243.
                        // 242 <= 243 <= 244.
                        // So we check integer part directly.
                        // Wait, 256.0 is 256.0. 0.95 is 0.95.
                        // If 256.0 -> 65536, then 1.0 -> 256.
                        // 0.95 -> 243.
                        // Yes, check [242, 244].
                        if (state_reg_32[7] >= 32'd242 && state_reg_32[7] <= 32'd244) begin
                            if (t_candidate == 8'd0) begin
                                t_candidate <= day;
                            end
                        end
                    end
                    calc_state <= C_NEXT_DAY;
                end
                
                C_NEXT_DAY: begin
                    if (day >= day_L_plus_9) begin
                        calc_state <= C_DONE;
                    end else begin
                        day <= day + 8'd1;
                        // Compute new state
                        row_idx <= 8'd0;
                        col_idx <= 8'd0;
                        acc_val <= 32'd0;
                        // Initialize new_state_vec to 0
                        for (m = 0; m < 8; m = m + 1) begin
                            new_state_vec[m] <= 32'd0;
                        end
                        calc_state <= C_ACCUM;
                    end
                end
                
                C_ACCUM: begin
                    // Compute new_state[col_idx] += state[row_idx] * trans_matrix[row_idx][col_idx]
                    // state[row_idx] is 32-bit (Q16.16ish)
                    // matrix is 16-bit Q8.8
                    // product = state[row_idx] * {16'b0, m_val}
                    // product is 48-bit. We need sum of these.
                    // sum >> 8.
                    // Let's just accumulate in high bits.
                    // m_val is 16-bit Q8.8. Extend to 32-bit: {16'b0, m_val} or sign extended.
                    // m_val is unsigned? Probably.
                    // state[row_idx] is 32-bit. 
                    // prod = state[row_idx] * m_val.
                    // acc_val += prod.
                    
                    // Optimization: Do we need full precision?
                    // We can do acc_val += (state[row_idx] >> 8) * m_val.
                    // state[row_idx] is large (up to 65536). 
                    // Let's assume state[row_idx] is already Q8.8 in 32 bits (max 2^24).
                    // m_val is Q8.8.
                    // Sum needs to be large. 
                    // Let's use a 64-bit temp calculation if possible, or 48-bit.
                    // Verilog arrays can't be 64-bit easily in always blocks without loops.
                    // Let's stick to 32-bit but be careful with overflow.
                    // Max state: 8 * 256.0 * 256.0 = 524288. Fits in 32 bits.
                    // Max matrix: 256.0.
                    // Product: 524288 * 256 = 134,217,728. Fits in 32 bits? No, 2^27.
                    // 2^32 is 4.29B. 134M fits.
                    // Wait, 256.0 is 65536. 8*65536 = 524288.
                    // 524288 * 256 = 134,217,728. Fits in 32 bits (signed).
                    // So accumulation fits in 32 bits.
                    // Shift by 8 at the end (division by 256).
                    
                    acc_val <= acc_val + ((state_reg_32[row_idx] >> 8) * m_val);
                    
                    // Advance counters
                    if (col_idx < 8'd7) begin
                        col_idx <= col_idx + 8'd1;
                    end else begin
                        col_idx <= 8'd0;
                        // Finished sum for this col? No, loop is usually row-major.
                        // new_state[j] = sum_i state[i] * M[i][j]
                        // Inner loop is i (row). Outer loop is j (col).
                        // So we iterate i (row_idx) for fixed j (col_idx).
                        // Once i reaches 7, we store result for j, then increment j.
                    end
                    
                    if (row_idx < 8'd7) begin
                        row_idx <= row_idx + 8'd1;
                    end else begin
                        // Finished one column
                        row_idx <= 8'd0;
                        // Store acc_val >> 8 into new_state_vec[col_idx]
                        // But acc_val is accumulating for CURRENT col_idx.
                        // We need to reset acc_val for next col_idx.
                        // And save current acc_val.
                        
                        // We need to save acc_val before resetting.
                        // This is tricky in single cycle.
                        // Let's modify logic:
                        // Loop: i=0..7, j=0..7.
                        // We process one (i,j) pair per cycle.
                        // We need to accumulate sum for j.
                        // When j changes, we must have saved the sum.
                        // So we need to detect j change.
                        
                        // Better: Standard nested loop order.
                        // for j=0..7:
                        //   acc=0
                        //   for i=0..7:
                        //     acc += state[i] * M[i][j]
                        //   new_state[j] = acc >> 8
                        // 
                        // Implementing this in hardware iteratively:
                        // State C_ACCUM processes (i, j).
                        // If i<7, next state C_ACCUM (i++).
                        // If i==7, next state C_SAVE (store acc, reset acc, j++).
                        // 
                        // Let's refine C_ACCUM.
                        // We will increment row_idx.
                        // When row_idx hits 7, we save result.
                    end
                    
                    if (row_idx == 8'd7) begin
                        // Last row. Sum complete for this column.
                        new_state_vec[col_idx] <= acc_val >> 8;  // Shift right by 8
                        acc_val <= 32'd0;
                        
                        if (col_idx < 8'd7) begin
                            col_idx <= col_idx + 8'd1;
                            // Stay in C_ACCUM for next column
                        end else begin
                            // All columns done
                            calc_state <= C_APPLY;
                        end
                    end
                end
                
                C_APPLY: begin
                    // Copy new_state_vec to state_reg_32
                    for (m = 0; m < 8; m = m + 1) begin
                        state_reg_32[m] <= new_state_vec[m];
                    end
                    calc_state <= C_CHECK;
                end
                
                C_DONE: begin
                    done <= 1'b1;
                    if (t_candidate != 8'd0) begin
                        T <= t_candidate;
                    end else begin
                        T <= 6'b111111;
                    end
                    calc_state <= C_IDLE;
                end
                
                default: calc_state <= C_IDLE;
            endcase
        end
    end

endmodule