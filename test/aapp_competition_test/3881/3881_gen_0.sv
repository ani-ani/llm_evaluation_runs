module string_compressor(
  input clk,
  input rst_n,
  input start,
  output reg [15:0] result,
  output reg done
);

  // Parameter: string length n (2-6). Change as needed per test.
  parameter integer N = 6;

  // Alphabet size and encoding
  localparam int ALPH_SIZE = 6;          // symbols: 0..5 represent 'a'..'f'
  localparam int CHAR_W    = 3;          // log2(6) -> use 3 bits

  // Max states from N down to 1
  localparam int MAX_LEN = 6;            // fixed to 6 for hardware sizing

  // Maximum number of strings: 6^N (<= 6^6 = 46656)
  // 6^6 fits in 16 bits, so 16-bit counter is enough

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_EVAL_STR  = 3'd2,
    S_APPLY_ALL = 3'd3,
    S_NEXT_STEP = 3'd4,
    S_NEXT_STR  = 3'd5,
    S_DONE      = 3'd6
  } state_t;

  state_t state, next_state;

  // Current input string index (0 .. 6^N - 1)
  reg [15:0] str_index;
  reg [15:0] max_index;  // = 6^N - 1

  // Working buffer for current string symbols
  // buf[0]..buf[N-1] are valid; others ignored.
  reg [CHAR_W-1:0] buf [0:MAX_LEN-1];

  // Current effective length of string in buf
  reg [2:0] cur_len;

  // Compression step index (position of 2-char window)
  reg [2:0] step_pos;

  // Flag: whether any rule applied in the current full pass
  reg applied_any;

  // ROM: 36 rules (indexed 0..35), each 9 bits: [8:7] unused, [8:7] can stay 0
  // Format: {in1[2:0], in0[2:0], out[2:0]} = 9 bits
  // Hardcoded example rules for illustration; synth tools should map to ROM.
  // NOTE: Replace/extend contents as needed with real rules.
  localparam int RULE_COUNT = 36;
  reg [8:0] rule_rom [0:RULE_COUNT-1];

  // ROM initialization (example pattern, user to customize as needed)
  // Here we fill all 36 entries with distinct, deterministic content.
  // In synthesis, this becomes a fixed ROM.
  integer ri;
  initial begin
    // Default
    for (ri = 0; ri < RULE_COUNT; ri = ri + 1) begin
      rule_rom[ri] = 9'b0;
    end

    // Example hardcoded rules (placeholder):
    // rule 0: 'a''a' -> 'a'
    rule_rom[0]  = {3'd0, 3'd0, 3'd0};
    // rule 1: 'a''b' -> 'c'
    rule_rom[1]  = {3'd0, 3'd1, 3'd2};
    // rule 2: 'b''a' -> 'c'
    rule_rom[2]  = {3'd1, 3'd0, 3'd2};
    // rule 3: 'b''b' -> 'b'
    rule_rom[3]  = {3'd1, 3'd1, 3'd1};
    // Additional arbitrary but deterministic examples
    rule_rom[4]  = {3'd2, 3'd2, 3'd3};
    rule_rom[5]  = {3'd2, 3'd3, 3'd4};
    rule_rom[6]  = {3'd3, 3'd2, 3'd4};
    rule_rom[7]  = {3'd3, 3'd3, 3'd5};
    rule_rom[8]  = {3'd4, 3'd4, 3'd0};
    rule_rom[9]  = {3'd5, 3'd5, 3'd1};
    rule_rom[10] = {3'd0, 3'd2, 3'd1};
    rule_rom[11] = {3'd2, 3'd0, 3'd1};
    rule_rom[12] = {3'd0, 3'd3, 3'd2};
    rule_rom[13] = {3'd3, 3'd0, 3'd2};
    rule_rom[14] = {3'd1, 3'd2, 3'd3};
    rule_rom[15] = {3'd2, 3'd1, 3'd3};
    rule_rom[16] = {3'd1, 3'd3, 3'd4};
    rule_rom[17] = {3'd3, 3'd1, 3'd4};
    rule_rom[18] = {3'd2, 3'd4, 3'd5};
    rule_rom[19] = {3'd4, 3'd2, 3'd5};
    rule_rom[20] = {3'd2, 3'd5, 3'd0};
    rule_rom[21] = {3'd5, 3'd2, 3'd0};
    rule_rom[22] = {3'd3, 3'd4, 3'd1};
    rule_rom[23] = {3'd4, 3'd3, 3'd1};
    rule_rom[24] = {3'd3, 3'd5, 3'd2};
    rule_rom[25] = {3'd5, 3'd3, 3'd2};
    rule_rom[26] = {3'd4, 3'd5, 3'd3};
    rule_rom[27] = {3'd5, 3'd4, 3'd3};
    rule_rom[28] = {3'd0, 3'd4, 3'd4};
    rule_rom[29] = {3'd4, 3'd0, 3'd4};
    rule_rom[30] = {3'd0, 3'd5, 3'd5};
    rule_rom[31] = {3'd5, 3'd0, 3'd5};
    rule_rom[32] = {3'd1, 3'd4, 3'd0};
    rule_rom[33] = {3'd4, 3'd1, 3'd0};
    rule_rom[34] = {3'd1, 3'd5, 3'd2};
    rule_rom[35] = {3'd5, 3'd1, 3'd2};
  end

  // Combinational: decode rule for a given pair
  function automatic logic find_rule(
    input  [CHAR_W-1:0] in1,
    input  [CHAR_W-1:0] in0,
    output [CHAR_W-1:0] out
  );
    int i;
    logic match;
    match = 1'b0;
    out   = '0;
    for (i = 0; i < RULE_COUNT; i = i + 1) begin
      if (!match && rule_rom[i][8:6] == in1 && rule_rom[i][5:3] == in0) begin
        match = 1'b1;
        out   = rule_rom[i][2:0];
      end
    end
    return match;
  endfunction

  // Compute 6^N at runtime (simple combinational for small N)
  function automatic [15:0] pow6(input int n);
    int j;
    reg [15:0] r;
    begin
      r = 16'd1;
      for (j = 0; j < n; j = j + 1) begin
        r = r * 16'd6;
      end
      pow6 = r;
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_EVAL_STR;
      end
      S_EVAL_STR: begin
        // Immediately go to applying rules for this string
        next_state = S_APPLY_ALL;
      end
      S_APPLY_ALL: begin
        // We iterate over positions sequentially in clocked block
        // Stay here until we finish a full pass over string
        // Transition done in sequential always when step_pos completes
      end
      S_NEXT_STEP: begin
        // Decide whether to continue compressing or finalize this string
        if ((cur_len <= 3'd1) || (!applied_any)) begin
          next_state = S_NEXT_STR;
        end else begin
          next_state = S_APPLY_ALL;
        end
      end
      S_NEXT_STR: begin
        if (str_index == max_index) begin
          next_state = S_DONE;
        end else begin
          next_state = S_EVAL_STR;
        end
      end
      S_DONE: begin
        // Wait here until start deasserted and reasserted
        if (!start) next_state = S_IDLE;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      result    <= 16'd0;
      done      <= 1'b0;
      str_index <= 16'd0;
      max_index <= 16'd0;
      cur_len   <= 3'd0;
      step_pos  <= 3'd0;
      applied_any <= 1'b0;
      for (k = 0; k < MAX_LEN; k = k + 1) begin
        buf[k] <= {CHAR_W{1'b0}};
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done      <= 1'b0;
          result    <= 16'd0;
          str_index <= 16'd0;
          if (start) begin
            max_index <= pow6(N) - 16'd1;
          end
        end

        S_INIT: begin
          // Prepare for first string (index already 0)
          result      <= 16'd0;
          done        <= 1'b0;
          cur_len     <= N[2:0];
          applied_any <= 1'b0;
          step_pos    <= 3'd0;
          // Decode str_index (0) to base-6 digits -> all zeros (all 'a')
          for (k = 0; k < MAX_LEN; k = k + 1) begin
            if (k < N) buf[k] <= {CHAR_W{1'b0}};
            else       buf[k] <= {CHAR_W{1'b0}};
          end
        end

        S_EVAL_STR: begin
          // Load current str_index into buf as base-6 number (least significant digit at position 0)
          // Only N digits are used; remaining positions cleared
          reg [15:0] tmp;
          tmp = str_index;
          for (k = 0; k < MAX_LEN; k = k + 1) begin
            if (k < N) begin
              buf[k] <= tmp % 6;
              tmp    <= tmp / 6;
            end else begin
              buf[k] <= {CHAR_W{1'b0}};
            end
          end
          cur_len     <= N[2:0];
          applied_any <= 1'b0;
          step_pos    <= 3'd0;
        end

        S_APPLY_ALL: begin
          // For the current pass, apply at most one rule to the earliest matching pair.
          // We advance step_pos until we either apply a rule or exhaust positions.
          if (cur_len >= 3'd2) begin
            if (step_pos < (cur_len - 3'd1)) begin
              // Try match rule at (step_pos, step_pos+1)
              logic [CHAR_W-1:0] out_sym;
              logic match;
              match = find_rule(buf[step_pos], buf[step_pos+1], out_sym);
              if (match) begin
                // Apply compression: replace pair with out_sym at step_pos,
                // shift left remaining symbols, reduce length by 1.
                integer s;
                buf[step_pos] <= out_sym;
                for (s = step_pos + 1; s < MAX_LEN-1; s = s + 1) begin
                  if (s + 1 < cur_len)
                    buf[s] <= buf[s+1];
                  else
                    buf[s] <= {CHAR_W{1'b0}};
                end
                if (cur_len > 0)
                  cur_len <= cur_len - 3'd1;
                applied_any <= 1'b1;
                // After applying a rule, end this pass; move to NEXT_STEP
                step_pos <= 3'd0;
                state    <= S_NEXT_STEP; // override next_state for immediate sequencing
              end else begin
                // No rule at this position; move to next pair
                step_pos <= step_pos + 3'd1;
                // If about to exhaust positions without any match in this pass
                if ((step_pos + 3'd1) >= (cur_len - 3'd1)) begin
                  // Completed full pass; go to NEXT_STEP
                  step_pos <= 3'd0;
                  state    <= S_NEXT_STEP; // override
                end
              end
            end else begin
              // No more positions to check in this pass
              step_pos <= 3'd0;
              state    <= S_NEXT_STEP; // override
            end
          end else begin
            // Length < 2, nothing to apply
            step_pos <= 3'd0;
            state    <= S_NEXT_STEP; // override
          end
        end

        S_NEXT_STEP: begin
          // Decide to continue compressing or finalize this string handled in next_state
          // Nothing extra needed here; transitions handled combinationally.
        end

        S_NEXT_STR: begin
          // If final length is 1 and symbol is 'a' (0), increment result
          if (cur_len == 3'd1 && buf[0] == 3'd0) begin
            result <= result + 16'd1;
          end
          // Move to next string index if any
          if (str_index != max_index) begin
            str_index <= str_index + 16'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Hold result until reset or new start sequence
        end

        default: begin
          // Safe defaults
        end
      endcase
    end
  end

endmodule
