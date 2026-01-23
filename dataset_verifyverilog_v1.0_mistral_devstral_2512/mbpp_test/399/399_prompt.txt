module bitwise_xor_array (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // Parameters
    parameter ARRAY_SIZE = 8;
    parameter DATA_WIDTH = 8;
    
    // State machine states
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam FINISH = 2'b10;
    
    // State registers
    reg [1:0] state;
    reg [3:0] index;
    
    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            // Clear result array
            for (integer i = 0; i < ARRAY_SIZE; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Perform XOR for current index
                    result[index] <= arr1[index] ^ arr2[index];
                    index <= index + 1;
                    
                    if (index == ARRAY_SIZE - 1) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule