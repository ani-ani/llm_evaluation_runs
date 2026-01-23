module string_generator (
  input clk,
  input rst_n,
  input start,
  input [6:0] N,
  input [7:0] c_AA, c_AB, c_BA, c_BB,
  output reg [29:0] result,
  output reg done
);

  parameter MOD = 1000000007;
  parameter IDLE = 3'b000;
  parameter DECODE = 3'b001;
  parameter ITERATE = 3'b010;
  parameter DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [29:0] fib_prev = 1;
  reg [29:0] fib_curr = 1;
  reg [29:0] pow2_result = 1;
  reg [6:0] counter = 0;
  reg [6:0] max_count = 0;
  reg is_case0 = 0;
  reg is_case1 = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      counter <= 0;
      fib_prev <= 1;
      fib_curr <= 1;
      pow2_result <= 1;
      is_case0 <= 0;
      is_case1 <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= DECODE;
          end
        end
        DECODE: begin
          is_case0 <= (c_AB == 0 && c_AA == 0) || (c_AB == 1 && c_BB == 1);
          is_case1 <= !is_case0 && (c_BA != c_AB);
          max_count <= (N > 3) ? N - 3 : 0;
          state <= ITERATE;
        end
        ITERATE: begin
          if (counter < max_count) begin
            if (is_case1) begin
              pow2_result <= (pow2_result * 2) % MOD;
            end else if (!is_case0) begin
              fib_curr <= (fib_prev + fib_curr) % MOD;
              fib_prev <= (fib_curr - fib_prev + MOD) % MOD;
            end
            counter <= counter + 1;
          end else begin
            if (is_case0) begin
              result <= 1;
            end else if (is_case1) begin
              result <= (N > 3) ? pow2_result : 1;
            end else begin
              result <= (N > 3) ? fib_curr : 1;
            end
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule