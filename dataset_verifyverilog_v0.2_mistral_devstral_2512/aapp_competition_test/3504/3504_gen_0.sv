module antimatter_rain (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_droplets,
  input [3:0] num_sensors,
  input [3:0] drop_x [0:7],
  input [3:0] drop_y [0:7],
  input [3:0] sensor_x1 [0:7],
  input [3:0] sensor_x2 [0:7],
  input [3:0] sensor_y [0:7],
  output reg [3:0] result [0:7],
  output reg done
);

  // State machine
  typedef enum logic [2:0] {
    IDLE,
    READING,
    PROCESSING,
    WRITING,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg [3:0] droplet_idx;
  reg [3:0] sensor_idx;
  reg [3:0] active_sensors [0:7];
  reg [3:0] active_droplets [0:7];
  reg [3:0] current_result [0:7];
  reg [3:0] max_sensor_y;
  reg [3:0] max_sensor_idx;

  // Initialize all sensors and droplets as active
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      droplet_idx <= 0;
      sensor_idx <= 0;
      for (int i = 0; i < 8; i++) begin
        active_sensors[i] <= 1;
        active_droplets[i] <= 1;
        current_result[i] <= 0;
        result[i] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = READING;
      end
      READING: begin
        next_state = PROCESSING;
      end
      PROCESSING: begin
        if (droplet_idx == num_droplets - 1 && sensor_idx == num_sensors - 1) begin
          next_state = WRITING;
        end
      end
      WRITING: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled above
    end else if (state == READING) begin
      // Initialize active arrays
      for (int i = 0; i < 8; i++) begin
        active_sensors[i] <= 1;
        active_droplets[i] <= 1;
        current_result[i] <= 0;
      end
      droplet_idx <= 0;
      sensor_idx <= 0;
    end else if (state == PROCESSING) begin
      // Process each droplet
      if (active_droplets[droplet_idx]) begin
        max_sensor_y <= 0;
        max_sensor_idx <= 0;
        // Find highest sensor for current droplet
        for (int i = 0; i < num_sensors; i++) begin
          if (active_sensors[i] && 
              sensor_y[i] < drop_y[droplet_idx] &&
              drop_x[droplet_idx] >= sensor_x1[i] &&
              drop_x[droplet_idx] <= sensor_x2[i] &&
              sensor_y[i] > max_sensor_y) begin
            max_sensor_y <= sensor_y[i];
            max_sensor_idx <= i;
          end
        end
        // If sensor found, mark as destroyed and record result
        if (max_sensor_y > 0) begin
          current_result[droplet_idx] <= max_sensor_y;
          active_sensors[max_sensor_idx] <= 0;
          active_droplets[droplet_idx] <= 0;
        end
      end
      // Move to next droplet
      if (droplet_idx < num_droplets - 1) begin
        droplet_idx <= droplet_idx + 1;
      end else begin
        droplet_idx <= 0;
        sensor_idx <= sensor_idx + 1;
      end
    end else if (state == WRITING) begin
      // Write results to output
      for (int i = 0; i < 8; i++) begin
        result[i] <= current_result[i];
      end
      done <= 1;
    end else if (state == DONE) begin
      done <= 1;
    end
  end

endmodule