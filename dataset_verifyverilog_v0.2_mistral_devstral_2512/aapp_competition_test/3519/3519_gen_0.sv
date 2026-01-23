module memory_game_expected_turns (
  input clk,
  input rst_n,
  input start,
  input [4:0] N,
  output reg [31:0] result,
  output reg done
);

  // State machine states
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD_U = 3'b001;
  localparam [2:0] ITERATE_STATES = 3'b010;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [4:0] u = 0; // Current unmatched pairs
  reg [4:0] v = 0; // Current known single cards
  reg [31:0] E [0:16][0:32]; // DP table in Q16.16

  // Precomputed division lookup tables (Q16.16)
  reg [31:0] inv_u [1:16];
  reg [31:0] inv_2u_minus_1 [1:16];

  // Initialize lookup tables
  integer i;
  initial begin
    for (i = 1; i <= 16; i = i + 1) begin
      inv_u[i] = (1 << 16) / i;
      inv_2u_minus_1[i] = (1 << 16) / (2*i - 1);
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      u <= 0;
      v <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_U;
            u <= N;
            v <= 0;
            done <= 0;
          end
        end

        LOAD_U: begin
          if (u == 0) begin
            state <= DONE;
            result <= 0;
            done <= 1;
          end else begin
            state <= ITERATE_STATES;
          end
        end

        ITERATE_STATES: begin
          if (v == 0) begin
            // Base case: E(u, 0) = 1 + E(u, 2)
            E[u][v] <= 32'h10000 + E[u][v+2];
            v <= v + 2;
          end else if (v > 0) begin
            // Case 1: Known pair exists (prob 1/u)
            reg [31:0] term1 = (1 << 16) + E[u-1][v-1];
            // Case 2: No known pair (prob (u-1)/u)
            reg [31:0] term2;
            if (v < 2*u) begin
              // Match found (prob 1/(2u-1))
              term2 = (1 << 16) + E[u-1][v-1];
            end else begin
              // No match (prob (2u-2)/(2u-1))
              term2 = (1 << 16) + E[u][v+2];
            end
            // Combine terms with probabilities
            E[u][v] <= (term1 * inv_u[u] + term2 * ((u-1) * inv_u[u])) >> 16;
            v <= v + 1;
          end
          // Move to next state
          if (v >= 2*u) begin
            u <= u - 1;
            v <= 0;
            if (u == 0) begin
              state <= DONE;
              result <= E[N][0];
              done <= 1;
            end
          end
        end

        DONE: begin
          if (start) begin
            state <= LOAD_U;
            u <= N;
            v <= 0;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule