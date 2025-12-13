module spiral_exit_point(
  input clk,
  input rst_n,
  input start,
  input [31:0] b_q248,
  input [31:0] tx_q248,
  input [31:0] ty_q248,
  output reg [31:0] x_out_q248,
  output reg [31:0] y_out_q248,
  output reg done
);

  // Fixed-point formats:
  // Q24.8 for coordinates and parameter b
  // Q8.8 for angle phi

  // Parameters
  localparam ITER_MAX        = 16;                  // Newton iterations
  localparam CYCLES_PER_ITER = 8;                   // pipeline cycles per iteration
  localparam TOTAL_CYCLES    = ITER_MAX*CYCLES_PER_ITER; // 128

  // Internal registers
  reg [7:0]   iter_cnt;        // iteration counter (0..15)
  reg [6:0]   cyc_cnt;         // cycle counter within total sequence
  reg         busy;            // high during computation

  // Angle phi in Q8.8
  reg  [15:0] phi_q88;         // current phi
  reg  [15:0] dphi_q88;        // update step

  // ROM interface for sin/cos
  // 12-bit address: use upper bits of phi (wrap naturally)
  wire [11:0] lut_addr;
  wire signed [15:0] sin_q18;  // example output format: Q1.15 or Q2.14 (we treat as signed 16)
  wire signed [15:0] cos_q18;

  assign lut_addr = phi_q88[15:4]; // take high 12 bits as address

  // Spiral radius r = b * phi  (b: Q24.8, phi: Q8.8)
  // Product is Q(24+8).(8+8) = Q32.16; scale back to Q24.8 by >>8
  reg  signed [31:0] r_q248;
  reg  signed [47:0] mult_b_phi;

  // Coordinates and intermediate values
  reg  signed [31:0] x_q248;
  reg  signed [31:0] y_q248;

  // Derivative-related values (for Newton-Raphson)
  // Archimedean spiral: r = b*phi
  // x = r cos(phi), y = r sin(phi)
  // x' = dr/dphi*cos - r*sin = b*cos - r*sin
  // y' = dr/dphi*sin + r*cos = b*sin + r*cos
  reg  signed [31:0] dx_dphi_q248;
  reg  signed [31:0] dy_dphi_q248;

  // Error and update
  reg  signed [31:0] ex_q248;   // x error
  reg  signed [31:0] ey_q248;   // y error
  reg  signed [47:0] num_q;     // numerator for projection
  reg  signed [47:0] den_q;     // denominator for projection
  reg  signed [31:0] dphi_newton_q88; // Delta phi in Q8.8

  // Control FSM (simple counter-based pipeline)
  // We distribute operations across 8 cycles per iteration.

  // Cycle meaning per iteration (cyc_mod = cyc_cnt[2:0]):
  // 0: compute r = b * phi
  // 1: compute x = r*cos, y = r*sin
  // 2: compute derivatives dx_dphi, dy_dphi
  // 3: compute errors ex, ey
  // 4: compute numerator = ex*dx + ey*dy (projection along tangent)
  // 5: compute denominator = dx*dx + dy*dy
  // 6: compute dphi using a simple reciprocal approximation (Newton-Raphson-friendly)
  // 7: update phi with dphi, last iteration latch outputs

  wire [2:0] cyc_mod = cyc_cnt[2:0];

  // ROM-based sin/cos LUTs (12-bit address)
  spiral_trig_lut u_lut(
    .addr(lut_addr),
    .sin_out(sin_q18),
    .cos_out(cos_q18)
  );

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      iter_cnt     <= 8'd0;
      cyc_cnt      <= 7'd0;
      busy         <= 1'b0;
      phi_q88      <= 16'd0;
      dphi_q88     <= 16'd0;
      r_q248       <= 32'sd0;
      mult_b_phi   <= 48'sd0;
      x_q248       <= 32'sd0;
      y_q248       <= 32'sd0;
      dx_dphi_q248 <= 32'sd0;
      dy_dphi_q248 <= 32'sd0;
      ex_q248      <= 32'sd0;
      ey_q248      <= 32'sd0;
      num_q        <= 48'sd0;
      den_q        <= 48'sd0;
      dphi_newton_q88 <= 32'sd0;
      x_out_q248   <= 32'd0;
      y_out_q248   <= 32'd0;
      done         <= 1'b0;
    end else begin
      done <= 1'b0;

      // Start pulse: initialize computation
      if (start && !busy) begin
        busy         <= 1'b1;
        iter_cnt     <= 8'd0;
        cyc_cnt      <= 7'd0;
        // Initial guess for phi: use small non-zero to avoid singularity
        // e.g., phi0 = 0.5 rad (~0x0080 in Q8.8)
        phi_q88      <= 16'd128; // 0.5
        dphi_q88     <= 16'd0;
        r_q248       <= 32'sd0;
        x_q248       <= 32'sd0;
        y_q248       <= 32'sd0;
        dx_dphi_q248 <= 32'sd0;
        dy_dphi_q248 <= 32'sd0;
        ex_q248      <= 32'sd0;
        ey_q248      <= 32'sd0;
        num_q        <= 48'sd0;
        den_q        <= 48'sd0;
        dphi_newton_q88 <= 32'sd0;
      end else if (busy) begin
        // Main pipeline
        case (cyc_mod)
          3'd0: begin
            // Compute r = b * phi (Q24.8 * Q8.8 -> Q32.16 -> Q24.8)
            mult_b_phi <= $signed(b_q248) * $signed({{16{phi_q88[15]}},phi_q88});
          end

          3'd1: begin
            // Finish r scaling
            r_q248 <= mult_b_phi[47:16]; // >>8 from Q32.16 to Q24.8 (taking upper 32 bits)

            // Compute x = r*cos, y = r*sin
            // r: Q24.8, cos/sin: treat as Q1.15 -> product Q25.23 -> back to Q24.8 by >>15
            // Extend r to 40 bits for mult precision
            begin
              reg signed [39:0] r_ext;
              reg signed [55:0] x_mul;
              reg signed [55:0] y_mul;
              r_ext = { {8{r_q248[31]}}, r_q248 }; // sign-extend to 40
              x_mul = r_ext * $signed(cos_q18);
              y_mul = r_ext * $signed(sin_q18);
              x_q248 <= x_mul[55:24];
              y_q248 <= y_mul[55:24];
            end
          end

          3'd2: begin
            // Compute derivatives:
            // dx_dphi = b*cos - r*sin
            // dy_dphi = b*sin + r*cos
            begin
              reg signed [39:0] b_ext;
              reg signed [39:0] r_ext2;
              reg signed [55:0] bcos_mul;
              reg signed [55:0] bsin_mul;
              reg signed [55:0] rsin_mul;
              reg signed [55:0] rcos_mul;

              b_ext   = { {8{b_q248[31]}}, b_q248 };
              r_ext2  = { {8{r_q248[31]}}, r_q248 };

              bcos_mul = b_ext  * $signed(cos_q18);
              bsin_mul = b_ext  * $signed(sin_q18);
              rsin_mul = r_ext2 * $signed(sin_q18);
              rcos_mul = r_ext2 * $signed(cos_q18);

              // Convert back to Q24.8 (>>15)
              dx_dphi_q248 <= (bcos_mul[55:24]) - (rsin_mul[55:24]);
              dy_dphi_q248 <= (bsin_mul[55:24]) + (rcos_mul[55:24]);
            end
          end

          3'd3: begin
            // Compute error vector: e = target - current
            ex_q248 <= $signed(tx_q248) - x_q248;
            ey_q248 <= $signed(ty_q248) - y_q248;
          end

          3'd4: begin
            // Numerator: ex*dx + ey*dy (Q24.8 * Q24.8 -> Q48.16)
            begin
              reg signed [47:0] exdx;
              reg signed [47:0] eydy;
              exdx = $signed(ex_q248) * $signed(dx_dphi_q248);
              eydy = $signed(ey_q248) * $signed(dy_dphi_q248);
              num_q <= exdx + eydy;
            end
          end

          3'd5: begin
            // Denominator: dx^2 + dy^2
            begin
              reg signed [47:0] dxdx;
              reg signed [47:0] dydy;
              dxdx = $signed(dx_dphi_q248) * $signed(dx_dphi_q248);
              dydy = $signed(dy_dphi_q248) * $signed(dy_dphi_q248);
              den_q <= dxdx + dydy;
            end
          end

          3'd6: begin
            // Compute dphi = num / den
            // num: Q48.16, den: Q48.16 -> ratio ~ Q0.16
            // We want dphi in Q8.8, so take appropriate bits.
            // For hardware simplicity: use a non-restoring division approximation.
            // Here model with direct divide (synthesizable if mapped or replaced later).
            if (den_q != 0) begin
              // Signed division; scale to Q8.8: (num / den) in Q8.8
              // Take a 32-bit intermediate for dphi.
              dphi_newton_q88 <= $signed(num_q[47:16]) / $signed(den_q[31:16]);
            end else begin
              dphi_newton_q88 <= 32'sd0;
            end
          end

          3'd7: begin
            // Update phi and iteration counter
            // Newton step: phi = phi + dphi
            // Limit step to avoid divergence (clamp)
            begin
              reg signed [15:0] dphi_clamped;
              reg signed [15:0] phi_next;

              // Clamp dphi to reasonable range (e.g., [-256,256] in Q8.8 -> +/-1.0 rad)
              if ($signed(dphi_newton_q88[15:0]) > 16'sd256)
                dphi_clamped = 16'sd256;
              else if ($signed(dphi_newton_q88[15:0]) < -16'sd256)
                dphi_clamped = -16'sd256;
              else
                dphi_clamped = dphi_newton_q88[15:0];

              phi_next = $signed(phi_q88) + dphi_clamped;

              // Keep phi non-negative
              if (phi_next < 0)
                phi_q88 <= 16'd0;
              else
                phi_q88 <= phi_next;
            end

            // End of iteration handling
            if (iter_cnt == ITER_MAX-1) begin
              // Final outputs latch current x,y as exit point
              x_out_q248 <= x_q248;
              y_out_q248 <= y_q248;

              busy     <= 1'b0;
              done     <= 1'b1;
              iter_cnt <= 8'd0;
              cyc_cnt  <= 7'd0;
            end else begin
              iter_cnt <= iter_cnt + 8'd1;
              if (cyc_cnt == TOTAL_CYCLES-1)
                cyc_cnt <= 7'd0;
            end
          end
        endcase

        // Global cycle count increment while busy
        if (busy) begin
          if (!(cyc_mod == 3'd7 && iter_cnt == ITER_MAX-1)) begin
            cyc_cnt <= cyc_cnt + 7'd1;
          end
        end
      end
    end
  end

endmodule

// Trig LUT: 12-bit address -> sin/cos in signed 16-bit
// Placeholder implementation; to be replaced with actual ROM contents.
module spiral_trig_lut(
  input  [11:0] addr,
  output reg signed [15:0] sin_out,
  output reg signed [15:0] cos_out
);
  // Simple symmetric placeholder using case; in real design, infer ROM.
  always @(*) begin
    // Default
    sin_out = 16'sd0;
    cos_out = 16'sd32767;
    // Minimal illustrative entries (address-dependent); real table must be filled.
    case (addr)
      12'd0: begin sin_out = 16'sd0;      cos_out = 16'sd32767; end
      12'd1: begin sin_out = 16'sd804;    cos_out = 16'sd32757; end
      12'd2: begin sin_out = 16'sd1608;   cos_out = 16'sd32727; end
      default: ;
    endcase
  end
endmodule