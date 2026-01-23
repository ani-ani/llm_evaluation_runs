module coprime_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] d,
    output reg [7:0] result,
    output reg done
);

reg [2:0] state_reg;
localparam STATE_IDLE = 3'd0, STATE_CALC_GCD = 3'd1, STATE_CHECK_GCD = 3'd2, STATE_NEXT_PAIR = 3'd3, STATE_DONE = 3'd4;
reg [7:0] x_reg, y_reg;
reg [7:0] a_reg, b_reg, c_reg, d_reg;
reg [7:0] result_reg;
reg done_reg;

reg [7:0] gcd_a, gcd_b;
reg gcd_state;
localparam GCD_COMPUTE = 1'b0, GCD_DONE = 1'b1;
reg initialized_gcd;

always @(posedge clk) begin
    if (!rst_n) begin
        gcd_a <= 8'd0;
        gcd_b <= 8'd0;
        gcd_state <= GCD_COMPUTE;
        initialized_gcd <= 1'b0;
    end else begin
        case (gcd_state)
            GCD_COMPUTE: begin
                if (gcd_b == 8'd0) begin
                    gcd_state <= GCD_DONE;
                end else begin
                    gcd_a <= gcd_b;
                    gcd_b <= gcd_a % gcd_b;
                end
            end
            GCD_DONE: begin
                // do nothing
            end
        endcase
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= STATE_IDLE;
        x_reg <= 8'd0;
        y_reg <= 8'd0;
        a_reg <= 8'd0;
        b_reg <= 8'd0;
        c_reg <= 8'd0;
        d_reg <= 8'd0;
        result_reg <= 8'd0;
        done_reg <= 1'b0;
        gcd_a <= 8'd0;
        gcd_b <= 8'd0;
        gcd_state <= GCD_COMPUTE;
        initialized_gcd <= 1'b0;
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                if (start) begin
                    a_reg <= a;
                    b_reg <= b;
                    c_reg <= c;
                    d_reg <= d;
                    x_reg <= a_reg;
                    y_reg <= c_reg;
                    state_reg <= STATE_CALC_GCD;
                end
            end
            STATE_CALC_GCD: begin
                if (!initialized_gcd) begin
                    gcd_a <= x_reg;
                    gcd_b <= y_reg;
                    gcd_state <= GCD_COMPUTE;
                    initialized_gcd <= 1'b1;
                end
                if (gcd_state == GCD_DONE) begin
                    state_reg <= STATE_CHECK_GCD;
                    initialized_gcd <= 1'b0;
                end
            end
            STATE_CHECK_GCD: begin
                if (gcd_a == 1) begin
                    result_reg <= result_reg + 1;
                end
                state_reg <= STATE_NEXT_PAIR;
            end
            STATE_NEXT_PAIR: begin
                if (y_reg < d_reg) begin
                    y_reg <= y_reg + 1;
                    state_reg <= STATE_CALC_GCD;
                end else begin
                    y_reg <= c_reg;
                    if (x_reg < b_reg) begin
                        x_reg <= x_reg + 1;
                        state_reg <= STATE_CALC_GCD;
                    end else begin
                        state_reg <= STATE_DONE;
                    end
                end
            end
            STATE_DONE: begin
                done_reg <= 1'b1;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule