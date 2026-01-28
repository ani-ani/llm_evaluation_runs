module sum_of_squares(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] UPDATE  = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [15:0] accumulator;
    reg [7:0] current_element;
    reg [15:0] square;
    reg [7:0] abs_element;
    reg is_positive;
    reg is_odd;
    reg [7:0] i;
    reg [15:0] temp_product;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            accumulator <= 16'd0;
            current_element <= 8'd0;
            square <= 16'd0;
            abs_element <= 8'd0;
            is_positive <= 1'b0;
            is_odd <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PROCESS;
                        index <= 4'd0;
                        accumulator <= 16'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    // Read current element
                    current_element <= arr[index];
                    
                    // Check if positive (>=1) and odd
                    is_positive <= (current_element[7] == 1'b0) && (current_element != 8'd0);
                    is_odd <= (current_element[0] == 1'b1);
                    
                    // Get absolute value (since we checked positive)
                    abs_element <= current_element;
                    
                    next_state <= UPDATE;
                end
                
                UPDATE: begin
                    if (is_positive && is_odd) begin
                        // Compute square using sequential adder
                        temp_product <= 16'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (abs_element[i]) begin
                                temp_product <= temp_product + ({8'd0, abs_element} << i);
                            end
                        end
                        square <= temp_product;
                        
                        // Add to accumulator
                        accumulator <= accumulator + square;
                    end
                    
                    // Increment index
                    if (index == len) begin
                        next_state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                        next_state <= PROCESS;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
endmodule