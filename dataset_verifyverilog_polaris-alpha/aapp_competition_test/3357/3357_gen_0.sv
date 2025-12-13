module sunlight_calculator(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [3:0]  num_buildings,
  input  wire [15:0] x_pos [7:0],
  input  wire [15:0] height [7:0],
  output reg  [31:0] sunlight [7:0],
  output reg         done
);

  // Parameters
  localparam integer MAX_BUILDINGS = 8;
  localparam integer ANG_Q        = 8;          // Q8.8 for angles
  localparam integer ANG_WIDTH    = 16;
  localparam [ANG_WIDTH-1:0] ANG_180 = 16'hB400; // 180deg in Q8.8 (180*256=46080=0xB400)
  // Combined scaling: (180 - L - R)/15 * 12 hours = (180 - L - R) * 0.8
  // For Q16.16 output: multiply angle(Q8.8) by SCALE (Q8.16) then >>8
  // SCALE = 0.8 in Q8.16 = round(0.8 * 2^16) = 0x0CCD
  localparam [23:0] SCALE = 24'h00CCD;

  // Internal regs
  reg        busy;
  reg        start_d;
  wire       start_pulse;

  reg [5:0]  cycle_cnt;          // To enforce 60-cycle latency
  reg [3:0]  b_idx;              // current building index
  reg [3:0]  j_idx;              // index for scanning other buildings
  reg [1:0]  phase;              // 0: init building, 1: scan left, 2: scan right, 3: finalize

  reg [ANG_WIDTH-1:0] max_left_angle;
  reg [ANG_WIDTH-1:0] max_right_angle;

  // Latched inputs for current building
  reg [15:0] cur_x;
  reg [15:0] cur_h;

  // For atan2 pipeline
  reg              atan_valid_in;
  reg signed [15:0] atan_dy_in;
  reg signed [15:0] atan_dx_in;
  wire             atan_valid_out;
  wire [ANG_WIDTH-1:0] atan_angle_out;

  // Track when atan result corresponds to left or right and which building
  reg atan_is_left_in;
  reg [3:0] atan_bidx_in;

  reg atan_is_left_pipe [3:0];
  reg [3:0] atan_bidx_pipe [3:0];

  integer ii;

  // Start pulse detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  assign start_pulse = start & ~start_d;

  // Main control FSM and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy       <= 1'b0;
      done       <= 1'b0;
      cycle_cnt  <= 6'd0;
      b_idx      <= 4'd0;
      j_idx      <= 4'd0;
      phase      <= 2'd0;
      max_left_angle  <= 0;
      max_right_angle <= 0;
      cur_x      <= 16'd0;
      cur_h      <= 16'd0;
      atan_valid_in <= 1'b0;
      atan_dy_in    <= 16'sd0;
      atan_dx_in    <= 16'sd1;
      atan_is_left_in <= 1'b0;
      atan_bidx_in    <= 4'd0;
      for (ii = 0; ii < MAX_BUILDINGS; ii = ii + 1) begin
        sunlight[ii] <= 32'd0;
      end
    end else begin
      // Default
      atan_valid_in <= 1'b0;

      // Pipeline tracking shift
      atan_is_left_pipe[0] <= atan_is_left_in;
      atan_bidx_pipe[0]    <= atan_bidx_in;
      for (ii = 1; ii < 4; ii = ii + 1) begin
        atan_is_left_pipe[ii] <= atan_is_left_pipe[ii-1];
        atan_bidx_pipe[ii]    <= atan_bidx_pipe[ii-1];
      end

      // Handle start
      if (start_pulse && !busy) begin
        busy      <= 1'b1;
        done      <= 1'b0;
        cycle_cnt <= 6'd0;
        b_idx     <= 4'd0;
        phase     <= 2'd0;
        j_idx     <= 4'd0;
        max_left_angle  <= 0;
        max_right_angle <= 0;
      end

      if (busy) begin
        // Increment cycle counter until 60
        if (cycle_cnt < 6'd60)
          cycle_cnt <= cycle_cnt + 6'd1;

        // Capture atan2 outputs and update max angles
        if (atan_valid_out) begin
          if (atan_is_left_pipe[3]) begin
            // left side
            if (atan_angle_out > max_left_angle)
              max_left_angle <= atan_angle_out;
          end else begin
            // right side
            if (atan_angle_out > max_right_angle)
              max_right_angle <= atan_angle_out;
          end
        end

        // FSM for building/neighbor iteration
        case (phase)
          2'd0: begin
            // Initialize current building if within count
            if (b_idx < num_buildings) begin
              cur_x <= x_pos[b_idx];
              cur_h <= height[b_idx];
              max_left_angle  <= 0;
              max_right_angle <= 0;
              j_idx <= 4'd0;
              phase <= 2'd1; // start scanning left
            end else begin
              // All buildings processed
              if (cycle_cnt >= 6'd60) begin
                busy <= 1'b0;
                done <= 1'b1;
              end
            end
          end

          2'd1: begin
            // Scan left neighbors: j < b_idx
            if (j_idx < b_idx) begin
              // compute angle if dx > 0 (west neighbor: x_j < x_i)
              if (x_pos[b_idx] > x_pos[j_idx]) begin
                atan_valid_in <= 1'b1;
                atan_dy_in    <= $signed(height[j_idx]) - $signed(cur_h);
                atan_dx_in    <= $signed(cur_x) - $signed(x_pos[j_idx]);
                atan_is_left_in <= 1'b1;
                atan_bidx_in    <= b_idx;
              end
              j_idx <= j_idx + 4'd1;
            end else begin
              // done left, now scan right
              j_idx <= b_idx + 4'd1;
              phase <= 2'd2;
            end
          end

          2'd2: begin
            // Scan right neighbors: j > b_idx and j < num_buildings
            if ((j_idx < num_buildings) && (j_idx < MAX_BUILDINGS)) begin
              if (x_pos[j_idx] > cur_x) begin
                atan_valid_in <= 1'b1;
                atan_dy_in    <= $signed(height[j_idx]) - $signed(cur_h);
                atan_dx_in    <= $signed(x_pos[j_idx]) - $signed(cur_x);
                atan_is_left_in <= 1'b0;
                atan_bidx_in    <= b_idx;
              end
              j_idx <= j_idx + 4'd1;
            end else begin
              // Done both sides, move to finalize for this building
              phase <= 2'd3;
            end
          end

          2'd3: begin
            // Finalize sunlight for building b_idx using current max_left/right
            // Compute: sun = (180 - L - R) * SCALE (Q8.8 * Q8.16) -> Q16.24, then >>8 -> Q16.16
            // Clamp negative to 0
            reg signed [17:0] diff_ang; // signed to hold 180-L-R
            reg signed [41:0] mult_res; // 18+24 bits
            diff_ang = $signed({1'b0, ANG_180}) - $signed({1'b0, max_left_angle}) - $signed({1'b0, max_right_angle});
            if (diff_ang <= 0) begin
              sunlight[b_idx] <= 32'd0;
            end else begin
              mult_res = $signed(diff_ang) * $signed({8'd0, SCALE});
              // >>8 to convert from Q16.24 to Q16.16
              sunlight[b_idx] <= mult_res[41:10];
            end

            // Next building
            b_idx  <= b_idx + 4'd1;
            phase  <= 2'd0;
          end

          default: phase <= 2'd0;
        endcase
      end else begin
        // Not busy; outputs hold, done held until next start
        atan_valid_in <= 1'b0;
      end
    end
  end

  // Simple pipelined atan2 approximation (4-cycle latency)
  // Input: dy, dx signed 16-bit, dx>0 assumed. Output: angle in Q8.8 (0-180deg), atan_valid_out aligned.
  // This is a placeholder piecewise-linear approximation suitable for synthesis.

  reg        v1, v2, v3;
  reg signed [15:0] dy1, dy2, dy3;
  reg signed [15:0] dx1, dx2, dx3;
  reg [ANG_WIDTH-1:0] angle3;

  // Stage 1: register inputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v1  <= 1'b0;
      dy1 <= 16'sd0;
      dx1 <= 16'sd1;
    end else begin
      v1  <= atan_valid_in;
      dy1 <= atan_dy_in;
      dx1 <= atan_dx_in;
    end
  end

  // Stage 2: compute absolute slope in Q4.12 approx (dy/dx)
  reg signed [31:0] slope2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v2  <= 1'b0;
      dy2 <= 16'sd0;
      dx2 <= 16'sd1;
      slope2 <= 32'sd0;
    end else begin
      v2  <= v1;
      dy2 <= dy1;
      dx2 <= dx1;
      if (dx1 != 0)
        slope2 <= ({{16{dy1[15]}},dy1} <<< 12) / dx1; // Q4.12
      else
        slope2 <= 32'sd0;
    end
  end

  // Stage 3: piecewise-linear atan(|slope|) in degrees Q8.8
  reg [ANG_WIDTH-1:0] ang2;
  reg signed [31:0] abs_slope2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v3  <= 1'b0;
      dy3 <= 16'sd0;
      dx3 <= 16'sd1;
      angle3 <= 16'd0;
    end else begin
      v3  <= v2;
      dy3 <= dy2;
      dx3 <= dx2;
      abs_slope2 <= (slope2 < 0) ? -slope2 : slope2;
      // Very rough approximation:
      // for small slope: angle ~= slope * (45/pi) deg ~ slope * 14.323; tuned for Q4.12->Q8.8
      // We'll use a scaled factor K = 14 (approx).
      // angle_q8_8 = (abs_slope2 * 14) >> 12
      if (abs_slope2 < (32'sd4096)) begin
        ang2 <= (abs_slope2 * 14) >> 12; // up to ~56deg
      end else if (abs_slope2 < (32'sd16384)) begin
        // between ~56 and ~75deg, compress
        ang2 <= 16'h3800 + ((abs_slope2 - 32'sd4096) * 6 >> 13); // base ~56deg + small slope
      end else begin
        // saturate near 89deg
        ang2 <= 16'h5900; // ~89deg
      end
      angle3 <= ang2;
    end
  end

  // Stage 4: adjust quadrant based on signs (only dx>0 used in this design, so sign(dy) not changing 0-180)
  reg [ANG_WIDTH-1:0] angle4;
  reg v4;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v4      <= 1'b0;
      angle4  <= 16'd0;
    end else begin
      v4 <= v3;
      if (dy3 >= 0)
        angle4 <= angle3;         // 0..~89
      else
        angle4 <= -angle3;        // allow negative for below-horizon
    end
  end

  assign atan_valid_out = v4;
  assign atan_angle_out = angle4;

endmodule