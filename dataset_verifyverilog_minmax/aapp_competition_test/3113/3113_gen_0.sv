module cloud_cover_comparator(
  input clk,                // system clock
  input rst_n,              // active-low reset
  input start,              // start computation
  input [1:0] g_tcount,     // Garry's triangle count (0-2)
  input [95:0] g_tri1,      // Garry's triangle1 {x1[15:8],x1[7:0], y1[15:8],...} Q8.8 fixed-point
  input [95:0] g_tri2,      // Garry's triangle2 (same format)
  input [1:0] j_tcount,     // Jerry's triangle count (0-2)
  input [95:0] j_tri1,      // Jerry's triangle1
  input [95:0] j_tri2,      // Jerry's triangle2
  output reg result,        // 1=yes, 0=no
  output reg done           // computation complete
);

  // Internal signals and registers
  reg [2:0] lat_cnt;
  reg [1:0] g_tcount_r, j_tcount_r;
  reg signed [15:0] g_x1, g_y1, g_x2, g_y2, g_x3, g_y3;
  reg signed [15:0] j_x1, j_y1, j_x2, j_y2, j_x3, j_y3;
  reg signed [31:0] g_p1, g_p2, g_p3, g_s1, g_s2, g_s3, g_a1, g_a2;
  reg signed [31:0] j_p1, j_p2, j_p3, j_s1, j_s2, j_s3, j_a1, j_a2;
  reg signed [63:0] g_area_sum, j_area_sum;
  reg g_done_int, j_done_int;
  reg cmp_valid;

  // Stage boundaries (combinational between flops)
  wire signed [31:0] g_term1, g_term2, g_term3, g_area1_raw, g_area2_raw;
  wire signed [31:0] j_term1, j_term2, j_term3, j_area1_raw, j_area2_raw;
  wire signed [31:0] g_area1, g_area2, j_area1, j_area2;
  wire signed [63:0] g_sum_raw, j_sum_raw;
  wire g_match, j_match;
  wire g_count_eq, g_area_eq;

  // Convert two bytes (big-endian) into signed 16-bit Q8.8 coordinate
  function [15:0] bytes_to_s16;
    input [15:0] bytes; // {byte_hi, byte_lo}
    bytes_to_s16 = $signed(bytes);
  endfunction

  // Garry: Stage 1 (cycle 1)
  always @(posedge clk) begin
    if (!rst_n) begin
      g_tcount_r <= 2'b0;
      g_x1 <= 16'sb0; g_y1 <= 16'sb0; g_x2 <= 16'sb0; g_y2 <= 16'sb0; g_x3 <= 16'sb0; g_y3 <= 16'sb0;
    end else if (start) begin
      g_tcount_r <= g_tcount;
      g_x1 <= bytes_to_s16({g_tri1[95:88], g_tri1[87:80]}); g_y1 <= bytes_to_s16({g_tri1[79:72], g_tri1[71:64]});
      g_x2 <= bytes_to_s16({g_tri1[63:56], g_tri1[55:48]}); g_y2 <= bytes_to_s16({g_tri1[47:40], g_tri1[39:32]});
      g_x3 <= bytes_to_s16({g_tri1[31:24], g_tri1[23:16]}); g_y3 <= bytes_to_s16({g_tri1[15:8],  g_tri1[7:0]});
    end
  end

  // Jerry: Stage 1 (cycle 1)
  always @(posedge clk) begin
    if (!rst_n) begin
      j_tcount_r <= 2'b0;
      j_x1 <= 16'sb0; j_y1 <= 16'sb0; j_x2 <= 16'sb0; j_y2 <= 16'sb0; j_x3 <= 16'sb0; j_y3 <= 16'sb0;
    end else if (start) begin
      j_tcount_r <= j_tcount;
      j_x1 <= bytes_to_s16({j_tri1[95:88], j_tri1[87:80]}); j_y1 <= bytes_to_s16({j_tri1[79:72], j_tri1[71:64]});
      j_x2 <= bytes_to_s16({j_tri1[63:56], j_tri1[55:48]}); j_y2 <= bytes_to_s16({j_tri1[47:40], j_tri1[39:32]});
      j_x3 <= bytes_to_s16({j_tri1[31:24], j_tri1[23:16]}); j_y3 <= bytes_to_s16({j_tri1[15:8],  j_tri1[7:0]});
    end
  end

  // Garry: Stage 2 (cycle 2)
  always @(posedge clk) begin
    if (!rst_n) begin
      g_p1 <= 32'sb0; g_p2 <= 32'sb0; g_p3 <= 32'sb0;
    end else if (start) begin
      // x1*(y2 - y3)  [Q8.8 * Q8.8 => Q16.16]
      g_p1 <= $signed(g_x1) * $signed(g_y2 - g_y3);
      // x2*(y3 - y1)
      g_p2 <= $signed(g_x2) * $signed(g_y3 - g_y1);
      // x3*(y1 - y2)
      g_p3 <= $signed(g_x3) * $signed(g_y1 - g_y2);
    end
  end

  // Jerry: Stage 2 (cycle 2)
  always @(posedge clk) begin
    if (!rst_n) begin
      j_p1 <= 32'sb0; j_p2 <= 32'sb0; j_p3 <= 32'sb0;
    end else if (start) begin
      j_p1 <= $signed(j_x1) * $signed(j_y2 - j_y3);
      j_p2 <= $signed(j_x2) * $signed(j_y3 - j_y1);
      j_p3 <= $signed(j_x3) * $signed(j_y1 - j_y2);
    end
  end

  // Garry: Stage 3 (cycle 3)
  always @(posedge clk) begin
    if (!rst_n) begin
      g_s1 <= 32'sb0; g_s2 <= 32'sb0; g_s3 <= 32'sb0;
    end else if (start) begin
      g_s1 <= g_p1;
      g_s2 <= g_p2;
      g_s3 <= g_p3;
    end
  end

  // Jerry: Stage 3 (cycle 3)
  always @(posedge clk) begin
    if (!rst_n) begin
      j_s1 <= 32'sb0; j_s2 <= 32'sb0; j_s3 <= 32'sb0;
    end else if (start) begin
      j_s1 <= j_p1;
      j_s2 <= j_p2;
      j_s3 <= j_p3;
    end
  end

  // Garry: Stage 4 (cycle 4) -> area = |sum(terms)| >> 1, clamp to 32-bit
  always @(posedge clk) begin
    if (!rst_n) begin
      g_a1 <= 32'sb0; g_a2 <= 32'sb0; g_done_int <= 1'b0;
    end else if (start) begin
      // Triangle 1 area
      g_a1 <= (g_s1 + g_s2 + g_s3[31:0] >= 0) ? ((g_s1 + g_s2 + g_s3[31:0]) >> 1) : (-((-$signed(g_s1 + g_s2 + g_s3[31:0])) >> 1));
      // Triangle 2 area: if tcount >= 2, decode g_tri2 in this cycle and compute; else 0
      if (g_tcount_r >= 2) begin
        g_a2 <= g_area2_raw;
      end else begin
        g_a2 <= 32'sb0;
      end
      g_done_int <= 1'b1;
    end else begin
      g_done_int <= 1'b0;
    end
  end

  // Jerry: Stage 4 (cycle 4) -> area = |sum(terms)| >> 1
  always @(posedge clk) begin
    if (!rst_n) begin
      j_a1 <= 32'sb0; j_a2 <= 32'sb0; j_done_int <= 1'b0;
    end else if (start) begin
      j_a1 <= (j_s1 + j_s2 + j_s3[31:0] >= 0) ? ((j_s1 + j_s2 + j_s3[31:0]) >> 1) : (-((-$signed(j_s1 + j_s2 + j_s3[31:0])) >> 1));
      if (j_tcount_r >= 2) begin
        j_a2 <= j_area2_raw;
      end else begin
        j_a2 <= 32'sb0;
      end
      j_done_int <= 1'b1;
    end else begin
      j_done_int <= 1'b0;
    end
  end

  // Garry: Stage 5 (cycle 5) -> sum areas
  always @(posedge clk) begin
    if (!rst_n) begin
      g_area_sum <= 64'sb0;
    end else if (start) begin
      g_area_sum <= $signed(g_a1) + $signed(g_a2);
    end
  end

  // Jerry: Stage 5 (cycle 5) -> sum areas
  always @(posedge clk) begin
    if (!rst_n) begin
      j_area_sum <= 64'sb0;
    end else if (start) begin
      j_area_sum <= $signed(j_a1) + $signed(j_a2);
    end
  end

  // Latency counter (5 cycles, done pulses on cycle 5)
  always @(posedge clk) begin
    if (!rst_n) lat_cnt <= 3'b0;
    else if (start) lat_cnt <= 3'd5;  // count down to 0
    else if (lat_cnt != 3'b0) lat_cnt <= lat_cnt - 1;
  end

  assign done = (lat_cnt == 3'd0) & start;

  // Triangle 2 area computation (for g_tri2 and j_tri2), combinational within cycle 4
  assign g_area2_raw = g_area_from_bytes(g_tri2);
  assign j_area2_raw = j_area_from_bytes(j_tri2);

  function [31:0] g_area_from_bytes;
    input [95:0] tri;
    reg signed [15:0] x1, y1, x2, y2, x3, y3;
    reg signed [31:0] t1, t2, t3;
    reg signed [31:0] s;
  begin
    x1 = bytes_to_s16({tri[95:88], tri[87:80]}); y1 = bytes_to_s16({tri[79:72], tri[71:64]});
    x2 = bytes_to_s16({tri[63:56], tri[55:48]}); y2 = bytes_to_s16({tri[47:40], tri[39:32]});
    x3 = bytes_to_s16({tri[31:24], tri[23:16]}); y3 = bytes_to_s16({tri[15:8],  tri[7:0]});
    t1 = $signed(x1) * $signed(y2 - y3);
    t2 = $signed(x2) * $signed(y3 - y1);
    t3 = $signed(x3) * $signed(y1 - y2);
    s  = t1 + t2 + t3;
    g_area_from_bytes = (s >= 0) ? (s >> 1) : (-((-s) >> 1));
  end
  endfunction

  function [31:0] j_area_from_bytes;
    input [95:0] tri;
    reg signed [15:0] x1, y1, x2, y2, x3, y3;
    reg signed [31:0] t1, t2, t3;
    reg signed [31:0] s;
  begin
    x1 = bytes_to_s16({tri[95:88], tri[87:80]}); y1 = bytes_to_s16({tri[79:72], tri[71:64]});
    x2 = bytes_to_s16({tri[63:56], tri[55:48]}); y2 = bytes_to_s16({tri[47:40], tri[39:32]});
    x3 = bytes_to_s16({tri[31:24], tri[23:16]}); y3 = bytes_to_s16({tri[15:8],  tri[7:0]});
    t1 = $signed(x1) * $signed(y2 - y3);
    t2 = $signed(x2) * $signed(y3 - y1);
    t3 = $signed(x3) * $signed(y1 - y2);
    s  = t1 + t2 + t3;
    j_area_from_bytes = (s >= 0) ? (s >> 1) : (-((-s) >> 1));
  end
  endfunction

  // Comparison logic (valid in cycle 5 when done pulses)
  assign g_count_eq = (g_tcount_r == j_tcount_r);
  assign g_area_eq  = (g_area_sum == j_area_sum);
  assign g_match = g_count_eq & g_area_eq;

  always @(posedge clk) begin
    if (!rst_n) result <= 1'b0;
    else if (done) result <= g_match;
  end

endmodule
