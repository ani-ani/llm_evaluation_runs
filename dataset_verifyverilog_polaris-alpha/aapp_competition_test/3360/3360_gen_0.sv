module cfg_substring_matcher(
  input clk,
  input rst_n,
  input start,
  input [263:0] rules, // 8 rules * 33 bits (5-bit head + 28-bit production)
  input [95:0] text_line, // 16 chars * 6 bits
  output reg [95:0] longest_substr,
  output reg valid,
  output reg done
);

  // ---------------------------------------------------------------------------
  // Parameter / Localparam definitions
  // ---------------------------------------------------------------------------
  localparam int MAX_LEN          = 16;
  localparam int CHAR_W           = 6;   // terminals encoding width
  localparam int VAR_W            = 5;   // variable id width
  localparam int SYM_W            = 7;   // 1b is_var + 6b value
  localparam int RULE_PROD_SYMS   = 4;   // 4 symbols per production
  localparam int RULE_W           = 5 + (RULE_PROD_SYMS*SYM_W); // 33
  localparam int NUM_RULES        = 8;
  localparam int MAX_STEPS        = 16;  // max derivation steps
  localparam int MAX_SENT_SYMS    = 16;  // limit on working sentential form length
  localparam int MAX_MATCH_CYCLES = 256;

  // FSM states
  typedef enum logic [3:0] {
    S_IDLE          = 4'd0,
    S_INIT_SEARCH   = 4'd1,
    S_TRY_SUBSTR    = 4'd2,
    S_INIT_DERIVE   = 4'd3,
    S_APPLY_RULE    = 4'd4,
    S_FIND_VAR      = 4'd5,
    S_BUILD_NEW     = 4'd6,
    S_CHECK_RESULT  = 4'd7,
    S_NEXT_RULE     = 4'd8,
    S_NEXT_STEP     = 4'd9,
    S_NEXT_SUBSTR   = 4'd10,
    S_DONE          = 4'd11
  } state_t;

  // ---------------------------------------------------------------------------
  // Rule storage (combinational unpack from rules bus)
  // ---------------------------------------------------------------------------
  // rule_head[i]: 5-bit head; rule_sym[i][k]: 7-bit symbol (is_var[6], value[5:0])
  logic [4:0]              rule_head   [0:NUM_RULES-1];
  logic [SYM_W-1:0]        rule_sym    [0:NUM_RULES-1][0:RULE_PROD_SYMS-1];

  genvar gi, gj;
  generate
    for (gi = 0; gi < NUM_RULES; gi++) begin : G_RULES
      localparam int BASE = gi*RULE_W;
      // head
      always_comb begin
        rule_head[gi] = rules[BASE + 4 -: 5];
      end
      // production symbols (4x7b)
      for (gj = 0; gj < RULE_PROD_SYMS; gj++) begin : G_RULE_SYM
        localparam int SBASE = BASE + 5 + gj*SYM_W;
        always_comb begin
          rule_sym[gi][gj] = rules[SBASE + (SYM_W-1) -: SYM_W];
        end
      end
    end
  endgenerate

  // Start symbol = head of first rule
  wire [4:0] start_var = rule_head[0];

  // ---------------------------------------------------------------------------
  // Text extraction helper: get 6-bit char at index (0..15) from text_line
  // text_line[95:90] -> index 15, [5:0] -> index 0
  // ---------------------------------------------------------------------------
  function automatic [CHAR_W-1:0] get_text_char(
    input [95:0] tline,
    input [4:0]  idx
  );
    int lsb;
    begin
      lsb = idx*CHAR_W;
      get_text_char = tline[lsb + (CHAR_W-1) -: CHAR_W];
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Sentential form representation
  // Each symbol: [6]=is_var, [5:0]=id_or_char
  // ---------------------------------------------------------------------------
  typedef logic [SYM_W-1:0] sym_t;

  sym_t sentential      [0:MAX_SENT_SYMS-1];  // current sentential form
  sym_t next_sentential [0:MAX_SENT_SYMS-1];  // buffer when rebuilding
  integer sent_len;
  integer next_sent_len;

  // ---------------------------------------------------------------------------
  // Search control registers
  // ---------------------------------------------------------------------------
  state_t state, nstate;

  integer curr_len;        // current substring length being tried
  integer curr_start;      // start index of current substring in text_line

  integer step_count;      // derivation step counter (<= MAX_STEPS)
  integer rule_idx;        // rule being tried

  integer var_pos;         // first variable position in sentential form
  logic   has_var;         // indicates if any variable exists

  // bookkeeping
  integer i, j;

  // Match flag
  logic match_success;

  // ---------------------------------------------------------------------------
  // Helper: Compare sentential form with target substring when no variables
  // ---------------------------------------------------------------------------
  function automatic logic sentential_matches_substring;
    input sym_t   sform   [0:MAX_SENT_SYMS-1];
    input integer s_len;
    input integer start_idx;
    input integer length;
    input [95:0] tline;
    integer k;
    begin
      if (s_len != length) begin
        sentential_matches_substring = 1'b0;
      end else begin
        sentential_matches_substring = 1'b1;
        for (k = 0; k < s_len; k++) begin
          if (sform[k][6] == 1'b1) begin
            // still has variable -> not fully derived
            sentential_matches_substring = 1'b0;
          end else if (sform[k][5:0] != get_text_char(tline, start_idx + k)) begin
            sentential_matches_substring = 1'b0;
          end
        end
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Helper: Find first variable index in sentential form
  // ---------------------------------------------------------------------------
  function automatic int find_first_var_idx;
    input sym_t sform [0:MAX_SENT_SYMS-1];
    input int   s_len;
    int k;
    begin
      find_first_var_idx = -1;
      for (k = 0; k < s_len; k++) begin
        if (sform[k][6] == 1'b1) begin
          find_first_var_idx = k;
          k = s_len; // break
        end
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Helper: Build new sentential form when applying rule_idx at var_pos
  // Returns: success flag and new length; uses global rule_* arrays
  // ---------------------------------------------------------------------------
  function automatic logic build_new_sentential;
    input sym_t   sform   [0:MAX_SENT_SYMS-1];
    input int     s_len;
    input int     vpos;
    input int     r_idx;
    output sym_t  outform [0:MAX_SENT_SYMS-1];
    output int    out_len;
    int k;
    int wpos;
    int used;
    sym_t rs;
    begin
      // length = left part + production syms (non-zero) + right part
      used = 0;
      for (k = 0; k < RULE_PROD_SYMS; k++) begin
        rs = rule_sym[r_idx][k];
        if (rs != {SYM_W{1'b0}}) used++;
      end
      out_len = s_len - 1 + used; // replace single variable
      if (out_len > MAX_SENT_SYMS) begin
        build_new_sentential = 1'b0;
        // keep original to be safe
        for (k = 0; k < s_len; k++) outform[k] = sform[k];
      end else begin
        wpos = 0;
        // copy left of variable
        for (k = 0; k < vpos; k++) begin
          outform[wpos] = sform[k];
          wpos++;
        end
        // insert production symbols (skip zero entries)
        for (k = 0; k < RULE_PROD_SYMS; k++) begin
          rs = rule_sym[r_idx][k];
          if (rs != {SYM_W{1'b0}}) begin
            outform[wpos] = rs;
            wpos++;
          end
        end
        // copy right of variable
        for (k = vpos + 1; k < s_len; k++) begin
          outform[wpos] = sform[k];
          wpos++;
        end
        // pad remaining
        for (k = wpos; k < MAX_SENT_SYMS; k++) begin
          outform[k] = {SYM_W{1'b0}};
        end
        build_new_sentential = 1'b1;
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Sequential FSM
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      curr_len      <= 0;
      curr_start    <= 0;
      sent_len      <= 0;
      step_count    <= 0;
      rule_idx      <= 0;
      var_pos       <= -1;
      has_var       <= 1'b0;
      match_success <= 1'b0;
      longest_substr<= {96{1'b0}};
      valid         <= 1'b0;
      done          <= 1'b0;
      for (i = 0; i < MAX_SENT_SYMS; i++) begin
        sentential[i]      <= {SYM_W{1'b0}};
        next_sentential[i] <= {SYM_W{1'b0}};
      end
    end else begin
      case (state)
        S_IDLE: begin
          done          <= 1'b0;
          valid         <= 1'b0;
          match_success <= 1'b0;
          if (start) begin
            curr_len   <= MAX_LEN;
            curr_start <= 0;
            state      <= S_INIT_SUBSTR;
          end
        end

        // Synth-friendly alias: INIT_SEARCH
        S_INIT_SEARCH: begin
          // not used (fall-through style). Kept for completeness.
          state <= S_INIT_SUBSTR;
        end

        // Initialize a new substring (length = curr_len, start = curr_start)
        S_INIT_SUBSTR: begin
          // Initialize sentential form to start symbol
          sentential[0] <= {1'b1, start_var[4:0]};
          for (i = 1; i < MAX_SENT_SYMS; i++) begin
            sentential[i] <= {SYM_W{1'b0}};
          end
          sent_len      <= 1;
          step_count    <= 0;
          rule_idx      <= 0;
          match_success <= 1'b0;
          state         <= S_FIND_VAR;
        end

        // Find first variable in current sentential form
        S_FIND_VAR: begin
          var_pos = find_first_var_idx(sentential, sent_len);
          if (var_pos == -1) begin
            has_var <= 1'b0;
            state   <= S_CHECK_RESULT;
          end else begin
            has_var  <= 1'b1;
            rule_idx <= 0;
            state    <= S_APPLY_RULE;
          end
        end

        // Try applying rules at var_pos sequentially
        S_APPLY_RULE: begin
          if (!has_var) begin
            state <= S_CHECK_RESULT;
          end else if (rule_idx >= NUM_RULES) begin
            // No applicable rule for this variable -> fail this derivation path
            state <= S_NEXT_STEP; // counts as a step; will terminate if exceed
          end else begin
            // Check head match
            if (sentential[var_pos][6] == 1'b1 && // is var
                sentential[var_pos][4:0] == rule_head[rule_idx]) begin
              // Attempt build
              if (build_new_sentential(sentential, sent_len, var_pos, rule_idx,
                                       next_sentential, next_sent_len)) begin
                // commit new form
                for (i = 0; i < MAX_SENT_SYMS; i++) begin
                  sentential[i] <= next_sentential[i];
                end
                sent_len   <= next_sent_len;
                step_count <= step_count + 1;
                state      <= S_FIND_VAR;
              end else begin
                // length overflow: try next rule
                rule_idx   <= rule_idx + 1;
              end
            end else begin
              // head not match: try next rule
              rule_idx <= rule_idx + 1;
            end
          end
        end

        // Check if we have a final all-terminal string equal to substring
        S_CHECK_RESULT: begin
          if (sentential_matches_substring(sentential, sent_len,
                                           curr_start, curr_len,
                                           text_line)) begin
            match_success <= 1'b1;
            // Capture longest_substr (curr_len from curr_start)
            for (i = 0; i < MAX_LEN; i++) begin
              if (i < curr_len)
                longest_substr[i*CHAR_W +: CHAR_W]
                  <= get_text_char(text_line, curr_start + i);
              else
                longest_substr[i*CHAR_W +: CHAR_W] <= {CHAR_W{1'b0}};
            end
            valid <= (curr_len != 0);
            done  <= 1'b1;
            state <= S_DONE;
          end else begin
            // not final or no match
            if (step_count >= MAX_STEPS) begin
              // give up on this substring
              state <= S_NEXT_SUBSTR;
            end else begin
              state <= S_NEXT_STEP;
            end
          end
        end

        // Prepare for another derivation step when no conclusive result
        S_NEXT_STEP: begin
          step_count <= step_count + 1;
          if (step_count >= MAX_STEPS) begin
            state <= S_NEXT_SUBSTR;
          end else begin
            state <= S_FIND_VAR;
          end
        end

        // Move to next substring when current (len,start) failed
        S_NEXT_SUBSTR: begin
          if (curr_start + 1 <= (MAX_LEN - curr_len)) begin
            // next start for same length
            curr_start <= curr_start + 1;
            state      <= S_INIT_SUBSTR;
          end else begin
            // move to next shorter length
            if (curr_len > 1) begin
              curr_len   <= curr_len - 1;
              curr_start <= 0;
              state      <= S_INIT_SUBSTR;
            end else begin
              // length 1 exhausted -> no match
              longest_substr <= {96{1'b0}};
              valid          <= 1'b0;
              done           <= 1'b1;
              state          <= S_DONE;
            end
          end
        end

        S_DONE: begin
          // Hold outputs stable until next start
          if (start) begin
            // restart search
            match_success <= 1'b0;
            done          <= 1'b0;
            valid         <= 1'b0;
            curr_len      <= MAX_LEN;
            curr_start    <= 0;
            state         <= S_INIT_SUBSTR;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule