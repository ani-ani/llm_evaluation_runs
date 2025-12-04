module odd_even_sum (
    input clk,
    input rst_n,
    input start,
    input [15:0] data,
    input [3:0] index,
    input [3:0] count,
    output reg [15:0] sum_result,
    output reg done
);
    
    // State definitions
    localparam IDLE = 2'b00;
    localparam COUNTING = 2'b01;
    localparam WAIT = 2'b10;
    
    // State and control signals
    reg [1:0] state;
    reg [3:0] counter;  // 0 to 15, but we only need 0-7 for 8 elements
    reg [15:0] accumulator;
    reg wait_counter;   // 0 or 1
    
    // State machine
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            accumulator <= 16'd0;
            wait_counter <= 1'b0;
            sum_result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COUNTING;
                        counter <= 4'd0;
                        accumulator <= 16'd0;
                        wait_counter <= 1'b0;
                        done <= 1'b0;
                    end
                end
                
                COUNTING: begin
                    // Check conditions: even index and odd data
                    if (index[0] == 1'b0 && data[0] == 1'b1) begin
                        accumulator <= accumulator + data;
                    end
                    
                    counter <= counter + 1;
                    
                    // Check if we've processed all elements
                    if (counter == (count - 1)) begin
                        state <= WAIT;
                        wait_counter <= 1'b0;
                    end
                end
                
                WAIT: begin
                    if (wait_counter == 1'b0) begin
                        wait_counter <= 1'b1;
                    end else begin
                        // Second cycle of wait state
                        sum_result <= accumulator;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule