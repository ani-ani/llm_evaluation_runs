module cookie_hits_wall (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] omega,
  input [31:0] v0,
  input [31:0] theta_deg,
  input [31:0] wall_x,
  input [31:0] vertices [0:4][0:1],
  output reg [2:0] result_index,
  output reg [31:0] result_time,
  output reg done,
  output reg valid
);

  // Constants
  localparam IDLE = 3'b000;
  localparam SETUP = 3'b001;
  localparam SIMULATE = 3'b010;
  localparam DONE = 3'b100;

  localparam [31:0] DT = 32'h0000028F; // 0.01s in Q16.16
  localparam [31:0] MAX_STEPS = 1000;
  localparam [31:0] PI = 32'h0003243F; // 3.1415926535 in Q16.16
  localparam [31:0] DEG_TO_RAD = 32'h00000B44; // 0.0174532925 in Q16.16

  // State machine
  reg [2:0] state;

  // Simulation variables
  reg [31:0] time;
  reg [31:0] step_count;
  reg [31:0] x_c, y_c; // Center of mass
  reg [31:0] vx, vy; // Velocity components
  reg [31:0] phi; // Rotation angle
  reg [31:0] min_time;
  reg [2:0] min_index;
  reg [31:0] hit_times [0:4];

  // Temporary variables for computation
  reg [31:0] x_rot, y_rot;
  reg [31:0] x_global, y_global;
  reg [31:0] cos_phi, sin_phi;
  reg [31:0] x_rel, y_rel;
  reg [31:0] temp;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      result_index <= 0;
      result_time <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP;
          end
        end
        SETUP: begin
          state <= SIMULATE;
          time <= 0;
          step_count <= 0;
          min_time <= 32'hFFFFFFFF;
          min_index <= 0;

          // Calculate center of mass
          x_c <= 0;
          y_c <= 0;
          for (int i = 0; i < n; i = i + 1) begin
            x_c <= x_c + vertices[i][0];
            y_c <= y_c + vertices[i][1];
          end
          x_c <= x_c / n;
          y_c <= y_c / n;

          // Convert angle to radians
          temp <= theta_deg * DEG_TO_RAD;
          temp <= temp >> 16; // Scale to Q16.16

          // Calculate velocity components
          // Small angle approximation for cos and sin
          // cos(theta) ≈ 1 - theta^2/2, sin(theta) ≈ theta
          cos_phi <= 32'h00010000 - ((temp * temp) >> 17); // Q16.16
          sin_phi <= temp;

          vx <= (v0 * cos_phi) >> 16;
          vy <= (v0 * sin_phi) >> 16;

          // Initialize hit times
          for (int i = 0; i < 5; i = i + 1) begin
            hit_times[i] <= 32'hFFFFFFFF;
          end
        end
        SIMULATE: begin
          if (step_count < MAX_STEPS) begin
            // Update time and rotation angle
            time <= time + DT;
            phi <= omega * time;
            phi <= phi >> 16; // Scale to Q16.16

            // Small angle approximation for cos and sin of phi
            cos_phi <= 32'h00010000 - ((phi * phi) >> 17);
            sin_phi <= phi;

            // Update center of mass position
            x_c <= x_c + ((vx * DT) >> 16);
            y_c <= y_c + ((vy * DT) >> 16) - ((32'h0000000A * DT * DT) >> 32); // g = 9.8 ≈ 0x0000000A

            // Check each vertex
            for (int i = 0; i < n; i = i + 1) begin
              // Relative position to center
              x_rel <= vertices[i][0] - x_c;
              y_rel <= vertices[i][1] - y_c;

              // Rotate clockwise
              x_rot <= (x_rel * cos_phi) >> 16 + (y_rel * sin_phi) >> 16;
              y_rot <= (y_rel * cos_phi) >> 16 - (x_rel * sin_phi) >> 16;

              // Global position
              x_global <= x_c + x_rot;
              y_global <= y_c + y_rot;

              // Check if hit wall
              if (x_global >= wall_x && hit_times[i] == 32'hFFFFFFFF) begin
                hit_times[i] <= time;
                if (time < min_time) begin
                  min_time <= time;
                  min_index <= i + 1;
                end
              end
            end

            step_count <= step_count + 1;

            // Check if all vertices have hit or max steps reached
            if (step_count == MAX_STEPS) begin
              state <= DONE;
            end
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1;
          valid <= 1;
          result_index <= min_index;
          result_time <= min_time;
        end
      endcase
    end
  end

endmodule