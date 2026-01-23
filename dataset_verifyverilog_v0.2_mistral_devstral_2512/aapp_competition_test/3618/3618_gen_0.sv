module best_friends (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg done,
  output reg [31:0] result
);

  parameter MOD = 998244353;
  parameter STATE_IDLE = 3'b000;
  parameter STATE_CALC_POW5 = 3'b001;
  parameter STATE_CALC_POW10 = 3'b010;
  parameter STATE_CALC_FINAL = 3'b011;
  parameter STATE_DONE = 3'b100;

  reg [2:0] state = STATE_IDLE;
  reg [31:0] p5 = 1;
  reg [31:0] p10 = 1;
  reg [31:0] comp;
  reg [31:0] inv5 = 400000002; // 5^{-1} mod 998244353
  reg [3:0] cnt = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      done <= 0;
      result <= 0;
      p5 <= 1;
      p10 <= 1;
      cnt <= 0;
    end else if (start) begin
      case (state)
        STATE_IDLE: begin
          state <= STATE_CALC_POW5;
          cnt <= n;
          p5 <= 1;
        end
        STATE_CALC_POW5: begin
          if (cnt > 0) begin
            p5 <= (p5 * 5) % MOD;
            cnt <= cnt - 1;
          end else begin
            state <= STATE_CALC_POW10;
            cnt <= n;
            p10 <= 1;
          end
        end
        STATE_CALC_POW10: begin
          if (cnt > 0) begin
            p10 <= (p10 * 10) % MOD;
            cnt <= cnt - 1;
          end else begin
            state <= STATE_CALC_FINAL;
          end
        end
        STATE_CALC_FINAL: begin
          if (n[0]) begin // n is odd
            comp <= (1000 * p5) % MOD;
          end else begin // n is even
            comp <= (1000 * p5 - 4 * ((p5 * inv5) % MOD)) % MOD;
          end
          result <= (comp * (comp - 1) % MOD * 500000004) % MOD; // 500000004 is inv(2) mod MOD
          state <= STATE_DONE;
        end
        STATE_DONE: begin
          done <= 1;
          state <= STATE_IDLE;
        end
        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule