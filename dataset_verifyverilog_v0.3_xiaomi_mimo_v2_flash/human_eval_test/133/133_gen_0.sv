module sum_squares(
    input clk,
    input rst_n,
    input start,
    input [7:0] numbers [0:7],
    output reg [31:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [3:0] counter;          // 0 to 8
    reg [31:0] accumulator;
    reg [15:0] square_temp;     // For 8-bit squaring
    
    // State transition and computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter <= 4'd0;
            accumulator <= 32'd0;
            square_temp <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    accumulator <= 32'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Compute square of current element
                    square_temp <= numbers[counter] * numbers[counter];
                    
                    // Add square to accumulator
                    accumulator <= accumulator + {16'd0, square_temp};
                    
                    // Increment counter
                    counter <= counter + 4'd1;
                    
                    // Transition to DONE when all 8 elements processed
                    if (counter == 4'd7) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule