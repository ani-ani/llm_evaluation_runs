module lane_switch_safety #(
  parameter NUM_LANES = 4,
  parameter MAX_CARS_PER_LANE = 8,
  parameter SENSOR_RANGE = 256,
  parameter ACM_CAR_LENGTH = 10,
  parameter ACM_CAR_POSITION = 10
)(
  input clk,
  input rst_n,
  input start,
  input [3:0] total_cars_input,
  input [1:0] car_lane [0:15],
  input [7:0] car_length [0:15],
  input [17:0] car_distance [0:15],
  output reg [31:0] safety_factor_result,
  output reg result_valid,
  output reg impossible,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_INPUT,
    FIND_GAPS,
    CHECK_SWITCH,
    CALC_SAFETY,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] total_cars;
  reg [1:0] lane_cars [0:NUM_LANES-1];
  reg [7:0] lane_car_length [0:NUM_LANES-1][0:MAX_CARS_PER_LANE-1];
  reg [17:0] lane_car_distance [0:NUM_LANES-1][0:MAX_CARS_PER_LANE-1];

  reg [17:0] sorted_distances [0:NUM_LANES-1][0:MAX_CARS_PER_LANE-1];
  reg [7:0] sorted_lengths [0:NUM_LANES-1][0:MAX_CARS_PER_LANE-1];

  reg [17:0] gaps [0:NUM_LANES-1][0:MAX_CARS_PER_LANE];
  reg [17:0] min_gap [0:NUM_LANES-1];

  reg [31:0] current_safety_factor;
  reg [31:0] min_safety_factor;

  reg [1:0] current_lane;
  reg [3:0] car_index;
  reg [3:0] gap_index;
  reg [3:0] sort_index_i;
  reg [3:0] sort_index_j;
  reg [3:0] temp;

  reg [17:0] temp_distance;
  reg [7:0] temp_length;

  reg [17:0] acm_car_position_q;
  reg [7:0] acm_car_length_q;

  // Initialize ACM car in Q16.16 format
  initial begin
    acm_car_position_q = ACM_CAR_POSITION * 65536;
    acm_car_length_q = ACM_CAR_LENGTH;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      safety_factor_result <= 32'h0;
      result_valid <= 1'b0;
      impossible <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = READ_INPUT;
      end
      READ_INPUT: begin
        if (car_index == total_cars) next_state = FIND_GAPS;
      end
      FIND_GAPS: begin
        if (current_lane == NUM_LANES-1 && gap_index == lane_cars[current_lane]+1) next_state = CHECK_SWITCH;
      end
      CHECK_SWITCH: begin
        if (current_lane == NUM_LANES-1) next_state = CALC_SAFETY;
      end
      CALC_SAFETY: begin
        if (current_lane == NUM_LANES-1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_cars <= 0;
      car_index <= 0;
      current_lane <= 0;
      gap_index <= 0;
      sort_index_i <= 0;
      sort_index_j <= 0;
      min_safety_factor <= 32'h7FFFFFFF; // Initialize to max value
      current_safety_factor <= 0;
      result_valid <= 0;
      impossible <= 0;
      done <= 0;

      // Initialize lane car counts
      for (int i = 0; i < NUM_LANES; i++) begin
        lane_cars[i] <= 0;
        min_gap[i] <= 18'h3FFFF; // Initialize to max value
      end

      // Initialize car data arrays
      for (int i = 0; i < NUM_LANES; i++) begin
        for (int j = 0; j < MAX_CARS_PER_LANE; j++) begin
          lane_car_length[i][j] <= 0;
          lane_car_distance[i][j] <= 0;
          sorted_distances[i][j] <= 0;
          sorted_lengths[i][j] <= 0;
        end
      end

      // Initialize gaps
      for (int i = 0; i < NUM_LANES; i++) begin
        for (int j = 0; j < MAX_CARS_PER_LANE+1; j++) begin
          gaps[i][j] <= 0;
        end
      end
    end else begin
      case (current_state)
        IDLE: begin
          // Reset outputs
          result_valid <= 0;
          impossible <= 0;
          done <= 0;
        end

        READ_INPUT: begin
          if (car_index < total_cars_input) begin
            // Store car data in appropriate lane
            int lane = car_lane[car_index];
            int count = lane_cars[lane];
            if (count < MAX_CARS_PER_LANE) begin
              lane_car_length[lane][count] <= car_length[car_index];
              lane_car_distance[lane][count] <= car_distance[car_index];
              lane_cars[lane] <= count + 1;
            end
            car_index <= car_index + 1;
          end
        end

        FIND_GAPS: begin
          // Sort cars by distance in each lane (bubble sort)
          if (sort_index_i < lane_cars[current_lane]) begin
            if (sort_index_j < lane_cars[current_lane] - sort_index_i - 1) begin
              if (lane_car_distance[current_lane][sort_index_j] > lane_car_distance[current_lane][sort_index_j+1]) begin
                // Swap distances
                temp_distance <= lane_car_distance[current_lane][sort_index_j];
                lane_car_distance[current_lane][sort_index_j] <= lane_car_distance[current_lane][sort_index_j+1];
                lane_car_distance[current_lane][sort_index_j+1] <= temp_distance;

                // Swap lengths
                temp_length <= lane_car_length[current_lane][sort_index_j];
                lane_car_length[current_lane][sort_index_j] <= lane_car_length[current_lane][sort_index_j+1];
                lane_car_length[current_lane][sort_index_j+1] <= temp_length;
              end
              sort_index_j <= sort_index_j + 1;
            end else begin
              sort_index_j <= 0;
              sort_index_i <= sort_index_i + 1;
            end
          end else begin
            // Copy sorted data
            for (int i = 0; i < lane_cars[current_lane]; i++) begin
              sorted_distances[current_lane][i] <= lane_car_distance[current_lane][i];
              sorted_lengths[current_lane][i] <= lane_car_length[current_lane][i];
            end

            // Calculate gaps
            if (gap_index == 0) begin
              // Gap before first car
              gaps[current_lane][0] <= sorted_distances[current_lane][0];
            end else if (gap_index <= lane_cars[current_lane]) begin
              if (gap_index == lane_cars[current_lane]) begin
                // Gap after last car
                gaps[current_lane][gap_index] <= (SENSOR_RANGE << 16) - (sorted_distances[current_lane][gap_index-1] + sorted_lengths[current_lane][gap_index-1]);
              end else begin
                // Gap between cars
                gaps[current_lane][gap_index] <= sorted_distances[current_lane][gap_index] - (sorted_distances[current_lane][gap_index-1] + sorted_lengths[current_lane][gap_index-1]);
              end
            end

            // Find minimum gap in lane
            if (gap_index <= lane_cars[current_lane]) begin
              if (gaps[current_lane][gap_index] < min_gap[current_lane]) begin
                min_gap[current_lane] <= gaps[current_lane][gap_index];
              end
              gap_index <= gap_index + 1;
            end else begin
              // Move to next lane
              current_lane <= current_lane + 1;
              sort_index_i <= 0;
              sort_index_j <= 0;
              gap_index <= 0;
            end
          end
        end

        CHECK_SWITCH: begin
          // Check if switch from current_lane to current_lane+1 is possible
          if (current_lane < NUM_LANES-1) begin
            // Check if there's enough gap in destination lane
            if (min_gap[current_lane+1] >= acm_car_length_q) begin
              // Calculate safety factor for this switch
              current_safety_factor <= (min_gap[current_lane+1] - acm_car_length_q) << 16;
              
              // Update minimum safety factor
              if (current_safety_factor < min_safety_factor) begin
                min_safety_factor <= current_safety_factor;
              end
            end else begin
              // Not enough gap, mark as impossible
              impossible <= 1;
            end
            current_lane <= current_lane + 1;
          end
        end

        CALC_SAFETCH: begin
          // For the final result, we need to consider the entire path
          // This is a simplified version - in a real implementation you'd track the path
          if (current_lane < NUM_LANES-1) begin
            // Check if switch is possible
            if (min_gap[current_lane+1] >= acm_car_length_q) begin
              current_safety_factor <= (min_gap[current_lane+1] - acm_car_length_q) << 16;
              if (current_safety_factor < min_safety_factor) begin
                min_safety_factor <= current_safety_factor;
              end
            end else begin
              impossible <= 1;
            end
            current_lane <= current_lane + 1;
          end
        end

        DONE: begin
          if (!done) begin
            // Output final result
            if (impossible) begin
              safety_factor_result <= 32'h0;
            end else begin
              safety_factor_result <= min_safety_factor;
            end
            result_valid <= 1;
            done <= 1;
          end
        end
      endcase
    end
  end

  // Handle start signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_cars <= 0;
    end else if (start && current_state == IDLE) begin
      total_cars <= total_cars_input;
    end
  end

endmodule