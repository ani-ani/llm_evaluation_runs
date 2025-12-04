module alice_bob_meet(
  input clk,
  input rst_n,
  input start,
  input [15:0] adjacency,
  input [1:0] alice_start,
  input [1:0] bob_start,
  output reg [31:0] expected_time,
  output reg done
);

  // Q16.16 constants
  localparam [31:0] Q_ONE   = 32'h00010000;
  localparam [31:0] Q_ZERO  = 32'h00000000;
  localparam [31:0] Q_INF   = 32'hFFFFFFFF;

  // States
  typedef enum logic [1:0] {
    S_IDLE      = 2'b00,
    S_INIT      = 2'b01,
    S_CALC      = 2'b10,
    S_FINISH    = 2'b11
  } state_t;

  state_t state, next_state;

  // Probability and expectation storage
  // P_move[x][y]: probability to move from station x to y (Q16.16)
  reg [31:0] P_move [0:3][0:3];

  // Expected time E[i][j] for positions (i,j) in Q16.16
  reg [31:0] E      [0:3][0:3];

  // Next-state for E during iterative refinement
  reg [31:0] E_next [0:3][0:3];

  // Iteration counter (ensure <=16 cycles in CALC)
  reg [3:0] iter_cnt;

  // Internal wires/regs
  integer i, j, k, l;

  // Helper: count neighbors for a node
  function automatic [2:0] count_deg;
    input [3:0] row_bits;
    integer idx;
    begin
      count_deg = 3'd0;
      for (idx = 0; idx < 4; idx = idx + 1) begin
        count_deg = count_deg + row_bits[idx];
      end
    end
  endfunction

  // Multiply two Q16.16 numbers (truncate)
  function automatic [31:0] qmul;
    input [31:0] a;
    input [31:0] b;
    reg   [63:0] prod;
    begin
      prod = a * b;
      qmul = prod[47:16];
    end
  endfunction

  // Add two Q16.16 with simple saturation to Q_INF on overflow
  function automatic [31:0] qadd_sat;
    input [31:0] a;
    input [31:0] b;
    reg   [32:0] sum_ext;
    begin
      sum_ext = {1'b0, a} + {1'b0, b};
      if (sum_ext[32])
        qadd_sat = Q_INF;
      else
        qadd_sat = sum_ext[31:0];
    end
  endfunction

  // Detect disconnected / never meet condition via simple reachability:
  // if alice_start or bob_start isolated or graph has no path between them.
  // For 4 nodes, we can compute Floyd-Warshall style reachability combinationally.
  function automatic bit disconnected;
    input [15:0] adj;
    input [1:0] a0;
    input [1:0] b0;
    reg [3:0] reach [0:3];
    integer x,y;
    begin
      // Initialize reach with adjacency and self
      for (x = 0; x < 4; x = x + 1) begin
        reach[x] = 4'b0000;
        for (y = 0; y < 4; y = y + 1) begin
          reach[x][y] = adj[x*4 + y];
        end
        reach[x][x] = 1'b1;
      end

      // Warshall
      integer kidx;
      for (kidx = 0; kidx < 4; kidx = kidx + 1) begin
        for (x = 0; x < 4; x = x + 1) begin
          if (reach[x][kidx]) begin
            reach[x] = reach[x] | reach[kidx];
          end
        end
      end

      // Check connectivity between alice_start and bob_start
      if (!reach[a0][b0]) begin
        disconnected = 1'b1;
      end else begin
        disconnected = 1'b0;
      end
    end
  endfunction

  // Sequential state updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      done           <= 1'b0;
      expected_time  <= Q_ZERO;
      iter_cnt       <= 4'd0;
      // Clear E
      for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          E[i][j] <= Q_ZERO;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // nothing else here; transitions handled in next_state logic
          end
        end

        S_INIT: begin
          // Precompute transition probabilities P_move using adjacency
          // For each node x, P(x->y) = 1/deg(x) if edge else 0 (uniform)
          // Represent 1/deg in Q16.16.
          reg [3:0] row_bits;
          reg [2:0] deg;
          reg [31:0] inv_deg_q;
          for (i = 0; i < 4; i = i + 1) begin
            row_bits = {adjacency[i*4+3], adjacency[i*4+2], adjacency[i*4+1], adjacency[i*4+0]};
            deg = count_deg(row_bits);
            if (deg == 0) begin
              inv_deg_q = Q_ZERO;
            end else begin
              // Q16.16 representation of 1/deg = (1<<16)/deg
              inv_deg_q = (32'h00010000 / deg);
            end
            for (j = 0; j < 4; j = j + 1) begin
              if (adjacency[i*4 + j])
                P_move[i][j] <= inv_deg_q;
              else
                P_move[i][j] <= Q_ZERO;
            end
          end

          // Initialize E
          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
              if (i == j)
                E[i][j] <= Q_ZERO; // already meeting
              else
                E[i][j] <= Q_ZERO; // start iteration from 0
            end
          end

          iter_cnt <= 4'd0;
        end

        S_CALC: begin
          // One Jacobi-style update for all (i,j) in a single cycle
          // E_next[i][j] = 1 + sum_{i',j'} P(i->i') P(j->j') E[i'][j']  for i!=j
          // E[i][i] = 0
          reg [63:0] acc;
          reg [31:0] one_q;
          one_q = Q_ONE;

          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
              if (i == j) begin
                E_next[i][j] = Q_ZERO;
              end else begin
                acc = 64'd0;
                for (k = 0; k < 4; k = k + 1) begin
                  for (l = 0; l < 4; l = l + 1) begin
                    if (P_move[i][k] != Q_ZERO && P_move[j][l] != Q_ZERO) begin
                      // term = P(i->k) * P(j->l) * E[k][l]
                      // First mul probabilities (Q16.16 * Q16.16 -> Q16.16)
                      // then mul by E (Q16.16 * Q16.16 -> Q16.16)
                      reg [31:0] pij, term_q;
                      pij    = qmul(P_move[i][k], P_move[j][l]);
                      term_q = qmul(pij, E[k][l]);
                      acc = acc + {32'd0, term_q};
                    end
                  end
                end
                // acc is sum of Q16.16 terms; reduce to Q16.16 with saturation
                reg [31:0] acc_q;
                if (acc[63:32] != 32'd0)
                  acc_q = Q_INF;
                else
                  acc_q = acc[31:0];

                E_next[i][j] = qadd_sat(one_q, acc_q);
              end
            end
          end

          // Commit E_next to E
          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
              E[i][j] <= E_next[i][j];
            end
          end

          // Increment iteration counter
          iter_cnt <= iter_cnt + 1'b1;
        end

        S_FINISH: begin
          done <= 1'b1;
          // expected_time assigned in combinational next_state logic or retained
        end

        default: begin
          // safety
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next-state and outputs combinational logic
  always @(*) begin
    next_state     = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          // Check disconnected condition
          if (disconnected(adjacency, alice_start, bob_start)) begin
            next_state = S_FINISH;
          end else begin
            next_state = S_INIT;
          end
        end
      end

      S_INIT: begin
        // Move directly to calculation
        next_state = S_CALC;
      end

      S_CALC: begin
        // After enough iterations (<=16), finish
        if (iter_cnt == 4'd15) begin
          next_state = S_FINISH;
        end else begin
          next_state = S_CALC;
        end
      end

      S_FINISH: begin
        // Remain here until start deasserted and reasserted (implicit via S_IDLE on reset)
        next_state = S_FINISH;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // expected_time update (sequential, depends on state transitions)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      expected_time <= Q_ZERO;
    end else begin
      if (state == S_IDLE && start && disconnected(adjacency, alice_start, bob_start)) begin
        // Directly never-meet case recognized when transitioning to FINISH
        expected_time <= Q_INF;
      end else if (state == S_CALC && next_state == S_FINISH) begin
        // Capture E at starting positions after final iteration
        if (alice_start == bob_start)
          expected_time <= Q_ZERO;
        else
          expected_time <= E[alice_start][bob_start];
      end
    end
  end

endmodule