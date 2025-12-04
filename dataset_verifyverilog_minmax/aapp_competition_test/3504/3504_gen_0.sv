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
  logic start_q;
  logic [2:0] cycle;
  logic active;

  logic [15:0] r_droplet_x [0:7];
  logic [15:0] r_droplet_y [0:7];
  logic [2:0] r_droplet_count;
  logic [15:0] r_sensor_x1 [0:3];
  logic [15:0] r_sensor_x2 [0:3];
  logic [15:0] r_sensor_y [0:3];
  logic [1:0] r_sensor_count;

  // Combinational computation for current cycle (parallel across all droplets and sensors)
  logic [15:0] next_result [0:7];
  logic [15:0] best_y [0:7];
  logic       found [0:7];

  genvar i, j;

  generate
    for (i = 0; i < 8; i = i + 1) begin : g_droplet_loop
      always_comb begin
        best_y[i] = 16'h0;
        found[i]  = 1'b0;
        for (j = 0; j < 4; j = j + 1) begin
          if ((j < r_sensor_count) && (i < r_droplet_count)) begin
            if ((r_sensor_y[j] < r_droplet_y[i]) &&
                (r_sensor_x1[j] <= r_droplet_x[i]) &&
                (r_droplet_x[i] <= r_sensor_x2[j])) begin
              if (r_sensor_y[j] > best_y[i]) begin
                best_y[i] = r_sensor_y[j];
                found[i]  = 1'b1;
              end
            end
          end
        end
        next_result[i] = found[i] ? best_y[i] : 16'h0;
      end
    end
  endgenerate

  // Sequential control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_q      <= 1'b0;
      active       <= 1'b0;
      cycle        <= 3'd0;
      done         <= 1'b0;
      r_droplet_x <= '{default: 16'h0};
      r_droplet_y <= '{default: 16'h0};
      r_droplet_count <= 3'd0;
      r_sensor_x1 <= '{default: 16'h0};
      r_sensor_x2 <= '{default: 16'h0};
      r_sensor_y  <= '{default: 16'h0};
      r_sensor_count <= 2'd0;
      result       <= '{default: 16'h0};
    end else begin
      // Latch inputs on start pulse
      if (start && !start_q) begin
        r_droplet_x <= droplet_x;
        r_droplet_y <= droplet_y;
        r_droplet_count <= droplet_count;
        r_sensor_x1 <= sensor_x1;
        r_sensor_x2 <= sensor_x2;
        r_sensor_y  <= sensor_y;
        r_sensor_count <= sensor_count;
      end

      // Update state machine
      if (start && !start_q) begin
        active <= 1'b1;
        cycle  <= 3'd1; // Cycle 1 after start
        done   <= 1'b0;
      end else if (active) begin
        if (cycle < 3'd7) begin
          cycle <= cycle + 1;
        end else begin
          cycle <= 3'd0;
          active <= 1'b0;
          done <= 1'b1;
        end
      end else begin
        done <= 1'b0; // Hold done low when not processing
      end

      // Update results each cycle while active
      if (active) begin
        result <= next_result;
      end

      // If not active, hold results (already retained via non-blocking)
      start_q <= start;
    end
  end

endmodule
