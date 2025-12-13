module alternating_chain(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [15:0] c,
  input  [15:0] r,
  input  signed [7:0] scores [0:7],
  output reg [31:0] min_time,
  output reg done
);

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_SCAN   = 3'd2,
    S_EVAL   = 3'd3,
    S_DONE   = 3'd4
  } state_t;

  state_t state, next_state;

  // Registers
  reg [2:0] idx;                   // current index 0..7
  reg [2:0] idx_next;

  // pattern 0 (P): index0 positive, then alternate
  // pattern 1 (N): index0 negative, then alternate
  reg [31:0] total_cost_P, total_cost_N;
  reg [31:0] total_cost_P_next, total_cost_N_next;

  reg [2:0] length;                // latched n
  reg [15:0] cost_vote;            // latched c
  reg [15:0] cost_report;          // latched r

  // helper function: absolute value of signed 8-bit
  function automatic [7:0] abs8(input signed [7:0] v);
    begin
      abs8 = (v < 0) ? -v : v;
    end
  endfunction

  // combinational per-index cost computation
  // For each pattern, compute minimal of vote-to-correct or removal.
  // Vote cost: abs(value_to_target) * c

  // wires for current element
  reg signed [7:0] s_val;
  reg [7:0] abs_s;

  // pattern expectations
  reg expect_pos_P, expect_pos_N; // 1 => expect positive; 0 => expect negative

  // per-step costs
  reg [31:0] costP_vote, costN_vote;
  reg [31:0] costP_rm, costN_rm;
  reg [31:0] min_costP_step, min_costN_step;

  // combinational block for next state and cost calculations
  always @* begin
    next_state        = state;
    idx_next          = idx;
    total_cost_P_next = total_cost_P;
    total_cost_N_next = total_cost_N;

    // defaults
    done = 1'b0;

    // set up current score value and abs
    s_val = scores[idx];
    abs_s = abs8(s_val);

    // expected sign per pattern at this index
    // pattern P: start positive at idx 0
    // pattern N: start negative at idx 0
    expect_pos_P = (idx[0] == 1'b0); // even index -> positive, odd -> negative
    expect_pos_N = (idx[0] == 1'b1); // even index -> negative, odd -> positive

    // removal cost is same for both patterns
    costP_rm = cost_report;
    costN_rm = cost_report;

    // Vote cost pattern P
    if (expect_pos_P) begin
      if (s_val >= 1) begin
        costP_vote = 32'd0; // already positive non-zero
      end else begin
        // need to bring to +1
        // delta = 1 - s_val
        // max delta: 1 - (-128) = 129 fits in 8 bits
        costP_vote = (32'(1 - s_val)) * cost_vote;
      end
    end else begin
      // expect negative
      if (s_val <= -1) begin
        costP_vote = 32'd0; // already negative non-zero
      end else begin
        // need to bring to -1
        // delta = s_val + 1 (number of down-votes)
        costP_vote = (32'(s_val + 1)) * cost_vote;
      end
    end

    // Vote cost pattern N
    if (expect_pos_N) begin
      if (s_val >= 1) begin
        costN_vote = 32'd0;
      end else begin
        costN_vote = (32'(1 - s_val)) * cost_vote;
      end
    end else begin
      if (s_val <= -1) begin
        costN_vote = 32'd0;
      end else begin
        costN_vote = (32'(s_val + 1)) * cost_vote;
      end
    end

    // per index choose min(vote, remove)
    if (costP_vote <= costP_rm)
      min_costP_step = costP_vote;
    else
      min_costP_step = costP_rm;

    if (costN_vote <= costN_rm)
      min_costN_step = costN_vote;
    else
      min_costN_step = costN_rm;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT;
        end
      end

      S_INIT: begin
        // latch configuration
        // limit n to 1..8 implicitly by 3 bits, but use as is
        // handle n==0 as 0 cost (though spec says 1-8)
        next_state        = (n == 3'd0) ? S_EVAL : S_SCAN;
      end

      S_SCAN: begin
        // accumulate for current idx
        total_cost_P_next = total_cost_P + min_costP_step;
        total_cost_N_next = total_cost_N + min_costN_step;

        // advance index
        if (idx + 3'd1 >= length) begin
          next_state = S_EVAL;
        end
        idx_next = idx + 3'd1;
      end

      S_EVAL: begin
        // choose minimal across both patterns
        done       = 1'b1;
        next_state = S_DONE;
      end

      S_DONE: begin
        done = 1'b1;
        if (!start) begin
          // wait for start to deassert before going idle
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      idx           <= 3'd0;
      total_cost_P  <= 32'd0;
      total_cost_N  <= 32'd0;
      min_time      <= 32'd0;
      length        <= 3'd0;
      cost_vote     <= 16'd0;
      cost_report   <= 16'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          if (start) begin
            // initialize on start edge
            idx          <= 3'd0;
            total_cost_P <= 32'd0;
            total_cost_N <= 32'd0;
            length       <= n;
            cost_vote    <= c;
            cost_report  <= r;
          end
        end

        S_INIT: begin
          // already latched; just set initial index
          idx <= 3'd0;
        end

        S_SCAN: begin
          idx          <= idx_next;
          total_cost_P <= total_cost_P_next;
          total_cost_N <= total_cost_N_next;
        end

        S_EVAL: begin
          // choose minimal across patterns
          if (total_cost_P_next <= total_cost_N_next)
            min_time <= total_cost_P_next;
          else
            min_time <= total_cost_N_next;
        end

        S_DONE: begin
          // hold min_time until next start/reset
          // no updates
        end

        default: begin
          // no-op
        end
      endcase
    end
  end

endmodule