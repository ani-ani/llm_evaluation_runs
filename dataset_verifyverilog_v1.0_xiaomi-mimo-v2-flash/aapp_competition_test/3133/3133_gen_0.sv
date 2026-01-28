module alice_bob_pisa (
    input clk,
    input rst_n,
    input start,
    input [3:0] alice_start,
    input [3:0] bob_start,
    input [3:0] left_0, left_1, left_2, left_3,
    input [3:0] left_4, left_5, left_6, left_7,
    input [3:0] left_8, left_9, left_10, left_11,
    input [3:0] left_12, left_13, left_14, left_15,
    input [3:0] right_0, right_1, right_2, right_3,
    input [3:0] right_4, right_5, right_6, right_7,
    input [3:0] right_8, right_9, right_10, right_11,
    input [3:0] right_12, right_13, right_14, right_15,
    input tower_0, tower_1, tower_2, tower_3,
    input tower_4, tower_5, tower_6, tower_7,
    input tower_8, tower_9, tower_10, tower_11,
    input tower_12, tower_13, tower_14, tower_15,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state, next_state;
    reg [7:0] step_count, next_step_count;
    reg [3:0] alice_node, next_alice_node;
    reg [3:0] bob_node, next_bob_node;
    reg [15:0] result_reg, next_result;
    reg done_reg, next_done;
    reg found_flag, next_found_flag;

    // Combinational logic for next state and outputs
    always @(*) begin
        // Defaults
        next_state = state;
        next_step_count = step_count;
        next_alice_node = alice_node;
        next_bob_node = bob_node;
        next_result = result_reg;
        next_done = 1'b0;
        next_found_flag = found_flag;

        // Multiplexed node values and tower visibility
        reg alice_tower_vis;
        reg bob_tower_vis;
        reg [3:0] alice_left_node;
        reg [3:0] alice_right_node;
        reg [3:0] bob_left_node;
        reg [3:0] bob_right_node;

        // Default tower visibility lookup
        alice_tower_vis = 1'b0;
        bob_tower_vis = 1'b0;
        case (alice_node)
            4'd0: alice_tower_vis = tower_0;
            4'd1: alice_tower_vis = tower_1;
            4'd2: alice_tower_vis = tower_2;
            4'd3: alice_tower_vis = tower_3;
            4'd4: alice_tower_vis = tower_4;
            4'd5: alice_tower_vis = tower_5;
            4'd6: alice_tower_vis = tower_6;
            4'd7: alice_tower_vis = tower_7;
            4'd8: alice_tower_vis = tower_8;
            4'd9: alice_tower_vis = tower_9;
            4'd10: alice_tower_vis = tower_10;
            4'd11: alice_tower_vis = tower_11;
            4'd12: alice_tower_vis = tower_12;
            4'd13: alice_tower_vis = tower_13;
            4'd14: alice_tower_vis = tower_14;
            4'd15: alice_tower_vis = tower_15;
            default: alice_tower_vis = 1'b0;
        endcase

        case (bob_node)
            4'd0: bob_tower_vis = tower_0;
            4'd1: bob_tower_vis = tower_1;
            4'd2: bob_tower_vis = tower_2;
            4'd3: bob_tower_vis = tower_3;
            4'd4: bob_tower_vis = tower_4;
            4'd5: bob_tower_vis = tower_5;
            4'd6: bob_tower_vis = tower_6;
            4'd7: bob_tower_vis = tower_7;
            4'd8: bob_tower_vis = tower_8;
            4'd9: bob_tower_vis = tower_9;
            4'd10: bob_tower_vis = tower_10;
            4'd11: bob_tower_vis = tower_11;
            4'd12: bob_tower_vis = tower_12;
            4'd13: bob_tower_vis = tower_13;
            4'd14: bob_tower_vis = tower_14;
            4'd15: bob_tower_vis = tower_15;
            default: bob_tower_vis = 1'b0;
        endcase

        // Default transition lookup
        alice_left_node = 4'd0;
        alice_right_node = 4'd0;
        bob_left_node = 4'd0;
        bob_right_node = 4'd0;

        case (alice_node)
            4'd0: begin alice_left_node = left_0; alice_right_node = right_0; end
            4'd1: begin alice_left_node = left_1; alice_right_node = right_1; end
            4'd2: begin alice_left_node = left_2; alice_right_node = right_2; end
            4'd3: begin alice_left_node = left_3; alice_right_node = right_3; end
            4'd4: begin alice_left_node = left_4; alice_right_node = right_4; end
            4'd5: begin alice_left_node = left_5; alice_right_node = right_5; end
            4'd6: begin alice_left_node = left_6; alice_right_node = right_6; end
            4'd7: begin alice_left_node = left_7; alice_right_node = right_7; end
            4'd8: begin alice_left_node = left_8; alice_right_node = right_8; end
            4'd9: begin alice_left_node = left_9; alice_right_node = right_9; end
            4'd10: begin alice_left_node = left_10; alice_right_node = right_10; end
            4'd11: begin alice_left_node = left_11; alice_right_node = right_11; end
            4'd12: begin alice_left_node = left_12; alice_right_node = right_12; end
            4'd13: begin alice_left_node = left_13; alice_right_node = right_13; end
            4'd14: begin alice_left_node = left_14; alice_right_node = right_14; end
            4'd15: begin alice_left_node = left_15; alice_right_node = right_15; end
            default: begin alice_left_node = 4'd0; alice_right_node = 4'd0; end
        endcase

        case (bob_node)
            4'd0: begin bob_left_node = left_0; bob_right_node = right_0; end
            4'd1: begin bob_left_node = left_1; bob_right_node = right_1; end
            4'd2: begin bob_left_node = left_2; bob_right_node = right_2; end
            4'd3: begin bob_left_node = left_3; bob_right_node = right_3; end
            4'd4: begin bob_left_node = left_4; bob_right_node = right_4; end
            4'd5: begin bob_left_node = left_5; bob_right_node = right_5; end
            4'd6: begin bob_left_node = left_6; bob_right_node = right_6; end
            4'd7: begin bob_left_node = left_7; bob_right_node = right_7; end
            4'd8: begin bob_left_node = left_8; bob_right_node = right_8; end
            4'd9: begin bob_left_node = left_9; bob_right_node = right_9; end
            4'd10: begin bob_left_node = left_10; bob_right_node = right_10; end
            4'd11: begin bob_left_node = left_11; bob_right_node = right_11; end
            4'd12: begin bob_left_node = left_12; bob_right_node = right_12; end
            4'd13: begin bob_left_node = left_13; bob_right_node = right_13; end
            4'd14: begin bob_left_node = left_14; bob_right_node = right_14; end
            4'd15: begin bob_left_node = left_15; bob_right_node = right_15; end
            default: begin bob_left_node = 4'd0; bob_right_node = 4'd0; end
        endcase

        case (state)
            IDLE: begin
                done_reg = 1'b0;
                if (start) begin
                    next_state = SEARCH;
                    next_step_count = 8'd0;
                    next_alice_node = alice_start;
                    next_bob_node = bob_start;
                    next_found_flag = 1'b0;
                    next_result = 16'd0;
                end
            end

            SEARCH: begin
                // Check for match at current step (step 0 is starting position)
                if ((alice_tower_vis != bob_tower_vis) && !found_flag) begin
                    next_found_flag = 1'b1;
                    next_result = {8'd1, step_count};
                    next_state = DONE;
                end else if (step_count == 8'd255) begin
                    // Max steps reached, no match found
                    next_found_flag = 1'b1;
                    next_result = 16'hFFFF;
                    next_state = DONE;
                end else begin
                    // Move to next step
                    next_step_count = step_count + 8'd1;
                    // Alice moves left (alternating: 0=left, 1=right, 2=left...)
                    if (step_count[0] == 1'b0) begin
                        next_alice_node = alice_left_node;
                    end else begin
                        next_alice_node = alice_right_node;
                    end
                    // Bob moves right (alternating: 0=right, 1=left, 2=right...)
                    if (step_count[0] == 1'b0) begin
                        next_bob_node = bob_right_node;
                    end else begin
                        next_bob_node = bob_left_node;
                    end
                end
            end

            DONE: begin
                done_reg = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_count <= 8'd0;
            alice_node <= 4'd0;
            bob_node <= 4'd0;
            result_reg <= 16'd0;
            done_reg <= 1'b0;
            found_flag <= 1'b0;
        end else begin
            state <= next_state;
            step_count <= next_step_count;
            alice_node <= next_alice_node;
            bob_node <= next_bob_node;
            result_reg <= next_result;
            done_reg <= next_done;
            found_flag <= next_found_flag;
        end
    end

    // Assign outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            result <= result_reg;
            done <= done_reg;
        end
    end

endmodule