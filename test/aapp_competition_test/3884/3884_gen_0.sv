module rocket_fuel_calc(
  input              clk,
  input              rst_n,
  input              start,
  input       [3:0]  n,
  input       [15:0] m,
  input       [15:0] a [7:0],
  input       [15:0] b [7:0],
  output reg [39:0]  fuel,
  output reg         done
);

  // Internal state
  reg [3:0]   cycle_cnt;          // 0..15
  reg         running;            // indicates active calculation window
  reg         invalid_flag;       // asserted if any a_i or b_i == 1
  reg [31:0]  fuel_q16_16;        // fuel in Q16.16 (internal working register)

  // Pre-calculated constants
  localparam [31:0] ONE_Q16_16 = 32'h0001_0000; // 1.0 in Q16.16

  // Control: start and cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt   <= 4'd0;
      running     <= 1'b0;
      done        <= 1'b0;
      invalid_flag<= 1'b0;
      fuel        <= 40'd0;
      fuel_q16_16 <= 32'd0;
    end else begin
      // Default done low unless we explicitly set it at completion
      done <= 1'b0;

      // Launch new computation on start (one-cycle pulse assumed)
      if (start) begin
        running      <= 1'b1;
        cycle_cnt    <= 4'd0;
        invalid_flag <= 1'b0;
        fuel_q16_16  <= ONE_Q16_16; // initialize internal fuel (example baseline)
      end else if (running) begin
        cycle_cnt <= cycle_cnt + 4'd1;

        // 16-cycle computation window
        if (cycle_cnt == 4'd15) begin
          running <= 1'b0;
          done    <= 1'b1;

          // Final output selection
          if (invalid_flag) begin
            fuel <= 40'hFF_FFFF_FFFF;
          end else begin
            // Extend/clip from Q16.16 to 40-bit integer fuel (take upper bits)
            fuel <= {8'd0, fuel_q16_16[31:0]};
          end
        end
      end
    end
  end

  // Sequential computation: 1 planet (takeoff+landing) per cycle, up to 8 planets
  // Operations occur only while running and within n range
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      invalid_flag <= 1'b0;
      fuel_q16_16  <= 32'd0;
    end else if (running) begin
      if (cycle_cnt < n) begin
        // Current planet index
        // Takeoff and landing for planet i = cycle_cnt

        // Check invalid coefficients
        if (a[cycle_cnt] == 16'd1 || b[cycle_cnt] == 16'd1) begin
          invalid_flag <= 1'b1;
        end

        if (!invalid_flag) begin
          // Q16.16 math helpers (combinational within this clock):
          // mass in Q16.16
          reg [31:0] m_q16_16;
          reg [31:0] fuel_plus_m;
          reg [47:0] div_num;
          reg [31:0] takeoff_burn;
          reg [31:0] landing_burn;

          m_q16_16   = {m, 16'd0};

          // Takeoff burn
          fuel_plus_m = fuel_q16_16 + m_q16_16;
          div_num     = {16'd0, fuel_plus_m}; // align for division
          if (a[cycle_cnt] != 16'd0) begin
            takeoff_burn = div_num / a[cycle_cnt];
          end else begin
            takeoff_burn = 32'd0; // avoid div-by-zero; not specified, safe-guard
          end

          fuel_q16_16 = fuel_q16_16 - takeoff_burn;

          // Landing burn
          fuel_plus_m = fuel_q16_16 + m_q16_16;
          div_num     = {16'd0, fuel_plus_m};
          if (b[cycle_cnt] != 16'd0) begin
            landing_burn = div_num / b[cycle_cnt];
          end else begin
            landing_burn = 32'd0; // avoid div-by-zero; safe-guard
          end

          fuel_q16_16 = fuel_q16_16 - landing_burn;
        end
      end
      // For cycle_cnt >= n, no further fuel updates (idle until 16th cycle)
    end
  end

endmodule