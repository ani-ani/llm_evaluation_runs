module beautiful_sequence (
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    input [15:0] c,
    input [15:0] d,
    output reg result_valid,
    output reg [7:0] result,
    output reg [15:0] result_index,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] VALIDATE     = 3'd1;
    localparam [2:0] CHECK_START  = 3'd2;
    localparam [2:0] OUTPUT_SEQ   = 3'd3;
    localparam [2:0] DONE_STATE   = 3'd4;
    localparam [2:0] IMPOSSIBLE   = 3'd5;

    // Node positions for output
    localparam [7:0] NODE_0 = 8'd0;
    localparam [7:0] NODE_1 = 8'd1;
    localparam [7:0] NODE_2 = 8'd2;
    localparam [7:0] NODE_3 = 8'd3;

    reg [2:0] state, next_state;
    reg [15:0] count_0, count_1, count_2, count_3;
    reg [15:0] curr_index;
    reg [7:0] current_node;
    reg [7:0] prev_node;
    reg [15:0] total_count;
    reg [15:0] cycle_counter;
    localparam [15:0] MAX_CYCLE = 16'd100050;

    // Internal validation signals
    reg [16:0] abs_diff; // 17-bit for intermediate calculation
    reg [15:0] abs_val;
    reg validation_pass;
    reg can_start;

    // Helper for absolute value (no built-in abs in basic Verilog)
    function [15:0] abs_val_func;
        input [15:0] val;
        begin
            if (val[15])
                abs_val_func = (~val) + 16'd1;
            else
                abs_val_func = val;
        end
    endfunction

    // Initialize all regs on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count_0 <= 16'd0;
            count_1 <= 16'd0;
            count_2 <= 16'd0;
            count_3 <= 16'd0;
            curr_index <= 16'd0;
            current_node <= 8'd0;
            prev_node <= 8'd0;
            total_count <= 16'd0;
            cycle_counter <= 16'd0;
            result_valid <= 1'b0;
            result <= 8'd0;
            result_index <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            abs_diff <= 17'd0;
            abs_val <= 16'd0;
            validation_pass <= 1'b0;
            can_start <= 1'b0;
        end else begin
            state <= next_state;
            
            // Clear pulse signals
            done <= 1'b0;
            impossible <= 1'b0;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    result_index <= 16'd0;
                    curr_index <= 16'd0;
                    cycle_counter <= 16'd0;
                    validation_pass <= 1'b0;
                    can_start <= 1'b0;
                    if (start) begin
                        count_0 <= a;
                        count_1 <= b;
                        count_2 <= c;
                        count_3 <= d;
                        total_count <= a + b + c + d;
                    end
                end

                VALIDATE: begin
                    // Calculate: (a - b + c - d)
                    // Check if abs(value) <= 2
                    abs_diff <= (a + c) - (b + d);
                    if ((a + c) >= (b + d))
                        abs_val <= (a + c) - (b + d);
                    else
                        abs_val <= (b + d) - (a + c);
                    
                    if (total_count == 16'd0) begin
                        validation_pass <= 1'b1;
                        can_start <= 1'b0;
                    end else if (abs_val <= 16'd2) begin
                        validation_pass <= 1'b1;
                        can_start <= 1'b1;
                    end else begin
                        validation_pass <= 1'b0;
                        can_start <= 1'b0;
                    end
                end

                CHECK_START: begin
                    // Determine starting node
                    if (count_0 > 16'd0) begin
                        current_node <= NODE_0;
                        prev_node <= NODE_0;
                    end else if (count_3 > 16'd0) begin
                        current_node <= NODE_3;
                        prev_node <= NODE_3;
                    end else if (count_1 > 16'd0) begin
                        current_node <= NODE_1;
                        prev_node <= NODE_1;
                    end else if (count_2 > 16'd0) begin
                        current_node <= NODE_2;
                        prev_node <= NODE_2;
                    end
                    curr_index <= 16'd0;
                    cycle_counter <= 16'd0;
                end

                OUTPUT_SEQ: begin
                    cycle_counter <= cycle_counter + 16'd1;
                    result_valid <= 1'b1;
                    result <= current_node;
                    result_index <= curr_index;
                    
                    // Decrement count for current node
                    case (current_node)
                        NODE_0: count_0 <= count_0 - 16'd1;
                        NODE_1: count_1 <= count_1 - 16'd1;
                        NODE_2: count_2 <= count_2 - 16'd1;
                        NODE_3: count_3 <= count_3 - 16'd1;
                    endcase
                    
                    curr_index <= curr_index + 16'd1;
                    
                    // Determine next node
                    // Greedy logic
                    if (curr_index < total_count - 16'd1) begin
                        if (current_node == NODE_0) begin
                            // From 0, only go to 1
                            prev_node <= current_node;
                            current_node <= NODE_1;
                        end else if (current_node == NODE_3) begin
                            // From 3, only go to 2
                            prev_node <= current_node;
                            current_node <= NODE_2;
                        end else if (current_node == NODE_1) begin
                            // From 1, can go to 0 or 2
                            // Prefer direction with higher adjacent count
                            if (prev_node == NODE_0) begin
                                // Already came from 0, go to 2
                                if (count_2 > 16'd0) begin
                                    prev_node <= current_node;
                                    current_node <= NODE_2;
                                end else begin
                                    // Must go back to 0
                                    prev_node <= current_node;
                                    current_node <= NODE_0;
                                end
                            end else begin
                                // Came from 2, try to go to 0
                                if (count_0 > 16'd0) begin
                                    prev_node <= current_node;
                                    current_node <= NODE_0;
                                end else begin
                                    // Must go back to 2
                                    prev_node <= current_node;
                                    current_node <= NODE_2;
                                end
                            end
                        end else if (current_node == NODE_2) begin
                            // From 2, can go to 1 or 3
                            if (prev_node == NODE_3) begin
                                // Already came from 3, go to 1
                                if (count_1 > 16'd0) begin
                                    prev_node <= current_node;
                                    current_node <= NODE_1;
                                end else begin
                                    // Must go back to 3
                                    prev_node <= current_node;
                                    current_node <= NODE_3;
                                end
                            end else begin
                                // Came from 1, try to go to 3
                                if (count_3 > 16'd0) begin
                                    prev_node <= current_node;
                                    current_node <= NODE_3;
                                end else begin
                                    // Must go back to 1
                                    prev_node <= current_node;
                                    current_node <= NODE_1;
                                end
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    result_valid <= 1'b0;
                    result_index <= 16'd0;
                end

                IMPOSSIBLE: begin
                    result_valid <= 1'b0;
                    result_index <= 16'd0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state; // Default to hold state
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = VALIDATE;
            end
            
            VALIDATE: begin
                if (validation_pass) begin
                    if (can_start)
                        next_state = CHECK_START;
                    else
                        next_state = DONE_STATE; // Empty sequence
                end else begin
                    next_state = IMPOSSIBLE;
                end
            end

            CHECK_START: begin
                if (total_count > 16'd0)
                    next_state = OUTPUT_SEQ;
                else
                    next_state = DONE_STATE;
            end

            OUTPUT_SEQ: begin
                if (cycle_counter >= MAX_CYCLE) begin
                    next_state = IMPOSSIBLE;
                end else if (curr_index >= total_count) begin
                    next_state = DONE_STATE;
                end else begin
                    // Check for dead end during traversal
                    if (current_node == NODE_0 && count_0 == 16'd0 && count_1 == 16'd0)
                        next_state = IMPOSSIBLE;
                    else if (current_node == NODE_3 && count_3 == 16'd0 && count_2 == 16'd0)
                        next_state = IMPOSSIBLE;
                    else if (current_node == NODE_1) begin
                        // Check if stuck at 1
                        if (count_1 == 16'd0) begin
                            if ((prev_node == NODE_0 && count_0 == 16'd0 && count_2 == 16'd0) ||
                                (prev_node == NODE_2 && count_2 == 16'd0 && count_0 == 16'd0))
                                next_state = IMPOSSIBLE;
                        end
                    end else if (current_node == NODE_2) begin
                        // Check if stuck at 2
                        if (count_2 == 16'd0) begin
                            if ((prev_node == NODE_1 && count_1 == 16'd0 && count_3 == 16'd0) ||
                                (prev_node == NODE_3 && count_3 == 16'd0 && count_1 == 16'd0))
                                next_state = IMPOSSIBLE;
                        end
                    end
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            IMPOSSIBLE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule