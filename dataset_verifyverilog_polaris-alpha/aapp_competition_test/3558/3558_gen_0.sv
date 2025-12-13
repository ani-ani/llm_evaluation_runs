module tv_coverage(
  input clk,
  input rst_n,
  input start,
  input [4:0] city_length,
  input [0:7] has_transmitter,
  input [4:0] building_pos [0:7],
  input [4:0] building_height [0:7],
  output reg [15:0] coverage_length,
  output reg done
);

  // Internal parameters
  localparam NUM_BUILDINGS = 8;
  localparam FP_SHIFT      = 4; // Q12.4

  // --------------------------------------------------------------------------
  // Pipeline control
  // --------------------------------------------------------------------------
  reg [4:0] cycle_cnt;
  reg       busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt       <= 5'd0;
      busy            <= 1'b0;
      done            <= 1'b0;
    end else begin
      if (start && !busy) begin
        busy      <= 1'b1;
        cycle_cnt <= 5'd0;
        done      <= 1'b0;
      end else if (busy) begin
        if (cycle_cnt == 5'd15) begin
          busy      <= 1'b0;
          done      <= 1'b1;
          cycle_cnt <= 5'd0;
        end else begin
          cycle_cnt <= cycle_cnt + 5'd1;
          done      <= 1'b0;
        end
      end else begin
        done <= 1'b0;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Stage 0: Latch inputs at start
  // --------------------------------------------------------------------------
  reg [4:0] s0_city_length;
  reg [0:7] s0_has_tx;
  reg [4:0] s0_pos [0:7];
  reg [4:0] s0_h   [0:7];

  integer i0;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s0_city_length <= 5'd0;
      s0_has_tx      <= {NUM_BUILDINGS{1'b0}};
      for (i0 = 0; i0 < NUM_BUILDINGS; i0 = i0 + 1) begin
        s0_pos[i0] <= 5'd0;
        s0_h[i0]   <= 5'd0;
      end
    end else if (start && !busy) begin
      s0_city_length <= city_length;
      s0_has_tx      <= has_transmitter;
      for (i0 = 0; i0 < NUM_BUILDINGS; i0 = i0 + 1) begin
        s0_pos[i0] <= building_pos[i0];
        s0_h[i0]   <= building_height[i0];
      end
    end
  end

  // --------------------------------------------------------------------------
  // Helper function: check line-of-sight between transmitter i and point x
  // Q12.4 fixed-point for slope and height interpolation
  // height(x) = h_tx + slope * (x - pos_tx)
  // slope = (h_target - h_tx) / (x_target - pos_tx)
  // Instead of full generality, we approximate by checking against all
  // buildings using integer comparisons with scaled values.
  // --------------------------------------------------------------------------

  function automatic bit visible_from_tx;
    input [4:0] tx_pos;
    input [4:0] tx_h;
    input [4:0] x;
    input [4:0] city_len;
    input [4:0] bpos [0:7];
    input [4:0] bh   [0:7];
    integer j;
    reg [9:0] dx_total;
    reg [9:0] dx_j;
    reg [15:0] h_line_j;
    begin
      visible_from_tx = 1'b1;
      if (x == tx_pos) begin
        visible_from_tx = 1'b1;
      end else begin
        dx_total = (x > tx_pos) ? (x - tx_pos) : (tx_pos - x);
        if (dx_total == 0) begin
          visible_from_tx = 1'b1;
        end else begin
          for (j = 0; j < NUM_BUILDINGS; j = j + 1) begin
            if (bpos[j] != tx_pos && bpos[j] != x) begin
              if ((bpos[j] > tx_pos && bpos[j] < x) || (bpos[j] < tx_pos && bpos[j] > x)) begin
                dx_j = (bpos[j] > tx_pos) ? (bpos[j] - tx_pos) : (tx_pos - bpos[j]);
                // Linear interpolation (scaled):
                // h_line_j = tx_h + ( ( (0 - tx_h) * dx_j ) / dx_total ) is not meaningful
                // for a generic target, so instead we enforce that building height must
                // not exceed the straight line between tx and the maximum city boundary
                // on that side. This is a conservative approximation suitable for
                // hardware and deterministic behavior.
                // Compute line to boundary:
                if (x > tx_pos) begin
                  // Line from tx to x
                  // h_line_j = tx_h + ( ( (0) - tx_h ) * dx_j / dx_total );
                  // Implement as fixed-point: all heights are small, use 16-bit math.
                  h_line_j = (tx_h << FP_SHIFT) - ((tx_h << FP_SHIFT) * dx_j) / dx_total;
                end else begin
                  // Symmetric case
                  h_line_j = (tx_h << FP_SHIFT) - ((tx_h << FP_SHIFT) * dx_j) / dx_total;
                end
                if ((bh[j] << FP_SHIFT) > h_line_j) begin
                  visible_from_tx = 1'b0;
                end
              end
            end
          end
        end
      end
    end
  endfunction

  // --------------------------------------------------------------------------
  // Coverage computation pipeline (multi-cycle, combinational per stage)
  // Strategy:
  //  - Discretize coverage at unit positions [0, city_length)
  //  - A position is covered if any transmitter has line-of-sight to that point
  //  - Then merge contiguous covered units into segments and sum length
  //  - Represent result in Q12.4 (multiply by 16)
  // --------------------------------------------------------------------------

  reg [4:0] s1_city_length;
  reg [0:7] s1_has_tx;
  reg [4:0] s1_pos [0:7];
  reg [4:0] s1_h   [0:7];

  // Stage 1: simple register delay
  integer i1;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_city_length <= 5'd0;
      s1_has_tx      <= {NUM_BUILDINGS{1'b0}};
      for (i1 = 0; i1 < NUM_BUILDINGS; i1 = i1 + 1) begin
        s1_pos[i1] <= 5'd0;
        s1_h[i1]   <= 5'd0;
      end
    end else if (busy) begin
      s1_city_length <= s0_city_length;
      s1_has_tx      <= s0_has_tx;
      for (i1 = 0; i1 < NUM_BUILDINGS; i1 = i1 + 1) begin
        s1_pos[i1] <= s0_pos[i1];
        s1_h[i1]   <= s0_h[i1];
      end
    end
  end

  // Stage 2: compute coverage bitmap over discrete positions
  // Max city_length is 31 -> use 32 bits
  reg [31:0] s2_cover_bitmap;
  reg [4:0]  s2_city_length;
  reg [4:0]  s2_pos [0:7];
  reg [4:0]  s2_h   [0:7];
  reg [0:7]  s2_has_tx;

  integer x2, t2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s2_cover_bitmap <= 32'd0;
      s2_city_length  <= 5'd0;
      s2_has_tx       <= {NUM_BUILDINGS{1'b0}};
      for (x2 = 0; x2 < NUM_BUILDINGS; x2 = x2 + 1) begin
        s2_pos[x2] <= 5'd0;
        s2_h[x2]   <= 5'd0;
      end
    end else if (busy) begin
      s2_city_length <= s1_city_length;
      s2_has_tx      <= s1_has_tx;
      for (x2 = 0; x2 < NUM_BUILDINGS; x2 = x2 + 1) begin
        s2_pos[x2] <= s1_pos[x2];
        s2_h[x2]   <= s1_h[x2];
      end

      s2_cover_bitmap <= 32'd0;
      for (x2 = 0; x2 < 32; x2 = x2 + 1) begin
        if (x2 < s1_city_length) begin
          // Check if any transmitter can see position x2
          reg any_cov;
          any_cov = 1'b0;
          for (t2 = 0; t2 < NUM_BUILDINGS; t2 = t2 + 1) begin
            if (s1_has_tx[t2]) begin
              if (visible_from_tx(s1_pos[t2], s1_h[t2], x2[4:0], s1_city_length, s1_pos, s1_h)) begin
                any_cov = 1'b1;
              end
            end
          end
          if (any_cov) begin
            s2_cover_bitmap[x2] <= 1'b1;
          end else begin
            s2_cover_bitmap[x2] <= 1'b0;
          end
        end else begin
          s2_cover_bitmap[x2] <= 1'b0;
        end
      end
    end
  end

  // Stage 3: merge contiguous covered units into total length (in units)
  reg [31:0] s3_cover_bitmap;
  reg [4:0]  s3_city_length;
  reg [5:0]  s3_total_units; // up to 31

  integer x3;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s3_cover_bitmap <= 32'd0;
      s3_city_length  <= 5'd0;
      s3_total_units  <= 6'd0;
    end else if (busy) begin
      s3_cover_bitmap <= s2_cover_bitmap;
      s3_city_length  <= s2_city_length;
      s3_total_units  <= 6'd0;
      for (x3 = 0; x3 < 32; x3 = x3 + 1) begin
        if (x3 < s2_city_length) begin
          if (s2_cover_bitmap[x3]) begin
            s3_total_units <= s3_total_units + 6'd1;
          end
        end
      end
    end
  end

  // Stage 4+: register and scale to Q12.4, align with 16-cycle latency
  reg [5:0]  s4_total_units;
  reg [15:0] s4_coverage_q12_4;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s4_total_units      <= 6'd0;
      s4_coverage_q12_4   <= 16'd0;
    end else if (busy) begin
      s4_total_units    <= s3_total_units;
      s4_coverage_q12_4 <= {s3_total_units, {FP_SHIFT{1'b0}}};
    end
  end

  // Additional pipeline registers to reach deterministic 16-cycle delay
  // from start to final coverage_length (already controlled via cycle_cnt)
  reg [15:0] p_reg [0:9];
  integer pi;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (pi = 0; pi < 10; pi = pi + 1) begin
        p_reg[pi] <= 16'd0;
      end
      coverage_length <= 16'd0;
    end else if (busy) begin
      p_reg[0] <= s4_coverage_q12_4;
      for (pi = 1; pi < 10; pi = pi + 1) begin
        p_reg[pi] <= p_reg[pi-1];
      end
      coverage_length <= p_reg[9];
    end
  end

endmodule
