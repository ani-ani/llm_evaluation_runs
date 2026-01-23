module best_friends (input [3:0] n, input start, input clk, input rst_n, output reg [31:0] result, output reg done);
localparam IDLE = 2'b00, CALC_POW5 = 2'b01, CALC_FINAL = 2'b10, DONE = 2'b11;
reg [31:0] p5, comp, temp;
reg [3:0] count;
reg [2:0] state;
localparam MOD = 998244353;
always_ff @(posedge clk) begin
    if (!rst_n) begin
        p5 <= 32'b0;
        count <= 4'b0;
        state <= IDLE;
        result <= 32'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    count <= 4'b0;
                    p5 <= 32'b1;
                    state <= CALC_POW5;
                end
            end
            CALC_POW5: begin
                if (count < n) begin
                    count <= count + 1;
                    p5 <= (p5 * 5) % MOD;
                end else begin
                    state <= CALC_FINAL;
                end
            end
            CALC_FINAL: begin
                if (n[0] == 1) begin
                    comp <= (1000 * p5) % MOD;
                end else begin
                    temp <= p5 / 5;
                    comp <= (1000 * p5 - 4 * temp) % MOD;
                end
                result <= (comp * (comp - 1)) / 2 % MOD;
                state <= DONE;
            end
        endcase
    end
end
assign done = (state == DONE);
endmodule