module game_probability (
  input clk,
  input rst_n,
  input start,
  input valid,
  input [31:0] p_i,
  output reg [31:0] result,
  output reg done,
  output reg ready
);

  // Constants
  localparam IDLE = 3'b000;
  localparam COLLECT_PROBABILITIES = 3'b001;
  localparam COMPUTE = 3'b010;
  localparam DONE = 3'b100;

  localparam N = 3;
  localparam M = 2;
  localparam MAX_ROUNDS = 4;
  localparam Q16_16_ONE = 32'h00010000;

  // State
  reg [2:0] state = IDLE;
  reg [31:0] dp [0:5][0:5];
  reg [31:0] p [0:MAX_ROUNDS-1];
  reg [4:0] round_count = 0;
  reg [4:0] compute_count = 0;
  reg [4:0] a, c, r;

  // Q16.16 multiplication
  function [31:0] q16_16_mult;
    input [31:0] a, b;
    q16_16_mult = (a * b) >>> 16;
  endfunction

  // Q16.16 subtraction from 1.0
  function [31:0] q16_16_one_minus;
    input [31:0] a;
    q16_16_one_minus = Q16_16_ONE - a;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      round_count <= 0;
      compute_count <= 0;
      result <= 0;
      done <= 0;
      ready <= 1;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COLLECT_PROBABILITIES;
            round_count <= 0;
            ready <= 0;
          end
        end

        COLLECT_PROBABILITIES: begin
          if (valid) begin
            p[round_count] <= p_i;
            round_count <= round_count + 1;
            if (round_count == MAX_ROUNDS - 1) begin
              state <= COMPUTE;
              compute_count <= 0;
            end
          end
        end

        COMPUTE: begin
          if (compute_count < 100) begin
            compute_count <= compute_count + 1;
            // Initialize base cases
            for (a = 0; a <= N; a = a + 1) begin
              dp[a][0] <= Q16_16_ONE;  // Cora has 0 points
            end
            for (c = 0; c <= M; c = c + 1) begin
              dp[0][c] <= 0;  // Anthony has 0 points
            end

            // Compute backwards from last round
            for (r = MAX_ROUNDS-1; r >= 0; r = r - 1) begin
              for (a = 1; a <= N; a = a + 1) begin
                for (c = 1; c <= M; c = c + 1) begin
                  dp[a][c] <= q16_16_mult(p[r], dp[a][c-1]) + 
                             q16_16_mult(q16_16_one_minus(p[r]), dp[a-1][c]);
                end
              end
            end

            if (compute_count == 99) begin
              result <= dp[N][M];
              state <= DONE;
              done <= 1;
            end
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
            ready <= 1;
          end
        end
      endcase
    end
  end

endmodule