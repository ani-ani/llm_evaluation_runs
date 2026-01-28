module sum_1_to_n(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [15:0] result,
    output reg done
);

    reg [1:0] state;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate n*(n+1)/2
                    // n is 8-bit, n+1 is 8-bit, product is 16-bit
                    // Division by 2 is a right shift by 1
                    result <= (n_in * (n_in + 8'd1)) >> 1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule