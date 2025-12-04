module droplet_disintegrate(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high)
  // Droplet coordinates (max 8 droplets)
  input [15:0] droplet_x [0:7], // Array of 16-bit x-coordinates
  input [15:0] droplet_y [0:7], // Array of 16-bit y-coordinates
  input [2:0] droplet_count, // Number of valid droplets (1-8)
  // Sensor coordinates (max 4 sensors)
  input [15:0] sensor_x1 [0:3], // Array of 16-bit left x
  input [15:0] sensor_x2 [0:3], // Array of 16-bit right x
  input [15:0] sensor_y [0:3], // Array of 16-bit y positions
  input [1:0] sensor_count, // Number of valid sensors (1-4)
  // Outputs
  output reg [15:0] result [0:7], // Disintegration y-coordinates (0 = no hit)
  output reg done // High when all results ready
);

  // Internal state
  reg [2:0] cycle_cnt;      // 0-8
  reg [2:0] droplet_idx;    // 0-7
  reg       busy;           // Indicates active computation

  // Combinational wires for current droplet and matching sensors
  wire [15:0] cur_dx;
  wire [15:0] cur_dy;

  assign cur_dx = droplet_x[droplet_idx];
  assign cur_dy = droplet_y[droplet_idx];

  // Sensor validity and y values for current droplet
  wire match0_valid;
  wire match1_valid;
  wire match2_valid;
  wire match3_valid;

  wire [15:0] match0_y;
  wire [15:0] match1_y;
  wire [15:0] match2_y;
  wire [15:0] match3_y;

  // Check each sensor in parallel
  assign match0_valid = (sensor_count > 0) &&
                        (sensor_y[0] < cur_dy) &&
                        (sensor_x1[0] <= cur_dx) &&
                        (cur_dx <= sensor_x2[0]);
  assign match1_valid = (sensor_count > 1) &&
                        (sensor_y[1] < cur_dy) &&
                        (sensor_x1[1] <= cur_dx) &&
                        (cur_dx <= sensor_x2[1]);
  assign match2_valid = (sensor_count > 2) &&
                        (sensor_y[2] < cur_dy) &&
                        (sensor_x1[2] <= cur_dx) &&
                        (cur_dx <= sensor_x2[2]);
  assign match3_valid = (sensor_count > 3) &&
                        (sensor_y[3] < cur_dy) &&
                        (sensor_x1[3] <= cur_dx) &&
                        (cur_dx <= sensor_x2[3]);

  assign match0_y = sensor_y[0];
  assign match1_y = sensor_y[1];
  assign match2_y = sensor_y[2];
  assign match3_y = sensor_y[3];

  // Function to select highest (maximum) sensor_y among valid matches
  function automatic [15:0] select_best_sensor_y;
    input        v0; input [15:0] y0;
    input        v1; input [15:0] y1;
    input        v2; input [15:0] y2;
    input        v3; input [15:0] y3;
    reg   [15:0] best_y;
  begin
    best_y = 16'd0;
    if (v0 && (y0 > best_y)) best_y = y0;
    if (v1 && (y1 > best_y)) best_y = y1;
    if (v2 && (y2 > best_y)) best_y = y2;
    if (v3 && (y3 > best_y)) best_y = y3;
    select_best_sensor_y = best_y;
  end
  endfunction

  // Sequential control and result computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt   <= 3'd0;
      droplet_idx <= 3'd0;
      busy        <= 1'b0;
      done        <= 1'b0;
      result[0]   <= 16'd0;
      result[1]   <= 16'd0;
      result[2]   <= 16'd0;
      result[3]   <= 16'd0;
      result[4]   <= 16'd0;
      result[5]   <= 16'd0;
      result[6]   <= 16'd0;
      result[7]   <= 16'd0;
    end else begin
      // Default
      done <= 1'b0;

      if (start && !busy) begin
        // Start new computation window of fixed 8 cycles
        busy        <= 1'b1;
        cycle_cnt   <= 3'd0;
        droplet_idx <= 3'd0;
        // Clear all results at start
        result[0]   <= 16'd0;
        result[1]   <= 16'd0;
        result[2]   <= 16'd0;
        result[3]   <= 16'd0;
        result[4]   <= 16'd0;
        result[5]   <= 16'd0;
        result[6]   <= 16'd0;
        result[7]   <= 16'd0;
      end else if (busy) begin
        // Process one droplet per cycle for 8 cycles
        if (cycle_cnt < 3'd7) begin
          // Compute result for current droplet index if within droplet_count
          if (droplet_idx < droplet_count) begin
            result[droplet_idx] <= select_best_sensor_y(
                                      match0_valid, match0_y,
                                      match1_valid, match1_y,
                                      match2_valid, match2_y,
                                      match3_valid, match3_y);
          end else begin
            result[droplet_idx] <= 16'd0;
          end

          droplet_idx <= droplet_idx + 3'd1;
          cycle_cnt   <= cycle_cnt + 3'd1;
        end else begin
          // Final (8th) cycle: process last droplet index (7)
          if (droplet_idx < droplet_count) begin
            result[droplet_idx] <= select_best_sensor_y(
                                      match0_valid, match0_y,
                                      match1_valid, match1_y,
                                      match2_valid, match2_y,
                                      match3_valid, match3_y);
          end else begin
            result[droplet_idx] <= 16'd0;
          end

          // End of fixed 8-cycle computation
          done        <= 1'b1;
          busy        <= 1'b0;
          cycle_cnt   <= 3'd0;
          droplet_idx <= 3'd0;
        end
      end
    end
  end

endmodule