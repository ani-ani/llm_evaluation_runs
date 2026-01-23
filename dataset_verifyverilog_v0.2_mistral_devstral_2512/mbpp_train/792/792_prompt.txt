module count_list(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,  // One element from current sub-array
    input valid_in,        // Data valid signal
    input done_in,         // End of current sub-array
    output reg [3:0] result,  // Count of sub-arrays processed
    output reg done         // Computation complete
);

    // This module counts the number of sub-arrays (lists) in a 2D array.
    // Input is streamed in: valid_in pulses high for each element, done_in pulses high at end of each sub-array.
    // We process up to 8 sub-arrays, each with up to 4 elements.
    
    parameter MAX_LISTS = 4'd8;
    
    reg [3:0] count;
    reg [2:0] state;
    
    // States
    localparam IDLE = 3'b000;
    localparam READING = 3'b001;
    localparam DONE_STATE = 3'b010;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            count <= 4'd0;
            done <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        count <= 4'd0;
                        result <= 4'd0;
                        done <= 1'b0;
                        state <= READING;
                    end
                end
                
                READING: begin
                    if (done_in) begin
                        // End of a sub-array, increment count
                        count <= count + 1'b1;
                        result <= count + 1'b1;
                        // Check if we've processed 8 sub-arrays
                        if (count + 1'b1 >= MAX_LISTS) begin
                            state <= DONE_STATE;
                            done <= 1'b1;
                        end
                    end
                    // Stop if invalid (end of input)
                    if (!valid_in && !done_in && count > 0) begin
                        state <= DONE_STATE;
                        done <= 1'b1;
                    end
                end
                
                DONE_STATE: begin
                    // Wait for reset or start
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule