module string_matcher(
  input clk,
  input rst_n,
  input [511:0] text,    // 64 chars (8-bit ASCII each)
  input [63:0] pattern,   // 8 chars (8-bit ASCII each)
  input start,
  output reg [63:0] matched_pattern,
  output reg [5:0] start_idx,
  output reg [5:0] end_idx,
  output reg done,
  output reg found
);

  // Internal signals for 2-cycle pipeline
  reg start_d;
  wire [63:0] start_idx_w;
  wire found_w;
  wire [5:0] end_idx_w;
  reg [5:0] start_idx_pipe;
  reg found_pipe;
  reg [5:0] end_idx_pipe;

  // Stage 1: compute first match index and whether a match was found
  // text[i +: 8] maps to characters at indices i..i+7 (8 characters)
  integer i;
  assign found_w = 1'b0;
  assign start_idx_w = 6'd0;
  assign end_idx_w = 6'd0;
  always @(*) begin
    found_w = 1'b0;
    start_idx_w = 6'd0;
    for (i = 0; i < 57; i = i + 1) begin
      if (text[i*8 +: 8] == pattern) begin
        found_w = 1'b1;
        start_idx_w = i[5:0];
        break;
      end
    end
  end
  assign end_idx_w = start_idx_w + 6'd8;

  // Pipeline stage 1 delay
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  // Pipeline stage 2 results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_idx_pipe <= 6'd0;
      found_pipe <= 1'b0;
      end_idx_pipe <= 6'd0;
    end else begin
      start_idx_pipe <= start_idx_w;
      found_pipe <= found_w;
      end_idx_pipe <= end_idx_w;
    end
  end

  // Output update: two cycles of 'done' following assertion of 'start'
  // Outputs are cleared when start is low; on match, they capture pipeline results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      matched_pattern <= 64'd0;
      start_idx <= 6'd0;
      end_idx <= 6'd0;
      found <= 1'b0;
      done <= 1'b0;
    end else begin
      if (!start) begin
        matched_pattern <= 64'd0;
        start_idx <= 6'd0;
        end_idx <= 6'd0;
        found <= 1'b0;
        done <= 1'b0;
      end else begin
        if (start_d) begin
          matched_pattern <= pattern;
          start_idx <= start_idx_pipe;
          end_idx <= end_idx_pipe;
          found <= found_pipe;
          done <= 1'b1;
        end else if (done) begin
          // Hold outputs steady during the second done cycle
          matched_pattern <= matched_pattern;
          start_idx <= start_idx;
          end_idx <= end_idx;
          found <= found;
          done <= 1'b0;
        end
      end
    end
  end

endmodule
