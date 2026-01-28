module find_unique_element (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index, next_index;
    reg [15:0] accumulator, next_accumulator;
    reg [15:0] result_reg, next_result_reg;
    reg done_reg, next_done_reg;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            accumulator <= 16'd0;
            result_reg <= 16'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            accumulator <= next_accumulator;
            result_reg <= next_result_reg;
            done_reg <= next_done_reg;
        end
    end
    
    // Output assignments
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end
    
    // Next state and logic
    always @(*) begin
        // Default values
        next_state = state;
        next_index = index;
        next_accumulator = accumulator;
        next_result_reg = result_reg;
        next_done_reg = 1'b0;
        
        case (state)
            IDLE: begin
                next_index = 4'd0;
                next_accumulator = 16'd0;
                next_result_reg = 16'd0;
                next_done_reg = 1'b0;
                
                if (start) begin
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                // XOR current array element with accumulator
                next_accumulator = accumulator ^ {8'd0, arr[index]};
                next_index = index + 4'd1;
                
                // Check if we've processed all elements
                if (index >= (len - 4'd1)) begin
                    next_state = COMPLETE;
                    next_result_reg = next_accumulator;
                end
            end
            
            COMPLETE: begin
                next_done_reg = 1'b1;
                next_state = IDLE;
                next_index = 4'd0;
                next_accumulator = 16'd0;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule