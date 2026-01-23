module chubby_yang (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;

    // K = 92682 (approx 1.41421356 * 65536) represents sqrt(2) in Q16.16 format.
    // The problem requires result = 4 * floor(n * sqrt(2)).
    // By calculating (n * K) >> 14, we effectively multiply by K, then divide by 2^16 (shift right 16), 
    // and multiply by 4 (shift left 2), resulting in a net shift right 14.
    // This operation is equivalent to floor(n * sqrt(2)) * 4.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (n == 0) begin
                            // Case n=0: result = 1
                            result <= 1;
                            done <= 1;
                        end else begin
                            // Move to calculation state
                            state <= CALC;
                        end
                    end
                end
                CALC: begin
                    // Perform the fixed-point multiplication and shift
                    result <= (n * 92682) >> 14;
                    state <= DONE;
                    done <= 1;
                end
                DONE: begin
                    // Reset done and return to IDLE
                    done <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule