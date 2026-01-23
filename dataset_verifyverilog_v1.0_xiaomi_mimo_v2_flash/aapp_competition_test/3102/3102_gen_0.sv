module HouseNumberCounter (
    input clk,
    input rst_n,
    input start,
    input [15:0] lower_bound [0:15],
    input [15:0] upper_bound [0:15],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_DIGITS = 5'd16;
    localparam [4:0] OFFSET = 5'd20; // Max difference range [-20, 20]
    
    // Registers
    reg [2:0] state, next_state;
    reg [4:0] pos;           // Current position (0-15)
    reg [3:0] digit;         // Current digit being processed
    reg tight_lower;         // Tight constraint for lower bound
    reg tight_upper;         // Tight constraint for upper bound
    reg [4:0] diff_idx;      // Difference offset index [0-40]
    reg [31:0] dp_result;    // DP result accumulator
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd32;
    
    // Memory for DP state (position, tight_lower, tight_upper, diff) -> count
    // Each entry: 32 bits for count
    reg [31:0] dp_mem [0:4095]; // 2^12 = 4096 entries
    // Index mapping: {pos[3:0], tight_lower, tight_upper, diff_idx[5:0]}
    
    // Temporary memory for next position
    reg [31:0] next_dp_mem [0:4095];
    
    // Control signals
    reg [3:0] current_digit_lower, current_digit_upper;
    reg [4:0] next_diff;
    reg [31:0] temp_count;
    reg mem_write;
    reg [11:0] mem_idx, next_mem_idx;
    reg [4:0] loop_digit;
    reg [31:0] sum_val;
    
    integer i, j;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 5'd0;
            digit <= 4'd0;
            tight_lower <= 1'b0;
            tight_upper <= 1'b0;
            diff_idx <= 5'd0;
            dp_result <= 32'd0;
            cycle_count <= 5'd0;
            mem_write <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            for (i = 0; i < 4096; i = i + 1) begin
                dp_mem[i] <= 32'd0;
                next_dp_mem[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Initialize DP state
                    // Base case: pos=0, tight_lower=1, tight_upper=1, diff=0 -> count=1
                    mem_idx <= {4'd0, 2'b11, 6'd20}; // diff_idx = 20 (actual diff = 0)
                    dp_mem[{4'd0, 2'b11, 6'd20}] <= 32'd1;
                    
                    pos <= 5'd0;
                    tight_lower <= 1'b1;
                    tight_upper <= 1'b1;
                    diff_idx <= 5'd20;
                    mem_write <= 1'b0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    if (pos < MAX_DIGITS) begin
                        // Reset next_dp_mem to zero
                        for (i = 0; i < 4096; i = i + 1) begin
                            next_dp_mem[i] <= 32'd0;
                        end
                        
                        // Process current position
                        mem_write <= 1'b1;
                        
                        // Determine digit range based on tight constraints
                        if (pos == 5'd0) begin
                            current_digit_lower <= lower_bound[0][3:0];
                            current_digit_upper <= upper_bound[0][3:0];
                        end else begin
                            current_digit_lower <= tight_lower ? lower_bound[pos][3:0] : 4'd0;
                            current_digit_upper <= tight_upper ? upper_bound[pos][3:0] : 4'd9;
                        end
                        
                        // Compute next DP state
                        // Read current dp_mem for all combinations
                        // This would need combinational logic, but we simulate here
                        
                        if (cycle_count == MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end else begin
                        // Sum up final counts for diff_idx = 20 (actual diff = 0)
                        sum_val <= 32'd0;
                        for (i = 0; i < 4; i = i + 1) begin
                            for (j = 0; j < 4; j = j + 1) begin
                                mem_idx <= {MAX_DIGITS[3:0], i[1:0], j[1:0], 6'd20};
                                sum_val <= sum_val + dp_mem[{MAX_DIGITS[3:0], i[1:0], j[1:0], 6'd20}];
                            end
                        end
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= sum_val % MOD;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational DP logic (simplified - in practice this needs to handle all cases)
    always @(*) begin
        // This is a simplified combinational logic for the digit DP
        // In real implementation, this would be a large case statement
        // processing all valid digit transitions
        
        // For each valid digit in range, update next state
        // This is a placeholder for the actual DP computation
        // The full implementation would involve:
        // 1. Reading current dp_mem entry
        // 2. For each digit 0-9 in valid range:
        //    - Check digit != 4
        //    - Calculate new diff
        //    - Update next_dp_mem
    end
    
    // Note: The full digit DP implementation requires:
    // - Combinational block to process all states
    // - Sequential block to update memory
    // Due to complexity, this is a simplified structure
    // The actual DP would need detailed state transitions

endmodule