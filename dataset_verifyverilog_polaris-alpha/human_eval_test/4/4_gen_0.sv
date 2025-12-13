module mean_abs_dev(
  input        clk,
  input        rst_n,
  input        start,
  input  [31:0] num0,
  input  [31:0] num1,
  input  [31:0] num2,
  input  [31:0] num3,
  output reg [31:0] mad,
  output reg       done
);

  // Internal registers
  reg [31:0] n0_r, n1_r, n2_r, n3_r;
  reg [33:0] sum;            // can hold sum of four 32-bit numbers (34 bits)
  reg [31:0] mean;

  reg signed [32:0] diff0, diff1, diff2, diff3; // signed differences
  reg [31:0] abs0, abs1, abs2, abs3;
  reg [33:0] abs_sum;        // sum of four abs values

  reg [3:0] cycle_cnt;       // to track latency cycles
  reg       busy;            // indicates active computation

  // Sequential control and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      mad       <= 32'd0;
      done      <= 1'b0;
      n0_r      <= 32'd0;
      n1_r      <= 32'd0;
      n2_r      <= 32'd0;
      n3_r      <= 32'd0;
      sum       <= 34'd0;
      mean      <= 32'd0;
      diff0     <= 33'sd0;
      diff1     <= 33'sd0;
      diff2     <= 33'sd0;
      diff3     <= 33'sd0;
      abs0      <= 32'd0;
      abs1      <= 32'd0;
      abs2      <= 32'd0;
      abs3      <= 32'd0;
      abs_sum   <= 34'd0;
      cycle_cnt <= 4'd0;
      busy      <= 1'b0;
    end else begin
      done <= 1'b0; // default, will be pulsed when result ready

      if (!busy) begin
        // Idle: wait for start pulse
        if (start) begin
          // Latch inputs at start
          n0_r      <= num0;
          n1_r      <= num1;
          n2_r      <= num2;
          n3_r      <= num3;
          cycle_cnt <= 4'd1;
          busy      <= 1'b1;
        end
      end else begin
        // Busy: advance computation by cycle counter
        cycle_cnt <= cycle_cnt + 4'd1;

        case (cycle_cnt)
          4'd1: begin
            // Compute sum
            sum <= {2'd0, n0_r} + {2'd0, n1_r} + {2'd0, n2_r} + {2'd0, n3_r};
          end

          4'd2: begin
            // Compute mean = sum / 4 (right-shift by 2, rounding toward zero)
            mean <= sum[33:2];
          end

          4'd3: begin
            // Compute differences (signed)
            diff0 <= $signed({1'b0, n0_r}) - $signed({1'b0, mean});
            diff1 <= $signed({1'b0, n1_r}) - $signed({1'b0, mean});
            diff2 <= $signed({1'b0, n2_r}) - $signed({1'b0, mean});
            diff3 <= $signed({1'b0, n3_r}) - $signed({1'b0, mean});
          end

          4'd4: begin
            // Absolute values
            abs0 <= diff0[32] ? (~diff0[31:0] + 32'd1) : diff0[31:0];
            abs1 <= diff1[32] ? (~diff1[31:0] + 32'd1) : diff1[31:0];
            abs2 <= diff2[32] ? (~diff2[31:0] + 32'd1) : diff2[31:0];
            abs3 <= diff3[32] ? (~diff3[31:0] + 32'd1) : diff3[31:0];
          end

          4'd5: begin
            // Sum absolute values
            abs_sum <= {2'd0, abs0} + {2'd0, abs1} + {2'd0, abs2} + {2'd0, abs3};
          end

          4'd6: begin
            // Compute MAD = abs_sum / 4 (shift right by 2, truncation = round toward zero)
            mad <= abs_sum[33:2];
          end

          4'd10: begin
            // Assert done for one cycle at the specified latency and go idle
            done      <= 1'b1;
            busy      <= 1'b0;
            cycle_cnt <= 4'd0;
          end

          default: begin
            // No operation in other cycles; padding to meet 10-cycle latency
          end
        endcase
      end
    end
  end

endmodule