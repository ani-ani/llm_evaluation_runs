module string_matcher (
  input clk,
  input rst_n,
  input [511:0] text,
  input [63:0] pattern,
  input start,
  output reg [63:0] matched_pattern,
  output reg [5:0] start_idx,
  output reg [5:0] end_idx,
  output reg done,
  output reg found
);

  reg start_prev;
  wire start_rising;
  reg processing;
  reg [511:0] text_reg;
  reg [63:0] pattern_reg;
  
  logic [56:0] match_flags;
  logic found_temp;
  logic [5:0] match_index;
  
  reg found_result;
  reg [5:0] start_idx_result, end_idx_result;
  reg done_next;

  // Edge detection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_prev <= 0;
    end else begin
      start_prev <= start;
    end
  end
  
  assign start_rising = start && !start_prev;

  // Capture inputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 0;
      text_reg <= 0;
      pattern_reg <= 0;
    end else begin
      if (start_rising) begin
        processing <= 1;
        text_reg <= text;
        pattern_reg <= pattern;
      end else begin
        processing <= 0;
      end
    end
  end

  // Combinational matching
  always_comb begin
    match_flags = '0;
    for (int i=0; i<=56; i++) begin
      match_flags[i] = (text_reg[i*8 +:64] == pattern_reg);
    end
  end

  // Priority encoder
  always_comb begin
    found_temp = 0;
    match_index = 0;
    for (int i=0; i<=56; i++) begin
      if (match_flags[i] && !found_temp) begin
        found_temp = 1;
        match_index = i;
      end
    end
  end

  // Registered results
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      found_result <= 0;
      start_idx_result <= 0;
      end_idx_result <= 0;
      done_next <= 0;
    end else begin
      if (processing) begin
        found_result <= found_temp;
        start_idx_result <= match_index;
        end_idx_result <= match_index + 6'd8;
        done_next <= 1;
      end else begin
        done_next <= 0;
      end
    end
  end

  // Outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      found <= 0;
      start_idx <= 0;
      end_idx <= 0;
      matched_pattern <= 0;
    end else begin
      done <= done_next;
      if (done_next) begin
        found <= found_result;
        start_idx <= start_idx_result;
        end_idx <= end_idx_result;
        matched_pattern <= pattern_reg;
      end
    end
  end

endmodule