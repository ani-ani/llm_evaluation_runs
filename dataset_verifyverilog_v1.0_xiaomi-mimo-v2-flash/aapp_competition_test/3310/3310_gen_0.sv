module restaurant_expected (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] g,
    input wire [7:0] t,
    input wire [3:0] n,
    input wire [7:0] c_0, c_1, c_2, c_3, c_4, c_5, c_6, c_7,
    input wire [7:0] c_8, c_9, c_10, c_11, c_12, c_13, c_14, c_15,
    output reg [31:0] result,
    output reg done
);

// State declarations
localparam [3:0] IDLE        = 4'd0;
localparam [3:0] SORTING     = 4'd1;
localparam [3:0] INIT_DP     = 4'd2;
localparam [3:0] PROC_HOUR   = 4'd3;
localparam [3:0] PROC_STATE  = 4'd4;
localparam [3:4] ACCUMULATE  = 4'd5;
localparam [4:0] FINISH      = 4'd6;

reg [3:0] state;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

// Internal registers
reg [7:0] tables [0:15];  // Sorted table capacities
reg [7:0] tables_next [0:15];
reg [3:0] current_hour;
reg [15:0] state_mask;     // Current state mask (16 bits for 16 tables)
reg [63:0] state_prob;     // Probability of current state (Q16.16)
reg [63:0] next_state_prob;
reg [63:0] temp_prob;
reg [63:0] prob_accum;
reg [31:0] expected_sum;   // Accumulated expected value (Q32.32 actually, but output Q16.16)
reg [31:0] result_reg;

// Computation registers
reg [3:0] sort_i, sort_j;
reg [7:0] temp_swap;
reg [15:0] state_idx;
reg [15:0] max_states;
reg [3:0] table_idx;
reg [3:0] group_idx;
reg [3:0] best_table;
reg [3:0] group_size;
reg [3:0] bits_set;
reg [3:0] bits_clear;
reg [15:0] new_mask;
reg [63:0] prob_mult;
reg [63:0] expected_contrib;
reg [15:0] occupancy_count;

// Fixed-point constants (Q16.16)
localparam [31:0] ONE = 32'd65536;
localparam [31:0] INV_G_MAX = 32'h0000FFFF; // 1/255 approx

