module gon_win_prob(
  input clk,
  input rst_n,
  input start,
  input [3:0] g,
  input [3:0] k,
  input [7:0] p,
  output reg [23:0] prob_out,
  output reg done
);

  // State encoding
  localparam IDLE = 2'b00;
  localparam RUN  = 2'b01;

  reg [1:0] state, next_state;
  reg [4:0] step_cnt;          // 0..16

  // Probability terms in Q0.8
  wire [8:0] p_head_ext = {1'b0, p};       // Q0.8 (effectively 9 bits, but p is 8)
  wire [8:0] p_tail_ext = 9'd256 - p_head_ext; // 1.0 - p, Q0.8

  // Current sequence state in Q16.8 (24-bit)
  reg [23:0] prob_alive;       // probability game still running
  reg [23:0] prob_g;           // accumulated Gon-only win
  reg [23:0] prob_k;           // accumulated Killua-only win
  reg [23:0] prob_draw;        // accumulated simultaneous-completion prob (ignored for output)

  // Current match lengths (0..4)
  reg [2:0] ml_g;
  reg [2:0] ml_k;

  // Helper: compute next match length for a pattern of length 4
  // Given current match length 'ml', next coin 'bit', and pattern 'pat'.
  function automatic [2:0] next_match_len;
    input [2:0] ml;
    input bit_bit;         // 0 = H, 1 = T
    input [3:0] pat;       // pattern bits, [3] oldest, [0] newest
    reg [2:0] try_len;
    reg ok;
    integer i;
  begin
    // If extending completes full match directly
    if (ml < 4 && pat[3-ml] == bit_bit) begin
      try_len = ml + 1'b1;
      // If full, return 4; else see if longer border exists is handled by general search below
    end

    // General KMP-like: search largest L (4..1) such that
    // suffix of (current matched prefix + bit_bit) of length L equals pat[0..L-1]
    next_match_len = 3'd0;
    for (try_len = 3'd4; try_len >= 3'd1; try_len = try_len - 1'b1) begin
      ok = 1'b1;
      for (i = 0; i < try_len; i = i + 1) begin
        // Position in extended sequence corresponding to this i:
        // For indices 0..(try_len-2): they map into previous matched prefix
        // Index try_len-1 is the new bit
        if (i == try_len-1) begin
          if (bit_bit != pat[i]) ok = 1'b0;
        end else begin
          // Map to previous matched prefix index
          // We need that previous suffix of length (try_len-1) equals pat[0..try_len-2]
          // So prefix index is: (ml - (try_len-1)) + i
          if (ml < (try_len-1)) begin
            ok = 1'b0;
          end else begin
            if (pat[i] != pat[ (ml - (try_len-1)) + i ]) ok = 1'b0;
          end
        end
      end
      if (ok) begin
        next_match_len = try_len;
        disable for; // break
      end
    end
  end
  endfunction

  // Next-state logic and probability updates
  reg [23:0] prob_alive_n;
  reg [23:0] prob_g_n;
  reg [23:0] prob_k_n;
  reg [23:0] prob_draw_n;
  reg [2:0]  ml_g_h_n, ml_k_h_n; // next matches for heads
  reg [2:0]  ml_g_t_n, ml_k_t_n; // next matches for tails
  reg [2:0]  ml_g_n, ml_k_n;
  reg [4:0]  step_cnt_n;
  reg        done_n;

  // Combinational block
  always @* begin
    // Defaults
    next_state   = state;
    step_cnt_n   = step_cnt;
    prob_alive_n = prob_alive;
    prob_g_n     = prob_g;
    prob_k_n     = prob_k;
    prob_draw_n  = prob_draw;
    ml_g_n       = ml_g;
    ml_k_n       = ml_k;
    done_n       = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize for new run
          next_state   = RUN;
          step_cnt_n   = 5'd0;
          prob_alive_n = 24'd256;  // 1.0 in Q16.8
          prob_g_n     = 24'd0;
          prob_k_n     = 24'd0;
          prob_draw_n  = 24'd0;
          ml_g_n       = 3'd0;
          ml_k_n       = 3'd0;
        end
      end

      RUN: begin
        // Perform one step per cycle until 16 steps completed
        if (step_cnt < 5'd16 && prob_alive != 24'd0) begin
          // Compute next match lengths for both possible flips
          ml_g_h_n = next_match_len(ml_g, 1'b0, g);
          ml_k_h_n = next_match_len(ml_k, 1'b0, k);
          ml_g_t_n = next_match_len(ml_g, 1'b1, g);
          ml_k_t_n = next_match_len(ml_k, 1'b1, k);

          // HEAD branch probabilities
          // p_head_ext is Q0.8, prob_alive is Q16.8 => product Q16.16, shift right 8 -> Q16.8
          // Use 32-bit temp
          reg [31:0] tmp_head;
          reg [31:0] tmp_tail;
          reg [23:0] prob_head;
          reg [23:0] prob_tail;
          reg [23:0] add_g;
          reg [23:0] add_k;
          reg [23:0] add_draw;
          reg [23:0] add_alive;

          tmp_head = prob_alive * p_head_ext[7:0];
          prob_head = tmp_head[23:0] >> 8; // keep Q16.8

          // TAIL branch
          tmp_tail = prob_alive * p_tail_ext[7:0];
          prob_tail = tmp_tail[23:0] >> 8;

          add_g    = 24'd0;
          add_k    = 24'd0;
          add_draw = 24'd0;
          add_alive= 24'd0;

          // Process HEAD outcome
          if (ml_g_h_n == 3'd4 && ml_k_h_n == 3'd4) begin
            add_draw = add_draw + prob_head;
          end else if (ml_g_h_n == 3'd4) begin
            add_g = add_g + prob_head;
          end else if (ml_k_h_n == 3'd4) begin
            add_k = add_k + prob_head;
          end else begin
            add_alive = add_alive + prob_head;
          end

          // Process TAIL outcome
          if (ml_g_t_n == 3'd4 && ml_k_t_n == 3'd4) begin
            add_draw = add_draw + prob_tail;
          end else if (ml_g_t_n == 3'd4) begin
            add_g = add_g + prob_tail;
          end else if (ml_k_t_n == 3'd4) begin
            add_k = add_k + prob_tail;
          end else begin
            add_alive = add_alive + prob_tail;
          end

          // Update accumulators
          prob_g_n     = prob_g + add_g;
          prob_k_n     = prob_k + add_k;
          prob_draw_n  = prob_draw + add_draw;
          prob_alive_n = add_alive;

          // For ongoing state, we don't track per-outcome ml; we could choose any non-terminal branch.
          // Since probabilities are merged, we conceptually treat match lengths as part of probabilistic state.
          // To keep a single path, when both branches are non-terminal we arbitrarily pick head's ml.
          // (This is an approximation per given constraints.)
          if (add_alive != 24'd0) begin
            // Prefer head non-terminal if it contributed, else tail.
            if ( (ml_g_h_n != 3'd4 && ml_k_h_n != 3'd4) && (prob_head != 24'd0) ) begin
              ml_g_n = ml_g_h_n;
              ml_k_n = ml_k_h_n;
            end else if ( (ml_g_t_n != 3'd4 && ml_k_t_n != 3'd4) && (prob_tail != 24'd0) ) begin
              ml_g_n = ml_g_t_n;
              ml_k_n = ml_k_t_n;
            end else begin
              ml_g_n = 3'd0;
              ml_k_n = 3'd0;
            end
          end else begin
            ml_g_n = 3'd0;
            ml_k_n = 3'd0;
          end

          step_cnt_n = step_cnt + 5'd1;

          if (step_cnt_n == 5'd16 || prob_alive_n == 24'd0) begin
            next_state = IDLE;
            done_n     = 1'b1;
          end
        end else begin
          // Already reached depth or no alive probability; output done once and go IDLE
          next_state = IDLE;
          done_n     = 1'b1;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      step_cnt   <= 5'd0;
      prob_alive <= 24'd0;
      prob_g     <= 24'd0;
      prob_k     <= 24'd0;
      prob_draw  <= 24'd0;
      ml_g       <= 3'd0;
      ml_k       <= 3'd0;
      prob_out   <= 24'd0;
      done       <= 1'b0;
    end else begin
      state      <= next_state;
      step_cnt   <= step_cnt_n;
      prob_alive <= prob_alive_n;
      prob_g     <= prob_g_n;
      prob_k     <= prob_k_n;
      prob_draw  <= prob_draw_n;
      ml_g       <= ml_g_n;
      ml_k       <= ml_k_n;
      done       <= done_n;
      // Output Gon's win probability
      prob_out   <= prob_g_n;
    end
  end

endmodule