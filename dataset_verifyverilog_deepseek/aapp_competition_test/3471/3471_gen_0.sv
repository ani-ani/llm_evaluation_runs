module xorbonacci_queries(
  input clk,
  input rst_n,
  input start,
  input [1:0] K,
  input [7:0] a1, a2, a3, a4,
  input [1:0] Q,
  input [3:0] l1, r1,
  input [3:0] l2, r2,
  input [3:0] l3, r3,
  input [3:0] l4, r4,
  output reg done,
  output reg [7:0] res1,
  output reg [7:0] res2,
  output reg [7:0] res3,
  output reg [7:0] res4
);

  typedef enum logic [1:0] {IDLE, COMPUTE, QUERIES, DONE} state_t;
  state_t current_state, next_state;

  reg [3:0] n_count;
  reg [7:0] x_reg[1:16];
  reg [1:0] K_reg;
  reg [7:0] a1_reg, a2_reg, a3_reg, a4_reg;
  reg [3:0] l1_reg, l2_reg, l3_reg, l4_reg;
  reg [3:0] r1_reg, r2_reg, r3_reg, r4_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      n_count <= '0;
      res1 <= '0;
      res2 <= '0;
      res3 <= '0;
      res4 <= '0;
      for (int i = 1; i <= 16; i++) x_reg[i] <= '0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            K_reg <= K;
            a1_reg <= a1;
            a2_reg <= a2;
            a3_reg <= a3;
            a4_reg <= a4;
            l1_reg <= l1; r1_reg <= r1;
            l2_reg <= l2; r2_reg <= r2;
            l3_reg <= l3; r3_reg <= r3;
            l4_reg <= l4; r4_reg <= r4;
            n_count <= 1;
          end
        end

        COMPUTE: begin
          if (n_count <= K_reg) begin
            case (n_count)
              1: x_reg[n_count] <= a1_reg;
              2: x_reg[n_count] <= a2_reg;
              3: x_reg[n_count] <= a3_reg;
              4: x_reg[n_count] <= a4_reg;
              default: x_reg[n_count] <= '0;
            endcase
          end else begin
            case (K_reg)
              2'd1: x_reg[n_count] <= x_reg[n_count-1];
              2'd2: x_reg[n_count] <= x_reg[n_count-1] ^ x_reg[n_count-2];
              2'd3: x_reg[n_count] <= x_reg[n_count-1] ^ x_reg[n_count-2] ^ x_reg[n_count-3];
              2'd4: x_reg[n_count] <= x_reg[n_count-1] ^ x_reg[n_count-2] ^ x_reg[n_count-3] ^ x_reg[n_count-4];
            endcase
          end
          n_count <= n_count + 1;
        end

        QUERIES: begin
          done <= 1'b1;
          res1 <= compute_xor(l1_reg, r1_reg);
          res2 <= compute_xor(l2_reg, r2_reg);
          res3 <= compute_xor(l3_reg, r3_reg);
          res4 <= compute_xor(l4_reg, r4_reg);
        end

        DONE: begin
          if (!start) done <= 1'b0;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = COMPUTE;
      COMPUTE: if (n_count == 16) next_state = QUERIES;
      QUERIES: next_state = DONE;
      DONE: if (!start) next_state = IDLE;
    endcase
  end

  function [7:0] compute_xor(input [3:0] l, r);
    compute_xor = '0;
    for (int i = l; i <= r; i++) compute_xor ^= x_reg[i];
  endfunction

endmodule