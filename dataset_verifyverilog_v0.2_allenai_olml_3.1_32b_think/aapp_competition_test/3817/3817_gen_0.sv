module wool_sequence_counter (
  input clk,
  input rst_n,
  input start,
  input [31:0] n,
  input [31:0] m,
  output reg [31:0] result,
  output reg done
);

localparam MOD = 1000000009;

reg [31:0] current_result;
reg [31:0] pow_accum;
reg [31:0] exponent_counter;
reg [31:0] loop_counter;
reg [31:0] captured_n;
reg [31:0] captured_m;
reg [1:0] state;

assign result = current_result;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_result <= 1;
        pow_accum <= 0;
        exponent_counter <= 0;
        loop_counter <= 0;
        captured_n <= 0;
        captured_m <= 0;
        state <= 2'd0;
        done <= 0;
    end else begin
        case (state)
            2'd0: begin
                if (start) begin
                    captured_n <= n;
                    captured_m <= m;
                    current_result <= 1;
                    pow_accum <= 1;
                    exponent_counter <= 0;
                    state <= 2'd1;
                end
            end
            2'd1: begin
                if (exponent_counter < captured_m) begin
                    pow_accum <= (pow_accum * 2) % MOD;
                    exponent_counter <= exponent_counter + 1;
                end else begin
                    state <= 2'd2;
                    loop_counter <= 0;
                end
            end
            2'd2: begin
                if (loop_counter < captured_n) begin
                    current_result <= (current_result * ((pow_accum - (loop_counter + 1) + MOD) % MOD)) % MOD;
                    loop_counter <= loop_counter + 1;
                end else begin
                    state <= 3'd3;
                    done <= 1;
                end
            end
            2'd3: begin
                // Stay in DONE
            end
        endcase
    end
endmodule