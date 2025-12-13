module cloud_cover_comparator(
  input clk,
  input rst_n,
  input start,
  input [1:0] g_tcount,
  input [95:0] g_tri1,
  input [95:0] g_tri2,
  input [1:0] j_tcount,
  input [95:0] j_tri1,
  input [95:0] j_tri2,
  output reg result,
  output reg done
);

  // Triangle unpacking (Q8.8 coordinates)
  wire [15:0] g1_x1 = g_tri1[95:80];
  wire [15:0] g1_y1 = g_tri1[79:64];
  wire [15:0] g1_x2 = g_tri1[63:48];
  wire [15:0] g1_y2 = g_tri1[47:32];
  wire [15:0] g1_x3 = g_tri1[31:16];
  wire [15:0] g1_y3 = g_tri1[15:0];

  wire [15:0] g2_x1 = g_tri2[95:80];
  wire [15:0] g2_y1 = g_tri2[79:64];
  wire [15:0] g2_x2 = g_tri2[63:48];
  wire [15:0] g2_y2 = g_tri2[47:32];
  wire [15:0] g2_x3 = g_tri2[31:16];
  wire [15:0] g2_y3 = g_tri2[15:0];

  wire [15:0] j1_x1 = j_tri1[95:80];
  wire [15:0] j1_y1 = j_tri1[79:64];
  wire [15:0] j1_x2 = j_tri1[63:48];
  wire [15:0] j1_y2 = j_tri1[47:32];
  wire [15:0] j1_x3 = j_tri1[31:16];
  wire [15:0] j1_y3 = j_tri1[15:0];

  wire [15:0] j2_x1 = j_tri2[95:80];
  wire [15:0] j2_y1 = j_tri2[79:64];
  wire [15:0] j2_x2 = j_tri2[63:48];
  wire [15:0] j2_y2 = j_tri2[47:32];
  wire [15:0] j2_x3 = j_tri2[31:16];
  wire [15:0] j2_y3 = j_tri2[15:0];

  // Pipeline stage registers and control
  reg [2:0] cycle_cnt;
  reg start_d;

  // Signed interpretations
  function automatic signed [15:0] s16(input [15:0] v);
    s16 = v;
  endfunction

  // Stage 1: capture start and inputs snapshot
  reg [1:0] g_tcount_s1, j_tcount_s1;

  // Stage 2: compute y-differences
  reg signed [16:0] g1_dy2_3_s2, g1_dy3_1_s2, g1_dy1_2_s2;
  reg signed [16:0] g2_dy2_3_s2, g2_dy3_1_s2, g2_dy1_2_s2;
  reg signed [16:0] j1_dy2_3_s2, j1_dy3_1_s2, j1_dy1_2_s2;
  reg signed [16:0] j2_dy2_3_s2, j2_dy3_1_s2, j2_dy1_2_s2;
  reg [1:0] g_tcount_s2, j_tcount_s2;

  // Stage 3: multiplications (partial area terms)
  reg signed [31:0] g1_p1_s3, g1_p2_s3, g1_p3_s3;
  reg signed [31:0] g2_p1_s3, g2_p2_s3, g2_p3_s3;
  reg signed [31:0] j1_p1_s3, j1_p2_s3, j1_p3_s3;
  reg signed [31:0] j2_p1_s3, j2_p2_s3, j2_p3_s3;
  reg [1:0] g_tcount_s3, j_tcount_s3;

  // Stage 4: sum and abs to Q16.16 areas, then accumulate sums
  reg [31:0] g1_area_s4, g2_area_s4;
  reg [31:0] j1_area_s4, j2_area_s4;
  reg [31:0] g_area_sum_s4, j_area_sum_s4;
  reg [1:0] g_tcount_s4, j_tcount_s4;

  // Stage 5: final outputs
  reg [31:0] g_area_sum_s5, j_area_sum_s5;
  reg [1:0] g_tcount_s5, j_tcount_s5;

  // FSM-less 5-cycle pipeline control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt      <= 3'd0;
      start_d        <= 1'b0;
      done           <= 1'b0;
      result         <= 1'b0;
      g_tcount_s1    <= 2'd0;
      j_tcount_s1    <= 2'd0;
      g_tcount_s2    <= 2'd0;
      j_tcount_s2    <= 2'd0;
      g_tcount_s3    <= 2'd0;
      j_tcount_s3    <= 2'd0;
      g_tcount_s4    <= 2'd0;
      j_tcount_s4    <= 2'd0;
      g_tcount_s5    <= 2'd0;
      j_tcount_s5    <= 2'd0;
      g_area_sum_s4  <= 32'd0;
      j_area_sum_s4  <= 32'd0;
      g_area_sum_s5  <= 32'd0;
      j_area_sum_s5  <= 32'd0;
      g1_dy2_3_s2    <= 17'sd0;
      g1_dy3_1_s2    <= 17'sd0;
      g1_dy1_2_s2    <= 17'sd0;
      g2_dy2_3_s2    <= 17'sd0;
      g2_dy3_1_s2    <= 17'sd0;
      g2_dy1_2_s2    <= 17'sd0;
      j1_dy2_3_s2    <= 17'sd0;
      j1_dy3_1_s2    <= 17'sd0;
      j1_dy1_2_s2    <= 17'sd0;
      j2_dy2_3_s2    <= 17'sd0;
      j2_dy3_1_s2    <= 17'sd0;
      j2_dy1_2_s2    <= 17'sd0;
      g1_p1_s3       <= 32'sd0;
      g1_p2_s3       <= 32'sd0;
      g1_p3_s3       <= 32'sd0;
      g2_p1_s3       <= 32'sd0;
      g2_p2_s3       <= 32'sd0;
      g2_p3_s3       <= 32'sd0;
      j1_p1_s3       <= 32'sd0;
      j1_p2_s3       <= 32'sd0;
      j1_p3_s3       <= 32'sd0;
      j2_p1_s3       <= 32'sd0;
      j2_p2_s3       <= 32'sd0;
      j2_p3_s3       <= 32'sd0;
      g1_area_s4     <= 32'd0;
      g2_area_s4     <= 32'd0;
      j1_area_s4     <= 32'd0;
      j2_area_s4     <= 32'd0;
    end else begin
      // Edge detect start
      start_d <= start;

      // Pipeline control: start new operation on rising edge of start
      if (start && !start_d) begin
        cycle_cnt <= 3'd1;
        done      <= 1'b0;
      end else if (cycle_cnt != 3'd0) begin
        cycle_cnt <= cycle_cnt + 3'd1;
        if (cycle_cnt == 3'd5) begin
          cycle_cnt <= 3'd0; // complete
        end
      end

      // Default done low, assert only on final stage when active
      if (cycle_cnt == 3'd5) begin
        done <= 1'b1;
      end else begin
        if (!(start && !start_d)) begin
          done <= 1'b0;
        end
      end

      // Stage 1: latch tcounts
      if (start && !start_d) begin
        g_tcount_s1 <= g_tcount;
        j_tcount_s1 <= j_tcount;
      end

      // Stage 2: compute y differences (from stage1 snapshot of coordinates implicitly)
      if (cycle_cnt == 3'd1) begin
        g_tcount_s2 <= g_tcount_s1;
        j_tcount_s2 <= j_tcount_s1;

        g1_dy2_3_s2 <= s16(g1_y2) - s16(g1_y3);
        g1_dy3_1_s2 <= s16(g1_y3) - s16(g1_y1);
        g1_dy1_2_s2 <= s16(g1_y1) - s16(g1_y2);

        g2_dy2_3_s2 <= s16(g2_y2) - s16(g2_y3);
        g2_dy3_1_s2 <= s16(g2_y3) - s16(g2_y1);
        g2_dy1_2_s2 <= s16(g2_y1) - s16(g2_y2);

        j1_dy2_3_s2 <= s16(j1_y2) - s16(j1_y3);
        j1_dy3_1_s2 <= s16(j1_y3) - s16(j1_y1);
        j1_dy1_2_s2 <= s16(j1_y1) - s16(j1_y2);

        j2_dy2_3_s2 <= s16(j2_y2) - s16(j2_y3);
        j2_dy3_1_s2 <= s16(j2_y3) - s16(j2_y1);
        j2_dy1_2_s2 <= s16(j2_y1) - s16(j2_y2);
      end

      // Stage 3: multiplications
      if (cycle_cnt == 3'd2) begin
        g_tcount_s3 <= g_tcount_s2;
        j_tcount_s3 <= j_tcount_s2;

        g1_p1_s3 <= s16(g1_x1) * g1_dy2_3_s2;
        g1_p2_s3 <= s16(g1_x2) * g1_dy3_1_s2;
        g1_p3_s3 <= s16(g1_x3) * g1_dy1_2_s2;

        g2_p1_s3 <= s16(g2_x1) * g2_dy2_3_s2;
        g2_p2_s3 <= s16(g2_x2) * g2_dy3_1_s2;
        g2_p3_s3 <= s16(g2_x3) * g2_dy1_2_s2;

        j1_p1_s3 <= s16(j1_x1) * j1_dy2_3_s2;
        j1_p2_s3 <= s16(j1_x2) * j1_dy3_1_s2;
        j1_p3_s3 <= s16(j1_x3) * j1_dy1_2_s2;

        j2_p1_s3 <= s16(j2_x1) * j2_dy2_3_s2;
        j2_p2_s3 <= s16(j2_x2) * j2_dy3_1_s2;
        j2_p3_s3 <= s16(j2_x3) * j2_dy1_2_s2;
      end

      // Stage 4: sum, abs, accumulate areas
      if (cycle_cnt == 3'd3) begin
        g_tcount_s4 <= g_tcount_s3;
        j_tcount_s4 <= j_tcount_s3;

        // Raw sums (Q16.16 before /2 is ignored per problem statement)
        // Compute absolute values
        begin : g1_area_block
          reg signed [31:0] sum;
          sum = g1_p1_s3 + g1_p2_s3 + g1_p3_s3;
          g1_area_s4 <= (sum[31]) ? (~sum + 32'd1) : sum;
        end
        begin : g2_area_block
          reg signed [31:0] sum;
          sum = g2_p1_s3 + g2_p2_s3 + g2_p3_s3;
          g2_area_s4 <= (sum[31]) ? (~sum + 32'd1) : sum;
        end
        begin : j1_area_block
          reg signed [31:0] sum;
          sum = j1_p1_s3 + j1_p2_s3 + j1_p3_s3;
          j1_area_s4 <= (sum[31]) ? (~sum + 32'd1) : sum;
        end
        begin : j2_area_block
          reg signed [31:0] sum;
          sum = j2_p1_s3 + j2_p2_s3 + j2_p3_s3;
          j2_area_s4 <= (sum[31]) ? (~sum + 32'd1) : sum;
        end

        // Conditional accumulation based on triangle counts
        // g_tcount: 0=no tri,1=tri1,2=tri1+tri2 (per problem 0-2)
        case (g_tcount_s3)
          2'd0: g_area_sum_s4 <= 32'd0;
          2'd1: g_area_sum_s4 <= g1_area_s4; // will be from updated g1_area_s4 within cycle
          default: g_area_sum_s4 <= g1_area_s4 + g2_area_s4;
        endcase

        case (j_tcount_s3)
          2'd0: j_area_sum_s4 <= 32'd0;
          2'd1: j_area_sum_s4 <= j1_area_s4;
          default: j_area_sum_s4 <= j1_area_s4 + j2_area_s4;
        endcase
      end

      // Stage 5: latch sums and counts, compute result
      if (cycle_cnt == 3'd4) begin
        g_tcount_s5   <= g_tcount_s4;
        j_tcount_s5   <= j_tcount_s4;
        g_area_sum_s5 <= g_area_sum_s4;
        j_area_sum_s5 <= j_area_sum_s4;

        if ((g_tcount_s4 == j_tcount_s4) && (g_area_sum_s4 == j_area_sum_s4)) begin
          result <= 1'b1;
        end else begin
          result <= 1'b0;
        end
      end

      // When not active, hold result (or could clear; spec doesn't require)
      if (cycle_cnt == 3'd0 && !(start && !start_d)) begin
        // keep last result
      end
    end
  end

endmodule