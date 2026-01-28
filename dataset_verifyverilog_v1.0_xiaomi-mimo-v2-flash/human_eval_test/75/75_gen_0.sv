module is_multiply_prime(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    output reg result,
    output reg done
);

    // State declarations for FSM
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    
    // Lookup table for valid products of 3 primes (1-99)
    // Valid products: 8, 12, 18, 27, 30, 42, 45, 50, 63, 70, 75, 98
    // This is a 100-bit LUT where lut[i] = 1 if i is valid
    reg [99:0] lut;
    
    // Initialize LUT
    initial begin
        lut = 100'd0;
        lut[8]  = 1'b1;
        lut[12] = 1'b1;
        lut[18] = 1'b1;
        lut[27] = 1'b1;
        lut[30] = 1'b1;
        lut[42] = 1'b1;
        lut[45] = 1'b1;
        lut[50] = 1'b1;
        lut[63] = 1'b1;
        lut[70] = 1'b1;
        lut[75] = 1'b1;
        lut[98] = 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear done when entering IDLE
                    done <= 1'b0;
                    // Always go to PROCESS on clock edge
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    // Check if input is within valid range (1-99)
                    if (a >= 8'd1 && a <= 8'd99) begin
                        result <= lut[a];
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= FINISH;
                end
                
                FINISH: begin
                    // Return to IDLE to prepare for next start
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule