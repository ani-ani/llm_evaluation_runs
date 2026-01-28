module SentinelCheck (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] index, next_index;
    reg next_result;
    reg next_done;
    reg sentinel_found;
    reg [7:0] current_element;
    
    // Maximum 8 elements, so max 8 cycles + 2 overhead = 10 cycles max
    localparam [3:0] MAX_LEN = 4'd8;

    // Combinational logic for element selection and comparison
    always @(*) begin
        case (index)
            4'd0: current_element = arr_0;
            4'd1: current_element = arr_1;
            4'd2: current_element = arr_2;
            4'd3: current_element = arr_3;
            4'd4: current_element = arr_4;
            4'd5: current_element = arr_5;
            4'd6: current_element = arr_6;
            4'd7: current_element = arr_7;
            default: current_element = 8'd0;
        endcase
        
        // Check if current element is 0xFF (sentinel)
        sentinel_found = (current_element == 8'hFF);
    end

    // State transition logic
    always @(*) begin
        // Default values
        next_state = state;
        next_index = index;
        next_result = result;
        next_done = 1'b0;
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_index = 4'd0;
                next_result = 1'b0;
                if (start) begin
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                // Check if we've processed all elements
                if (index >= len || index >= MAX_LEN) begin
                    next_state = DONE;
                end else begin
                    // Check current element
                    if (sentinel_found) begin
                        next_result = 1'b1;
                    end
                    // Continue to next element
                    next_index = index + 4'd1;
                end
            end
            
            DONE: begin
                next_done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_index = 4'd0;
                next_result = 1'b0;
                next_done = 1'b0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule