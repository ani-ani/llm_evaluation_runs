module LongestNonDecreasingSequence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] n_i,
    input wire [23:0] T_i,
    input wire [8:0] arr_i,
    output reg [31:0] result,
    output reg done
);
    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] READ_INPUT    = 4'd1;
    localparam [3:0] COMPUTE_FREQ  = 4'd2;
    localparam [3:0] BUILD_2N      = 4'd3;
    localparam [3:0] LIS_LOOP      = 4'd4;
    localparam [3:0] RESULT_CALC   = 4'd5;
    localparam [3:0] DONE_STATE    = 4'd6;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Input storage
    reg [6:0] n_reg;
    reg [23:0] T_reg;
    reg [8:0] arr_reg [0:99];  // Max 100 elements
    reg [8:0] two_n_arr [0:199]; // 2n elements for LIS computation
    
    // Frequency counter (values 1-300, index 1-300)
    reg [23:0] freq [0:300];  // 301 entries, index 0 unused
    reg [23:0] max_freq;
    
    // BIT (Binary Indexed Tree) for LIS
    reg [15:0] bit_tree [0:300];  // Indexed by value rank (1-300)
    reg [15:0] bit_query_val;
    
    // Loop counters
    reg [6:0] idx;           // For array access
    reg [7:0] two_n_idx;     // For 2n array (0-199)
    reg [8:0] value_idx;     // For BIT operations (1-300)
    reg [7:0] i, j;          // Generic counters
    
    // Computation registers
    reg [15:0] current_lis;
    reg [15:0] max_lis_2n;
    reg [15:0] query_result;
    reg [15:0] update_val;
    
    // Cycle counter for timeout prevention
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd1024;
    
    // Temporary variables for BIT operations
    reg [8:0] bit_idx;
    reg [15:0] bit_val;
    
    integer k;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:          next_state = start ? READ_INPUT : IDLE;
            READ_INPUT:    next_state = (idx >= n_reg) ? COMPUTE_FREQ : READ_INPUT;
            COMPUTE_FREQ:  next_state = (idx >= n_reg) ? BUILD_2N : COMPUTE_FREQ;
            BUILD_2N:      next_state = (two_n_idx >= (n_reg << 1)) ? LIS_LOOP : BUILD_2N;
            LIS_LOOP:      next_state = (two_n_idx >= (n_reg << 1)) ? RESULT_CALC : LIS_LOOP;
            RESULT_CALC:   next_state = DONE_STATE;
            DONE_STATE:    next_state = IDLE;
            default:       next_state = IDLE;
        endcase
    end

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 11'd0;
            
            // Reset input storage
            n_reg <= 7'd0;
            T_reg <= 24'd0;
            for (k = 0; k < 100; k = k + 1) begin
                arr_reg[k] <= 9'd0;
            end
            for (k = 0; k < 200; k = k + 1) begin
                two_n_arr[k] <= 9'd0;
            end
            
            // Reset frequency array
            for (k = 0; k <= 300; k = k + 1) begin
                freq[k] <= 24'd0;
            end
            max_freq <= 24'd0;
            
            // Reset BIT
            for (k = 0; k <= 300; k = k + 1) begin
                bit_tree[k] <= 16'd0;
            end
            
            // Reset computation registers
            idx <= 7'd0;
            two_n_idx <= 8'd0;
            value_idx <= 9'd0;
            i <= 8'd0;
            j <= 8'd0;
            current_lis <= 16'd0;
            max_lis_2n <= 16'd0;
            query_result <= 16'd0;
            update_val <= 16'd0;
            bit_idx <= 9'd0;
            bit_val <= 16'd0;
            bit_query_val <= 16'd0;
            
        end else begin
            // Default assignments
            done <= 1'b0;
            cycle_count <= cycle_count + 11'd1;
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE_STATE;
            end else begin
                state <= next_state;
            end
            
            case (state)
                IDLE: begin
                    cycle_count <= 11'd0;
                    done <= 1'b0;
                    result <= 32'd0;
                    if (start) begin
                        n_reg <= n_i;
                        T_reg <= T_i;
                        idx <= 7'd0;
                        // Reset frequency array for new computation
                        for (k = 0; k <= 300; k = k + 1) begin
                            freq[k] <= 24'd0;
                        end
                        max_freq <= 24'd0;
                    end
                end
                
                READ_INPUT: begin
                    if (idx < n_reg && idx < 7'd100) begin
                        arr_reg[idx] <= arr_i;
                        idx <= idx + 7'd1;
                    end
                end
                
                COMPUTE_FREQ: begin
                    if (idx < n_reg) begin
                        // Increment frequency for current value
                        if (arr_reg[idx] >= 9'd1 && arr_reg[idx] <= 9'd300) begin
                            freq[arr_reg[idx]] <= freq[arr_reg[idx]] + 24'd1;
                        end
                        idx <= idx + 7'd1;
                    end else if (idx == n_reg) begin
                        // Find max frequency
                        if (value_idx <= 9'd300) begin
                            if (freq[value_idx] > max_freq) begin
                                max_freq <= freq[value_idx];
                            end
                            value_idx <= value_idx + 9'd1;
                        end else begin
                            value_idx <= 9'd0;
                            idx <= idx + 7'd1;
                        end
                    end
                end
                
                BUILD_2N: begin
                    // Create 2n array: repeat original array twice
                    if (two_n_idx < (n_reg << 1)) begin
                        two_n_arr[two_n_idx] <= arr_reg[two_n_idx % n_reg];
                        two_n_idx <= two_n_idx + 8'd1;
                    end
                end
                
                LIS_LOOP: begin
                    // Compute LIS on two_n_arr using BIT
                    if (two_n_idx < (n_reg << 1)) begin
                        // Get current value
                        bit_val <= two_n_arr[two_n_idx];
                        bit_idx <= two_n_arr[two_n_idx];
                        
                        // Query BIT for max LIS with values <= current
                        // BIT query: sum from 1 to idx
                        if (bit_idx > 9'd0) begin
                            if (bit_query_val < bit_tree[bit_idx]) begin
                                bit_query_val <= bit_tree[bit_idx];
                            end
                            bit_idx <= bit_idx - (bit_idx & (-bit_idx));
                        end else begin
                            // Query complete, compute update
                            current_lis <= bit_query_val + 16'd1;
                            if (bit_query_val + 16'd1 > max_lis_2n) begin
                                max_lis_2n <= bit_query_val + 16'd1;
                            end
                            // Prepare for update
                            bit_idx <= two_n_arr[two_n_idx];
                            bit_query_val <= 16'd0;
                            j <= 8'd1; // State for update phase
                        end
                    end else begin
                        j <= 8'd0;
                    end
                    
                    // Update BIT (runs in parallel with next query start)
                    if (j == 8'd1) begin
                        if (bit_idx <= 9'd300) begin
                            if (current_lis > bit_tree[bit_idx]) begin
                                bit_tree[bit_idx] <= current_lis;
                            end
                            bit_idx <= bit_idx + (bit_idx & (-bit_idx));
                        end else begin
                            j <= 8'd0;
                            two_n_idx <= two_n_idx + 8'd1;
                        end
                    end
                end
                
                RESULT_CALC: begin
                    // Compute final result
                    if (T_reg <= 24'd2) begin
                        // For T <= 2, LIS_2n already contains LIS of T periods
                        result <= {16'd0, max_lis_2n};
                    end else begin
                        // For T > 2: result = LIS_2n + (T - 2) * max_freq
                        // Use 32-bit multiplication to avoid overflow
                        result <= max_lis_2n + ((T_reg - 24'd2) * max_freq);
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    // Reset computation registers for next operation
                    idx <= 7'd0;
                    two_n_idx <= 8'd0;
                    value_idx <= 9'd0;
                    max_lis_2n <= 16'd0;
                    bit_query_val <= 16'd0;
                    current_lis <= 16'd0;
                    j <= 8'd0;
                    // Reset BIT for next use
                    for (k = 0; k <= 300; k = k + 1) begin
                        bit_tree[k] <= 16'd0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule