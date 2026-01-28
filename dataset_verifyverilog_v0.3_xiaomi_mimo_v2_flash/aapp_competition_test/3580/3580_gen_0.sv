module find_longest_subsequence (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [2:0] start_index,
    input [7:0] b0, b1, b2, b3,
    input [2:0] m,
    output reg [3:0] length,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COMPUTE = 2'b01;
    localparam [1:0] FINISH = 2'b10;
    
    reg [1:0] state, next_state;
    reg [2:0] current_index;
    reg [3:0] count;
    wire [7:0] current_element;
    wire element_in_set;
    
    // Mux to get current element based on index
    assign current_element = (
        (current_index == 3'd0) ? arr_0 :
        (current_index == 3'd1) ? arr_1 :
        (current_index == 3'd2) ? arr_2 :
        (current_index == 3'd3) ? arr_3 :
        (current_index == 3'd4) ? arr_4 :
        (current_index == 3'd5) ? arr_5 :
        (current_index == 3'd6) ? arr_6 :
        arr_7
    );
    
    // Check if current element is in set B
    assign element_in_set = (
        (m > 3'd0 && current_element == b0) ||
        (m > 3'd1 && current_element == b1) ||
        (m > 3'd2 && current_element == b2) ||
        (m > 3'd3 && current_element == b3)
    );
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE;
                else next_state = IDLE;
            end
            COMPUTE: begin
                if (!element_in_set || current_index == 3'd7) 
                    next_state = FINISH;
                else 
                    next_state = COMPUTE;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            length <= 4'd0;
            done <= 1'b0;
            current_index <= 3'd0;
            count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_index <= start_index;
                        count <= 4'd0;
                    end
                end
                COMPUTE: begin
                    if (element_in_set) begin
                        count <= count + 1'b1;
                        if (current_index < 3'd7)
                            current_index <= current_index + 1'b1;
                    end
                end
                FINISH: begin
                    length <= count;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule