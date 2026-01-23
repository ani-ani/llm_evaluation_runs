module find_first_occurrence (
    input clk,
    input rst_n,
    input start,
    input [3:0] target,
    input [7:0] array_element_0,
    input [7:0] array_element_1,
    input [7:0] array_element_2,
    input [7:0] array_element_3,
    input [7:0] array_element_4,
    input [7:0] array_element_5,
    input [7:0] array_element_6,
    input [7:0] array_element_7,
    output reg [3:0] result,
    output reg done,
    output reg found
);

    // State encoding
    localparam IDLE    = 3'b000;
    localparam SETUP   = 3'b001;
    localparam COMPARE = 3'b010;
    localparam UPDATE  = 3'b011;
    localparam DONE    = 3'b100;

    // Registers for state and data
    reg [2:0] current_state, next_state;
    reg [3:0] left, next_left;
    reg [3:0] right, next_right;
    reg [3:0] result_reg, next_result;
    reg found_reg, next_found;
    reg [2:0] iteration_count, next_iteration_count;

    // Intermediate signals
    wire [3:0] mid;
    reg [7:0] current_element;

    // Assign outputs from registers
    always @(*) begin
        result = result_reg;
        found = found_reg;
    end

    // Mid calculation (combinational)
    assign mid = (left + right) >> 1;

    // Array lookup logic (combinational)
    always @(*) begin
        case (mid)
            4'd0: current_element = array_element_0;
            4'd1: current_element = array_element_1;
            4'd2: current_element = array_element_2;
            4'd3: current_element = array_element_3;
            4'd4: current_element = array_element_4;
            4'd5: current_element = array_element_5;
            4'd6: current_element = array_element_6;
            4'd7: current_element = array_element_7;
            default: current_element = 8'hXX;
        endcase
    end

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            left <= 4'b0;
            right <= 4'b0;
            result_reg <= 4'd15;
            found_reg <= 1'b0;
            iteration_count <= 3'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            left <= next_left;
            right <= next_right;
            result_reg <= next_result;
            found_reg <= next_found;
            iteration_count <= next_iteration_count;
            
            // Done signal is asserted only in DONE state
            // It needs to be high for one cycle and then cleared or kept high
            // Based on spec: "Set done=1, keep result available"
            // Usually done is high during the state, and goes low when start is asserted again.
            if (next_state == DONE)
                done <= 1'b1;
            else if (next_state == IDLE)
                done <= 1'b0;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_left = left;
        next_right = right;
        next_result = result_reg;
        next_found = found_reg;
        next_iteration_count = iteration_count;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end
            end

            SETUP: begin
                next_left = 4'd0;
                next_right = 4'd7;
                next_result = 4'd15;
                next_found = 1'b0;
                next_iteration_count = 3'd0;
                next_state = COMPARE;
            end

            COMPARE: begin
                // Check termination condition: left <= right AND max iterations not exceeded
                if (left <= right && iteration_count < 3'd4) begin
                    // Read and compare is done via combinational logic (current_element)
                    // Wait one cycle effectively for state transition to UPDATE
                    next_state = UPDATE;
                end else begin
                    next_state = DONE;
                end
            end

            UPDATE: begin
                next_iteration_count = iteration_count + 1'b1;
                
                if (target == current_element) begin
                    // Found a match, but check for earlier ones
                    next_result = mid;
                    next_found = 1'b1;
                    next_right = mid - 1'b1;
                    next_state = COMPARE;
                end else if (target < current_element) begin
                    next_right = mid - 1'b1;
                    next_state = COMPARE;
                end else begin // target > current_element
                    next_left = mid + 1'b1;
                    next_state = COMPARE;
                end
            end

            DONE: begin
                // Stay in DONE until start is asserted again (which goes to SETUP via IDLE)
                if (start) begin
                    next_state = SETUP;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule