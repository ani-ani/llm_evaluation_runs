module droplet_disintegrate(
  input clk,
  input rst_n,
  input start,
  input [15:0] droplet_x [0:7],
  input [15:0] droplet_y [0:7],
  input [2:0] droplet_count,
  input [15:0] sensor_x1 [0:3],
  input [15:0] sensor_x2 [0:3],
  input [15:0] sensor_y [0:3],
  input [1:0] sensor_count,
  output reg [15:0] result [0:7],
  output reg done
);

  reg [2:0] cycle_count;
  reg [15:0] droplet_x_latched [0:7];
  reg [15:0] droplet_y_latched [0:7];
  reg [2:0] droplet_count_latched;
  reg [15:0] sensor_x1_latched [0:3];
  reg [15:0] sensor_x2_latched [0:3];
  reg [15:0] sensor_y_latched [0:3];
  reg [1:0] sensor_count_latched;
  reg [15:0] min_y;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 3'd0;
      done <= 1'b0;
      droplet_count_latched <= 3'd0;
      sensor_count_latched <= 2'd0;
      foreach (droplet_x_latched[i]) droplet_x_latched[i] <= 16'd0;
      foreach (droplet_y_latched[i]) droplet_y_latched[i] <= 16'd0;
      foreach (sensor_x1_latched[i]) sensor_x1_latched[i] <= 16'd0;
      foreach (sensor_x2_latched[i]) sensor_x2_latched[i] <= 16'd0;
      foreach (sensor_y_latched[i]) sensor_y_latched[i] <= 16'd0;
      foreach (result[i]) result[i] <= 16'd0;
    end else begin
      if (start) begin
        foreach (droplet_x[i]) droplet_x_latched[i] <= droplet_x[i];
        foreach (droplet_y[i]) droplet_y_latched[i] <= droplet_y[i];
        droplet_count_latched <= droplet_count;
        foreach (sensor_x1[i]) sensor_x1_latched[i] <= sensor_x1[i];
        foreach (sensor_x2[i]) sensor_x2_latched[i] <= sensor_x2[i];
        foreach (sensor_y[i]) sensor_y_latched[i] <= sensor_y[i];
        sensor_count_latched <= sensor_count;
        cycle_count <= 3'd0;
        done <= 1'b0;
      end else if (cycle_count < 3'd8) begin
        // Combinational min_y computation
        min_y = 16'hFFFF;
        if (cycle_count < droplet_count_latched) begin
          for (integer j=0; j<4; j=j+1) begin
            if (j < sensor_count_latched &&
                sensor_y_latched[j] < droplet_y_latched[cycle_count] &&
                droplet_x_latched[cycle_count] >= sensor_x1_latched[j] &&
                droplet_x_latched[cycle_count] <= sensor_x2_latched[j] &&
                sensor_y_latched[j] < min_y) begin
              min_y = sensor_y_latched[j];
            end
          end
          result[cycle_count] <= (min_y == 16'hFFFF) ? 16'd0 : min_y;
        end else begin
          result[cycle_count] <= 16'd0;
        end
        cycle_count <= cycle_count + 1;
      end
      done <= (cycle_count == 3'd8);
    end
  end
endmodule