// Helper signals
reg [7:0] cap_sum;
reg [7:0] group_count;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        cycle_count <= 8'd0;
        current_hour <= 4'd0;
        state_mask <= 16'd0;
        state_prob <= 64'd0;
        expected_sum <= 32'd0;
        result_reg <= 32'd0;
        sort_i <= 4'd0;
        sort_j <= 4'd0;
        state_idx <= 16'd0;
        table_idx <= 4'd0;
        group_idx <= 4'd0;
        best_table <= 4'd0;
        group_size <= 4'd0;
        bits_set <= 4'd0;
        bits_clear <= 4'd0;
        new_mask <= 16'd0;
        prob_mult <= 64'd0;
        expected_contrib <= 64'd0;
        occupancy_count <= 16'd0;
        cap_sum <= 8'd0;
        group_count <= 8'd0;
        // Initialize tables
        for (i = 0; i < 16; i = i + 1) begin
            tables[i] <= 8'd0;
            tables_next[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                current_hour <= 4'd0;
                state_mask <= 16'd0;
                state_prob <= 64'd0;
                expected_sum <= 32'd0;
                result_reg <= 32'd0;
                sort_i <= 4'd0;
                sort_j <= 4'd0;
                state_idx <= 16'd0;
                table_idx <= 4'd0;
                group_idx <= 4'd0;
                best_table <= 4'd0;
                group_size <= 4'd0;
                bits_set <= 4'd0;
                bits_clear <= 4'd0;
                new_mask <= 16'd0;
                prob_mult <= 64'd0;
                expected_contrib <= 64'd0;
                occupancy_count <= 16'd0;
                cap_sum <= 8'd0;
                group_count <= 8'd0;
                
                if (start) begin
                    state <= SORTING;
                    // Load tables from inputs
                    tables[0] <= c_0;
                    tables[1] <= c_1;
                    tables[2] <= c_2;
                    tables[3] <= c_3;
                    tables[4] <= c_4;
                    tables[5] <= c_5;
                    tables[6] <= c_6;
                    tables[7] <= c_7;
                    tables[8] <= c_8;
                    tables[9] <= c_9;
                    tables[10] <= c_10;
                    tables[11] <= c_11;
                    tables[12] <= c_12;
                    tables[13] <= c_13;
                    tables[14] <= c_14;
                    tables[15] <= c_15;
                end
            end
            
            SORTING: begin
                // Bubble sort tables by capacity
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= INIT_DP;
                end else if (sort_i < n) begin
                    if (sort_j < n - sort_i - 4'd1) begin
                        if (tables[sort_j] > tables[sort_j + 4'd1]) begin
                            // Swap
                            tables[sort_j] <= tables[sort_j + 4'd1];
                            tables[sort_j + 4'd1] <= tables[sort_j];
                        end
                        sort_j <= sort_j + 4'd1;
                    end else begin
                        sort_i <= sort_i + 4'd1;
                        sort_j <= 4'd0;
                    end
                end else begin
                    state <= INIT_DP;
                    cycle_count <= 8'd0;
                end
            end
            
            INIT_DP: begin
                // Initialize DP state
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count == 8'd1) begin
                    state_prob <= 64'd65536; // Initial probability 1.0
                    state_mask <= 16'd0;     // All tables empty
                    state <= PROC_HOUR;
                    current_hour <= 4'd0;
                end
            end
            
            PROC_HOUR: begin
                // Process each hour
                if (current_hour < t[3:0]) begin
                    state <= PROC_STATE;
                    state_idx <= 16'd0;
                    state_prob <= 64'd65536; // Reset for new iteration
                    state_mask <= 16'd0;
                    expected_sum <= expected_sum; // Keep accumulating
                end else begin
                    // Done with all hours
                    result_reg <= expected_sum[31:16]; // Convert to Q16.16
                    state <= FINISH;
                end
            end
            
            PROC_STATE: begin
                // Iterate through all possible states (2^n)
                if (state_idx < (16'd1 << n)) begin
                    // Check if this state is reachable
                    if (state_prob != 64'd0) begin
                        // Generate group sizes
                        group_size <= g[3:0]; // Use scaled value
                        group_idx <= 4'd0;
                        // Count set bits (occupied tables)
                        bits_set <= 4'd0;
                        bits_clear <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n) begin
                                if (state_mask[i]) bits_set <= bits_set + 4'd1;
                                else bits_clear <= bits_clear + 4'd1;
                            end
                        end
                        
                        // Try each possible group size (1 to g)
                        if (g[3:0] > 4'd0) begin
                            // Find best table for this group size
                            best_table <= 4'd15;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < n && !state_mask[i] && tables[i] >= group_size) begin
                                    if (best_table == 4'd15) best_table <= i;
                                end
                            end
                            
                            if (best_table != 4'd15) begin
                                // Generate new state
                                new_mask <= state_mask | (16'd1 << best_table);
                                // Probability * (1/g)
                                prob_mult <= state_prob / g[3:0];
                                // Expected contribution: occupied people
                                occupancy_count <= 16'd0;
                                // Count expected people in current state
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i < n && state_mask[i]) begin
                                        occupancy_count <= occupancy_count + tables[i];
                                    end
                                end
                                // Add contribution: sum(people * prob * (1/g))
                                expected_contrib <= (occupancy_count * state_prob) / g[3:0];
                            end
                        end
                        state <= ACCUMULATE;
                    end else begin
                        // Skip unreachable state
                        state_idx <= state_idx + 16'd1;
                    end
                end else begin
                    // Done with all states for this hour
                    state <= PROC_HOUR;
                    current_hour <= current_hour + 4'd1;
                end
            end
            
            ACCUMULATE: begin
                // Accumulate expected value and probability for next states
                // This is a simplified approximation
                expected_sum <= expected_sum + expected_contrib[47:16];
                // Move to next group size or next state
                if (group_idx < g[3:0] - 4'd1) begin
                    group_idx <= group_idx + 4'd1;
                    group_size <= group_size - 4'd1;
                    state <= PROC_STATE; // Loop back
                end else begin
                    state_idx <= state_idx + 16'd1;
                    // Reset probability for next state
                    state_prob <= 64'd0;
                    state <= PROC_STATE;
                end
            end
            
            FINISH: begin
                result <= result_reg;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule