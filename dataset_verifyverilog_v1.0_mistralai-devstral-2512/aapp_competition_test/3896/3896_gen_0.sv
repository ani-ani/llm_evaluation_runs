module dance_complexity_calc(
    input clk,
    input rst_n,
    input start,
    input [7:0] x_mask,
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] SHIFT = 5'd7;

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [15:0] product;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            product <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC;
                    end
                end
                CALC: begin
                    product <= x_mask << SHIFT;
                    result <= product;
                    state <= DONE_STATE;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule