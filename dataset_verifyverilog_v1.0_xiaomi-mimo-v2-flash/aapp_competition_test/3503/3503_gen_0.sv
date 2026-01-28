module distinct_results(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [31:0] a[15:0],
    input wire signed [31:0] b[15:0],
    output reg [1:0] op[15:0],
    output reg signed [31:0] result[15:0],
    output reg valid,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COMPUTE    = 3'd1;
    localparam [2:0] ASSIGN     = 3'd2;
    localparam [2:0] CHECK      = 3'd3;
    localparam [2:0] BACKTRACK  = 3'd4;
    localparam [2:0] FINISH     = 3'd5;
    localparam [2:0] IMPOSSIBLE = 3'd6;

    // Operation codes
    localparam [1:0] OP_ADD = 2'd0;
    localparam [1:0] OP_SUB = 2'd1;
    localparam [1:0] OP_MUL = 2'd2;

    // Registers
    reg [2:0] state;
    reg [3:0] current_pair;
    reg [1:0] op_try;
    reg [15:0] used_results[15:0];  // Track which result index is used for each pair
    reg [15:0] used_results_mask;
    reg signed [31:0] computed_results[3:0];  // Results for current pair
    reg signed [31:0] result_temp;
    reg [3:0] search_idx;
    reg [3:0] backtrack_depth;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 8'd0;
            current_pair <= 4'd0;
            op_try <= 2'd0;
            used_results_mask <= 16'd0;
            backtrack_depth <= 4'd0;
            search_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                op[i] <= 2'd0;
                result[i] <= 32'd0;
                used_results[i] <= 16'd0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                computed_results[i] <= 32'd0;
            end
            result_temp <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    current_pair <= 4'd0;
                    op_try <= 2'd0;
                    used_results_mask <= 16'd0;
                    backtrack_depth <= 4'd0;
                    search_idx <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        op[i] <= 2'd0;
                        result[i] <= 32'd0;
                        used_results[i] <= 16'd0;
                    end
                    for (i = 0; i < 4; i = i + 1) begin
                        computed_results[i] <= 32'd0;
                    end
                    result_temp <= 32'd0;
                    
                    if (start && (n >= 4'd1) && (n <= 4'd16)) begin
                        state <= COMPUTE;
                        current_pair <= 4'd0;
                        op_try <= OP_ADD;
                        cycle_count <= 8'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute all 3 operations for current pair
                    // Addition (truncate to 32-bit signed)
                    computed_results[0] <= a[current_pair] + b[current_pair];
                    // Subtraction (truncate to 32-bit signed)
                    computed_results[1] <= a[current_pair] - b[current_pair];
                    // Multiplication (truncate lower 32 bits of 64-bit result)
                    computed_results[2] <= (a[current_pair] * b[current_pair])[63:32];
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        state <= ASSIGN;
                    end
                end

                ASSIGN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Try operations in fixed order: +, -, *
                    if (op_try == OP_ADD) begin
                        result_temp <= computed_results[0];
                    end else if (op_try == OP_SUB) begin
                        result_temp <= computed_results[1];
                    end else begin  // OP_MUL
                        result_temp <= computed_results[2];
                    end
                    
                    state <= CHECK;
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    search_idx <= 4'd0;
                    
                    // Check if this result is already used by any previous pair
                    // Used if result_temp matches any result[0:current_pair-1]
                    // We also need to ensure no collision with current assignments
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        // Check for collision with previously assigned pairs
                        reg collision;
                        collision = 1'b0;
                        for (j = 0; j < current_pair; j = j + 1) begin
                            if (result[j] == result_temp) begin
                                collision = 1'b1;
                            end
                        end
                        
                        if (!collision) begin
                            // No collision, use this operation
                            if (op_try == OP_ADD) begin
                                op[current_pair] <= OP_ADD;
                            end else if (op_try == OP_SUB) begin
                                op[current_pair] <= OP_SUB;
                            end else begin
                                op[current_pair] <= OP_MUL;
                            end
                            result[current_pair] <= result_temp;
                            
                            // Move to next pair or finish
                            if (current_pair + 4'd1 >= n) begin
                                state <= FINISH;
                            end else begin
                                current_pair <= current_pair + 4'd1;
                                op_try <= OP_ADD;  // Reset op_try for next pair
                                state <= COMPUTE;
                            end
                        end else begin
                            // Collision, try next operation
                            if (op_try == OP_ADD) begin
                                op_try <= OP_SUB;
                                state <= ASSIGN;
                            end else if (op_try == OP_SUB) begin
                                op_try <= OP_MUL;
                                state <= ASSIGN;
                            end else begin
                                // All operations collided for this pair
                                // Need to backtrack
                                state <= BACKTRACK;
                            end
                        end
                    end
                end

                BACKTRACK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES || current_pair == 4'd0) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        // Go back to previous pair and try next operation
                        current_pair <= current_pair - 4'd1;
                        
                        // Get next operation for the previous pair
                        if (op[current_pair] == OP_ADD) begin
                            op_try <= OP_SUB;
                        end else if (op[current_pair] == OP_SUB) begin
                            op_try <= OP_MUL;
                        end else begin
                            // Already tried all, need to backtrack further
                            state <= BACKTRACK;
                        end
                        
                        if (op[current_pair] == OP_MUL) begin
                            // Cannot find solution, need deeper backtrack
                            if (current_pair == 4'd0) begin
                                state <= IMPOSSIBLE;
                            end
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                FINISH: begin
                    valid <= 1'b1;
                    state <= IDLE;
                end

                IMPOSSIBLE: begin
                    impossible <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule