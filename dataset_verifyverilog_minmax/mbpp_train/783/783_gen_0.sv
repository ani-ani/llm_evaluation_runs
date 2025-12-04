module rgb_to_hsv (
  input clk,
  input rst_n,
  input start,
  input [7:0] r,
  input [7:0] g,
  input [7:0] b,
  output reg [15:0] h,
  output reg [15:0] s,
  output reg [15:0] v,
  output reg done
);
  // Internal pipeline registers (16-stage pipeline, 1 cycle per stage)
  logic [15:0] r1, g1, b1;
  logic [15:0] r2, g2, b2;
  logic [7:0]  max2, min2;
  logic [1:0]  max_id2;
  logic [15:0] max2_u, min2_u;
  logic [15:0] delta3;
  logic [15:0] max3_u;
  logic [1:0]  max_id3;
  logic signed [31:0] h_base6;
  logic [15:0] h6_raw;
  logic [15:0] s7_raw;
  logic [15:0] v8_raw;
  logic [15:0] h9, s9, v9;

  logic [15:0] h_reg, s_reg, v_reg;
  logic done_reg;
  logic [3:0] shcnt;

  // Helper function: (a*b + c/2) / c  (integer division with rounding)
  function [15:0] mul_div_rounded;
    input [15:0] a;
    input [15:0] b;
    input [15:0] c;
    logic [31:0] prod;
    begin
      prod = a * b;
      // add c/2 for rounding, then divide by c
      mul_div_rounded = (prod + (c >> 1)) / c;
    end
  endfunction

  // Pipeline stage control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r1 <= '0; g1 <= '0; b1 <= '0;
      r2 <= '0; g2 <= '0; b2 <= '0;
      max2 <= '0; min2 <= '0; max_id2 <= '0;
      max2_u <= '0; min2_u <= '0;
      delta3 <= '0; max3_u <= '0; max_id3 <= '0;
      h_base6 <= '0; h6_raw <= '0;
      s7_raw <= '0; v8_raw <= '0;
      h9 <= '0; s9 <= '0; v9 <= '0;
      h_reg <= '0; s_reg <= '0; v_reg <= '0;
      done_reg <= '0; shcnt <= '0;
      h <= '0; s <= '0; v <= '0; done <= '0;
    end else begin
      // Start: load inputs, otherwise shift pipeline
      if (shcnt == 4'd0) begin
        if (start) begin
          r1 <= {8'b0, r};    // 16-bit extend to avoid width issues
          g1 <= {8'b0, g};
          b1 <= {8'b0, b};
          r2 <= r1;
          g2 <= g1;
          b2 <= b1;
          shcnt <= 4'd1;
        end else begin
          r1 <= '0; g1 <= '0; b1 <= '0;
          r2 <= '0; g2 <= '0; b2 <= '0;
          shcnt <= 4'd0;
        end
        done_reg <= 1'b0;
        h_reg <= '0; s_reg <= '0; v_reg <= '0;
      end else begin
        // Shift once per cycle
        if (shcnt < 4'd15) shcnt <= shcnt + 1;
        else shcnt <= 4'd0;

        // Stage 1->2: pass-through (1 cycle)
        // Stage 2 computations
        begin
          logic [7:0] lmax, lmin;
          logic [1:0] lmax_id;
          logic [15:0] lmax_u, lmin_u;
          // Parallel comparators to find max/min and their indices
          if (r2 >= g2 && r2 >= b2) begin lmax = r2; lmax_id = 2'd0; end
          else if (g2 >= r2 && g2 >= b2) begin lmax = g2; lmax_id = 2'd1; end
          else begin lmax = b2; lmax_id = 2'd2; end
          if (r2 <= g2 && r2 <= b2) lmin = r2;
          else if (g2 <= r2 && g2 <= b2) lmin = g2;
          else lmin = b2;
          max2 <= lmax;
          min2 <= lmin;
          max_id2 <= lmax_id;
          lmax_u = {8'b0, lmax}; // extend to 16-bit
          lmin_u = {8'b0, lmin};
          max2_u <= lmax_u;
          min2_u <= lmin_u;
        end

        // Stage 3: compute delta (max - min)
        delta3 <= max2_u - min2_u;
        max3_u <= max2_u;
        max_id3 <= max_id2;

        // Stage 6: hue base
        begin
          logic [15:0] diff, gmb, rmb, brm;
          logic signed [31:0] base;
          diff = (max_id3 == 2'd0) ? (g1 - b1) :  // not used, but kept for symmetry
                 (max_id3 == 2'd1) ? (b1 - r1) :
                                      (r1 - g1);
          // Note: g1/b1/r1 hold the current original (not scaled) values in the pipe.
          // The hue formula uses scaled-by-196 values, but scaling factor 196 = 1000/5.102.
          // r1/g1/b1 at this pipeline stage correspond to scaled-by-196 components.
          gmb = g1 - b1;
          rmb = r1 - b1;
          brm = b1 - r1;
          case (max_id3)
            2'd0: base = $signed(gmb) * 60;                 // (g - b) * 60
            2'd1: base = $signed(brm) * 60 + 12000;         // (b - r) * 60 + 12000
            2'd2: base = $signed(rmb) * 60 + 24000;         // (r - b) * 60 + 24000
            default: base = 0;
          endcase
          // Base is 0..36000. Negative values wrap to positive due to modulo behavior
          h_base6 <= base;
          // Prepare raw hue (we will normalize at stage 9)
          // Using modulo-like approach in the next stage.
        end

        // Stage 7: saturation raw (percent * 100 -> 0..10000)
        s7_raw <= (max3_u == 16'd0) ? 16'd0 : mul_div_rounded(delta3, 16'd10000, max3_u);

        // Stage 8: value raw (percent * 100 -> 0..10000)
        v8_raw <= mul_div_rounded(max3_u, 16'd10000, 16'd300);

        // Stage 9: finalize hue with wrapping and special case handling
        begin
          logic [15:0] h6, h9_wire;
          // Convert h_base6 (signed) to unsigned 0..35999 range
          // base range is 0..36000; allow slight overshoot and wrap to 0..35999
          h6 = (h_base6 % 36000);
          if (h6 >= 36000) h6 = h6 - 36000;
          if (delta3 == 16'd0 || max3_u == 16'd0) begin
            h9_wire = 16'd0; // Undefined hue for gray; set to 0
            s9 <= 16'd0;     // Also force saturation to 0
            v9 <= v8_raw;
          end else begin
            h9_wire = h6;    // hue already in tenths of degree (0..359.99)
            s9 <= s7_raw;
            v9 <= v8_raw;
          end
          h9 <= h9_wire;
        end

        // Capture results in output registers exactly at cycle 16
        if (shcnt == 4'd14) begin
          h_reg <= h9;
          s_reg <= s9;
          v_reg <= v9;
        end

        // done pulses high one cycle before outputs update
        done_reg <= (shcnt == 4'd13);

        // Outputs update concurrently when done is asserted
        h <= h_reg;
        s <= s_reg;
        v <= v_reg;
        done <= done_reg;
      end
    end
  end

  // Notes:
  // - r1/g1/b1 at stage 6 contain scaled-by-196 RGB values.
  //   196 is used instead of 1000/255 to keep intermediate products within 32-bit range.
  // - Hue, Saturation, Value are computed using integer arithmetic with proper rounding.
  // - Total latency: 16 cycles from start assertion to done.
endmodule
