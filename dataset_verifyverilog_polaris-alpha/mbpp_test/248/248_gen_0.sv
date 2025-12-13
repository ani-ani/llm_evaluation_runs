module harmonic_sum(
  input clk,
  input rst_n,
  input start,
  input [3:0] n_in,
  output reg [15:0] sum,
  output reg done
);

  // Q8.8 reciprocal lookup table for k = 0..15
  // Index 0 is unused (set to 0)
  //  1/1  = 0x0100
  //  1/2  = 0x0080
  //  1/3  ≈ 0x0055
  //  1/4  = 0x0040
  //  1/5  = 0x0033
  //  1/6  ≈ 0x002A
  //  1/7  ≈ 0x0024
  //  1/8  = 0x0020
  //  1/9  ≈ 0x001C
  //  1/10 = 0x0019
  //  1/11 ≈ 0x0017
  //  1/12 ≈ 0x0015
  //  1/13 ≈ 0x0013
  //  1/14 ≈ 0x0012
  //  1/15 ≈ 0x0011
  reg [15:0] recip_lut [0:15];
  initial begin
    recip_lut[0]  = 16'h0000; // unused
    recip_lut[1]  = 16'h0100; // 1/1
    recip_lut[2]  = 16'h0080; // 1/2
    recip_lut[3]  = 16'h0055; // 1/3
    recip_lut[4]  = 16'h0040; // 1/4
    recip_lut[5]  = 16'h0033; // 1/5
    recip_lut[6]  = 16'h002A; // 1/6
    recip_lut[7]  = 16'h0024; // 1/7
    recip_lut[8]  = 16'h0020; // 1/8
    recip_lut[9]  = 16'h001C; // 1/9
    recip_lut[10] = 16'h0019; // 1/10
    recip_lut[11] = 16'h0017; // 1/11
    recip_lut[12] = 16'h0015; // 1/12
    recip_lut[13] = 16'h0013; // 1/13
    recip_lut[14] = 16'h0012; // 1/14
    recip_lut[15] = 16'h0011; // 1/15
  end

  reg [3:0] k;
  reg [3:0] n_eff;
  reg       busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum   <= 16'd0;
      done  <= 1'b0;
      k     <= 4'd0;
      n_eff <= 4'd0;
      busy  <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Start new calculation
        n_eff <= (n_in < 4'd2) ? 4'd2 : n_in; // clamp to minimum 2
        sum   <= 16'd0;
        k     <= 4'd1;
        done  <= 1'b0;
        busy  <= 1'b1;
      end else if (busy) begin
        // Perform one term per cycle: sum += 1/k
        sum <= sum + recip_lut[k];
        if (k == (n_eff - 1)) begin
          // Completed last term
          done <= 1'b1;
          busy <= 1'b0;
        end else begin
          k <= k + 4'd1;
        end
      end else begin
        // Idle: hold outputs (done stays asserted until next start or reset)
        done <= done;
      end
    end
  end

endmodule