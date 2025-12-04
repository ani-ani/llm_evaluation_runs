module autocorrect_min_keystrokes(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start calculation
  input [7:0][39:0] dictionary, // 8 dictionary words (40 bits each: 8 chars * 5 bits/char)
  input [39:0] target_word, // word to type (40 bits: 8 chars * 5 bits/char)
  output reg [4:0] keystrokes, // minimum keystrokes required (max 31)
  output reg done // high when calculation complete
);

  // Internal signals
  reg [1:0] state, state_n;
  localparam IDLE  = 2'd0;
  localparam LOAD  = 2'd1;
  localparam CALC  = 2'd2;
  localparam OUT   = 2'd3;

  // Latched inputs
  reg [7:0][39:0] dict_reg;
  reg [39:0]      target_reg;

  // Helper: extract character function
  function automatic [4:0] get_char;
    input [39:0] word;
    input [2:0]  idx; // 0..7
    begin
      get_char = word[5*idx +: 5];
    end
  endfunction

  // Helper: compute target length (up to first 31 or 8)
  function automatic [3:0] get_word_len;
    input [39:0] word;
    integer i;
    begin
      get_word_len = 4'd8;
      for (i = 0; i < 8; i = i + 1) begin
        if (get_char(word, i[2:0]) == 5'd31 && get_word_len == 4'd8) begin
          get_word_len = i[3:0];
        end
      end
    end
  endfunction

  // Helper: longest common prefix length between target_reg and a dictionary word
  function automatic [3:0] lcp_len;
    input [39:0] t;
    input [39:0] d;
    integer i;
    reg [4:0] tc, dc;
    begin
      lcp_len = 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        tc = t[5*i +: 5];
        dc = d[5*i +: 5];
        if (tc == 5'd31 || dc == 5'd31) begin
          // stop at unused character in either
          disable lcp_stop;
        end
        if (tc == dc)
          lcp_len = lcp_len + 1;
        else
          disable lcp_stop;
      end
      lcp_stop: ;
    end
  endfunction

  // NOTE: SystemVerilog does not support named disable of blocks
  // inside function as written above in synthesizable style.
  // Re-implement lcp_len without disable for synthesis correctness.
  function automatic [3:0] lcp_len2;
    input [39:0] t;
    input [39:0] d;
    integer i;
    reg [4:0] tc, dc;
    reg stop;
    begin
      lcp_len2 = 4'd0;
      stop = 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        if (!stop) begin
          tc = t[5*i +: 5];
          dc = d[5*i +: 5];
          if (tc == 5'd31 || dc == 5'd31) begin
            stop = 1'b1;
          end else if (tc == dc) begin
            lcp_len2 = lcp_len2 + 1;
          end else begin
            stop = 1'b1;
          end
        end
      end
    end
  endfunction

  // Combinational calculation for keystrokes
  reg [4:0] keystrokes_calc;
  reg [3:0] L; // length of target

  integer i, j;
  reg [3:0] prefix_len;
  reg [3:0] best_sugg_len;
  reg [3:0] lcp;
  reg [4:0] cost_normal;
  reg [4:0] cost_best;

  always @(*) begin
    // Default outputs
    keystrokes_calc = 5'd0;

    // Compute target length
    L = get_word_len(target_reg);

    // If empty word -> 0 keystrokes
    if (L == 4'd0) begin
      keystrokes_calc = 5'd0;
    end else begin
      // Dynamic programming: dp prefix minimal keystrokes
      // dp[0] = 0; for i=1..L
      // dp[i] = min( dp[i-1] + 1 (type char i), suggestion options )
      reg [4:0] dp [0:8];
      dp[0] = 5'd0;

      for (i = 1; i <= 8; i = i + 1) begin
        if (i <= L) begin
          // normal typing from previous prefix
          cost_normal = dp[i-1] + 5'd1;

          // find best suggestion for prefix length i
          best_sugg_len = 4'd0;
          for (j = 0; j < 8; j = j + 1) begin
            lcp = lcp_len2(target_reg, dict_reg[j]);
            // suggestion must fully cover prefix i
            if (lcp >= i[3:0]) begin
              if (lcp > best_sugg_len) begin
                best_sugg_len = lcp;
              end
            end
          end

          // If there is a suggestion: we model choosing at this prefix i
          // cost: dp[i] via suggestion = dp[i] candidate from previous prefix i
          // Use pattern: apply suggestion at prefix i by:
          // - we already computed dp[i-1], then type char i OR
          // - one could also consider applying suggestion from an earlier prefix.
          // For a 3-cycle design, we keep it simple and allow suggestions only at exact prefix i:
          // cost_sugg = dp[i-1] + 1 (TAB) + (best_sugg_len - i) (extra chars auto from suggestion)
          // But we only need minimal keystrokes to reach positions; model as finishing at position best_sugg_len.
          // Hence we'll update dp for best_sugg_len using prefix i decisions in a local manner.

          // Start with normal typing
          dp[i] = cost_normal;

          // Suggestion: apply tab at position i-1 to reach best_sugg_len
          // To approximate within single pass, only apply suggestion starting at prefix (i-1):
          // if best_sugg_len > i-1 then from dp[i-1]: cost = dp[i-1] + 1 (TAB)
          // and we can jump ahead, but this requires multi-step updates.
          // Instead, we restrict: when computing dp[i], consider suggestion starting at prefix i-1 that reaches i.
          // That requires best_sugg_len >= i and decision at prefix i-1.

          // Recompute best_sugg_len for prefix (i-1)
          prefix_len = (i-1);
          best_sugg_len = 4'd0;
          if (prefix_len > 0) begin
            for (j = 0; j < 8; j = j + 1) begin
              lcp = lcp_len2(target_reg, dict_reg[j]);
              if (lcp >= prefix_len && lcp > best_sugg_len) begin
                best_sugg_len = lcp;
              end
            end
          end

          cost_best = 5'd31; // large
          if (prefix_len > 0 && best_sugg_len >= i && best_sugg_len > prefix_len) begin
            // from dp[prefix_len]: TAB (1) then suggestion auto-completes to best_sugg_len
            // To stand at position i (<= best_sugg_len), cost is same as reaching best_sugg_len.
            // We approximate cost at i as dp[prefix_len] + 1.
            if (dp[prefix_len] + 5'd1 < cost_best)
              cost_best = dp[prefix_len] + 5'd1;
          end

          if (cost_best < dp[i])
            dp[i] = cost_best;
        end else begin
          dp[i] = 5'd31; // unused beyond L
        end
      end

      keystrokes_calc = dp[L];
    end
  end

  // Sequential state machine and registers
  always @(*) begin
    state_n = state;
    done    = 1'b0;
    keystrokes = keystrokes; // hold by default

    case (state)
      IDLE: begin
        if (start)
          state_n = LOAD;
      end

      LOAD: begin
        // Inputs are latched in sequential block; move to CALC next
        state_n = CALC;
      end

      CALC: begin
        // Computation is combinational; advance to OUT next
        state_n = OUT;
      end

      OUT: begin
        done = 1'b1;
        keystrokes = keystrokes_calc;
        // Remain in OUT until start deasserts and reasserts; simple example returns to IDLE when start=0
        if (!start)
          state_n = IDLE;
      end

      default: begin
        state_n = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      dict_reg    <= '0;
      target_reg  <= '0;
      keystrokes  <= 5'd0;
    end else begin
      state <= state_n;
      if (state == IDLE && start) begin
        dict_reg   <= dictionary;
        target_reg <= target_word;
      end
      if (state == OUT) begin
        keystrokes <= keystrokes_calc;
      end
    end
  end

endmodule