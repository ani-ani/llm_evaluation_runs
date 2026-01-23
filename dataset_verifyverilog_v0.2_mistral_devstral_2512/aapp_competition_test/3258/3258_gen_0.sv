module cat_chase_verifier (
  input [3:0] valid_mice_mask,
  input [4:0][15:0] x_coords,
  input [4:0][15:0] y_coords,
  input [4:0][15:0] deadlines,
  input [4:0][15:0] velocities,
  output reg success
);

  reg [15:0] current_x = 16'd0;
  reg [15:0] current_y = 16'd0;
  reg [31:0] current_time = 32'd0;
  integer i;

  always @* begin
    success = 1'b1;
    current_x = 16'd0;
    current_y = 16'd0;
    current_time = 32'd0;

    for (i = 0; i < 5; i = i + 1) begin
      if (valid_mice_mask[i]) begin
        // Calculate Manhattan distance
        reg [15:0] dx = (x_coords[i] > current_x) ? (x_coords[i] - current_x) : (current_x - x_coords[i]);
        reg [15:0] dy = (y_coords[i] > current_y) ? (y_coords[i] - current_y) : (current_y - y_coords[i]);
        reg [15:0] distance = dx + dy;

        // Calculate travel time = distance / velocity (Q16.16)
        reg [31:0] travel_time = (distance << 16) / velocities[i];

        // Update current time
        current_time = current_time + travel_time;

        // Check deadline
        if (current_time > deadlines[i]) begin
          success = 1'b0;
        end

        // Update current position
        current_x = x_coords[i];
        current_y = y_coords[i];
      end
    end
  end

endmodule