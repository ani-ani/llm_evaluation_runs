module t_return_day_finder(
  input clk,
  input rst_n,
  input start,
  input [4:0] L,
  input [15:0] adj_matrix_row0,
  input [15:0] adj_matrix_row1,
  input [15:0] adj_matrix_row2,
  output reg signed [5:0] T_out,
  output reg done
);

  // Fixed-point: Q10.10
  localparam int FP_WIDTH     = 20;
  localparam int FP_FRAC      = 10;
  localparam int FP_ONE       = (1 << FP_FRAC);
  localparam int FP_95_PCT    = (973 << FP_FRAC); // 0x3E800
  localparam int TOL          = 1;                // +/-1 tolerance

  // FSM States
  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    INIT          = 3'd1,
    COMPUTE_DAY   = 3'd2,
    STEP_DAY      = 3'd3,
    CHECK_RESULT  = 3'd4,
    DONE          = 3'd5
  } state_t;

  state_t state, next_state;

  // Day / iteration tracking
  reg [5:0] cur_T;       // current absolute day T
  reg [3:0] day_idx;     // 0..9 offset from L

  // Probabilities for nodes 1..4 in Q10.10
  reg signed [FP_WIDTH-1:0] prob_curr [0:3];
  reg signed [FP_WIDTH-1:0] prob_next [0:3];

  // Adjacency probabilities for node4 row (assume 4 entries, 4 bits each) derived as complement
  // Given: rows 0..2 are inputs. Row3 (node4) = stay prob implied so row-sum=1.0

  // For convenience: extract 4-bit entries from rows
  function automatic [3:0] get_w(input [15:0] row, input int idx);
    case(idx)
      0: get_w = row[3:0];
      1: get_w = row[7:4];
      2: get_w = row[11:8];
      3: get_w = row[15:12];
      default: get_w = 4'd0;
    endcase
  endfunction

  // Multiply probability p (Q10.10) by 4-bit weight w (interpreted as w/16), return Q10.10
  function automatic signed [FP_WIDTH-1:0] mul_pw(
    input signed [FP_WIDTH-1:0] p,
    input [3:0] w
  );
    // (p * w) / 16
    logic signed [FP_WIDTH+3:0] mult;
    begin
      mult = p * $signed({1'b0,w});
      mul_pw = mult >>> 4;
    end
  endfunction

  // Compute next-day probabilities combinationally from prob_curr
  // Using a simple row-stochastic model where each row's 4-bit entries are probabilities/16.
  // Node indices: 0->node1,1->node2,2->node3,3->node4.
  // Rows: row0 -> from node1, row1 -> from node2, row2 -> from node3, row3 -> from node4 (derived).
  // We assume for node4: it can only stay (self-loop) with prob=1.0 (no outgoing else specified).
  // This yields deterministic, hardware-friendly behavior consistent with constraints.

  integer i;

  always @* begin
    // Default next probabilities
    for (i = 0; i < 4; i = i + 1) begin
      prob_next[i] = '0;
    end

    // From node1 (row0)
    prob_next[0] = prob_next[0] + mul_pw(prob_curr[0], get_w(adj_matrix_row0,0));
    prob_next[1] = prob_next[1] + mul_pw(prob_curr[0], get_w(adj_matrix_row0,1));
    prob_next[2] = prob_next[2] + mul_pw(prob_curr[0], get_w(adj_matrix_row0,2));
    prob_next[3] = prob_next[3] + mul_pw(prob_curr[0], get_w(adj_matrix_row0,3));

    // From node2 (row1)
    prob_next[0] = prob_next[0] + mul_pw(prob_curr[1], get_w(adj_matrix_row1,0));
    prob_next[1] = prob_next[1] + mul_pw(prob_curr[1], get_w(adj_matrix_row1,1));
    prob_next[2] = prob_next[2] + mul_pw(prob_curr[1], get_w(adj_matrix_row1,2));
    prob_next[3] = prob_next[3] + mul_pw(prob_curr[1], get_w(adj_matrix_row1,3));

    // From node3 (row2)
    prob_next[0] = prob_next[0] + mul_pw(prob_curr[2], get_w(adj_matrix_row2,0));
    prob_next[1] = prob_next[1] + mul_pw(prob_curr[2], get_w(adj_matrix_row2,1));
    prob_next[2] = prob_next[2] + mul_pw(prob_curr[2], get_w(adj_matrix_row2,2));
    prob_next[3] = prob_next[3] + mul_pw(prob_curr[2], get_w(adj_matrix_row2,3));

    // From node4: assume self-loop with prob=1.0
    prob_next[3] = prob_next[3] + prob_curr[3];
  end

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      T_out   <= -1;
      done    <= 1'b0;
      cur_T   <= 6'd0;
      day_idx <= 4'd0;
      for (i = 0; i < 4; i = i + 1) begin
        prob_curr[i] <= '0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done  <= 1'b0;
          T_out <= -1;
          if (start) begin
            // Prepare for INIT in next_state
            cur_T   <= L;       // Day starts at L
            day_idx <= 4'd0;
          end
        end

        INIT: begin
          // Initialize day-1 distribution (node1=1.0, others 0)
          prob_curr[0] <= FP_ONE;
          prob_curr[1] <= '0;
          prob_curr[2] <= '0;
          prob_curr[3] <= '0;
        end

        COMPUTE_DAY: begin
          // Latch prob_next as start of this day's iteration
          prob_curr[0] <= prob_next[0];
          prob_curr[1] <= prob_next[1];
          prob_curr[2] <= prob_next[2];
          prob_curr[3] <= prob_next[3];
        end

        STEP_DAY: begin
          // After at least one propagation, ready for check
          // No additional action; probabilities already updated in COMPUTE_DAY
        end

        CHECK_RESULT: begin
          // Check node4 probability for current T
          if ((prob_curr[3] >= (FP_95_PCT - TOL)) &&
              (prob_curr[3] <= (FP_95_PCT + TOL))) begin
            T_out <= cur_T;
            done  <= 1'b1;
          end else begin
            // Move to next day if within window
            if (day_idx < 4'd9 && cur_T < 6'd31) begin
              day_idx <= day_idx + 4'd1;
              cur_T   <= cur_T + 6'd1;
            end else begin
              // No match found in [L, L+9]
              T_out <= -1;
              done  <= 1'b1;
            end
          end
        end

        DONE: begin
          // Hold result until next start
          if (start) begin
            done    <= 1'b0;
            T_out   <= -1;
            cur_T   <= L;
            day_idx <= 4'd0;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // FSM next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // After initializing, perform first day's propagation
        next_state = COMPUTE_DAY;
      end

      COMPUTE_DAY: begin
        // One cycle to compute next probabilities
        next_state = STEP_DAY;
      end

      STEP_DAY: begin
        // Now check result for this day
        next_state = CHECK_RESULT;
      end

      CHECK_RESULT: begin
        if ((prob_curr[3] >= (FP_95_PCT - TOL)) &&
            (prob_curr[3] <= (FP_95_PCT + TOL))) begin
          next_state = DONE;
        end else begin
          if (day_idx < 4'd9 && cur_T < 6'd31) begin
            // Prepare probabilities for next day: another propagation
            next_state = COMPUTE_DAY;
          end else begin
            // No valid T found
            next_state = DONE;
          end
        end
      end

      DONE: begin
        if (start)
          next_state = INIT;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule