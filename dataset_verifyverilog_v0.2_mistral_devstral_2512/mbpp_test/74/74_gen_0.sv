module pattern_checker (
  input clk,
  input rst_n,
  input start,
  input [63:0] colors_i,
  input [63:0] patterns_i,
  input [2:0] index,
  input valid,
  input last,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COLLECT,
    VERIFY,
    COMPLETE
  } state_t;

  state_t state, next_state;

  // Storage for pattern-color pairs
  logic [63:0] pattern_mem [0:7];
  logic [63:0] color_mem [0:7];
  logic [7:0] pattern_count;

  // Tracking structures
  logic [63:0] pattern_to_color [0:7];
  logic [63:0] color_to_pattern [0:7];
  logic [7:0] pattern_used;
  logic [7:0] color_used;

  // Temporary variables
  logic [7:0] i, j;
  logic pattern_match;
  logic color_match;
  logic mismatch_found;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      pattern_count <= 0;
      pattern_used <= 0;
      color_used <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        pattern_mem[i] <= 0;
        color_mem[i] <= 0;
        pattern_to_color[i] <= 0;
        color_to_pattern[i] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end
      COLLECT: begin
        if (last && valid) next_state = VERIFY;
      end
      VERIFY: begin
        next_state = COMPLETE;
      end
      COMPLETE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Collection logic
  always @(posedge clk) begin
    if (!rst_n && state == COLLECT && valid) begin
      pattern_mem[index] <= patterns_i;
      color_mem[index] <= colors_i;
      if (last) pattern_count <= index + 1;
    end
  end

  // Verification logic
  always @(posedge clk) begin
    if (!rst_n && state == VERIFY) begin
      // Initialize tracking structures
      pattern_used <= 0;
      color_used <= 0;
      mismatch_found <= 0;

      // Check all pairs
      for (i = 0; i < pattern_count; i = i + 1) begin
        pattern_match <= 0;
        color_match <= 0;

        // Check if pattern already seen
        for (j = 0; j < i; j = j + 1) begin
          if (pattern_mem[i] == pattern_mem[j]) begin
            pattern_match <= 1;
            if (color_mem[i] != color_mem[j]) begin
              mismatch_found <= 1;
            end
          end
        end

        // If new pattern, check color uniqueness
        if (!pattern_match) begin
          for (j = 0; j < i; j = j + 1) begin
            if (color_mem[i] == color_mem[j]) begin
              color_match <= 1;
              if (pattern_mem[i] != pattern_mem[j]) begin
                mismatch_found <= 1;
              end
            end
          end
        end
      end

      // Set result
      result <= mismatch_found;
      done <= 1;
    end
  end

  // Reset done signal after completion
  always @(posedge clk) begin
    if (!rst_n && state == COMPLETE && !start) begin
      done <= 0;
    end
  end

endmodule