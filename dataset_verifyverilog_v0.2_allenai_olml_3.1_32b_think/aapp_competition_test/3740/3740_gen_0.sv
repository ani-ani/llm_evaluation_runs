module digit_sum_pairs_counter(
    input clk,
    input rst_n,
    input start,
    input [31:0] S,
    output reg [31:0] result,
    output reg done
);

wire [15:0] s_val;
assign s_val = S >> 16;

localparam IDLE = 3'd0, CALCULATE_LOOP_1 = 3'd1, CALCULATE_LOOP_2 = 3'd2, CALCULATE_LOOP_3 = 3'd3, FINALIZE = 3'd4;

reg [2:0] state;
reg [31:0] result_reg;
reg [7:0] i;
reg [7:0] k;
reg [7:0] d;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_reg <= 32'd0;
        done_reg <= 1'b0;
        i <= 8'd0;
        k <= 8'd0;
        d <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CALCULATE_LOOP_1;
                    result_reg <= 32'd0;
                    i <= 8'd1;
                end
            end
            CALCULATE_LOOP_1: begin
                if (i < 10) begin
                    if (s_val > 16'd0) begin
                        result_reg <= result_reg + 1;
                    end
                    i <= i + 1;
                end else begin
                    state <= CALCULATE_LOOP_2;
                    i <= 8'd0;
                    k <= 8'd9;
                end
            end
            CALCULATE_LOOP_2: begin
                if (k < 129) begin
                    result_reg <= result_reg + k;
                    k <= k + 1;
                end else begin
                    state <= CALCULATE_LOOP_3;
                    k <= 8'd0;
                    d <= 8'd1;
                end
            end
            CALCULATE_LOOP_3: begin
                if (d <= 128) begin
                    if (d != 8'd0 && S % d == 0) begin
                        result_reg <= result_reg + d;
                    end
                    d <= d + 1;
                end else begin
                    state <= FINALIZE;
                    d <= 8'd0;
                end
            end
            FINALIZE: begin
                result_reg <= result_reg % 1000000007;
                done_reg <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule