module min_phone_calls (
  input clk,
  input rst_n,
  input start,
  input [4:0] detector_index,
  input [15:0] position,
  input [31:0] call_count,
  input [4:0] num_detectors,
  input data_valid,
  output reg [31:0] min_calls,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_DATA,
    SORT_CHECK,
    PROCESS_DATA,
    COMPUTE_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [4:0] internal_index;
  reg [15:0] prev_position;
  reg [31:0] cumulative_max;
  reg [31:0] accumulated_sum;
  reg [31:0] detector_positions [0:31];
  reg [31:0] detector_counts [0:31];
  reg [4:0] loaded_detectors;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      internal_index <= 0;
      prev_position <= 0;
      cumulative_max <= 0;
      accumulated_sum <= 0;
      loaded_detectors <= 0;
      min_calls <= 0;
      done <= 0;
      error <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_DATA;
      end
      LOAD_DATA: begin
        if (loaded_detectors == num_detectors - 1) next_state = SORT_CHECK;
      end
      SORT_CHECK: begin
        if (internal_index == num_detectors - 1) next_state = PROCESS_DATA;
        else if (error) next_state = DONE;
      end
      PROCESS_DATA: begin
        if (internal_index == num_detectors - 1) next_state = COMPUTE_RESULT;
      end
      COMPUTE_RESULT: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Data loading
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      loaded_detectors <= 0;
    end else if (current_state == LOAD_DATA && data_valid) begin
      detector_positions[detector_index] <= position;
      detector_counts[detector_index] <= call_count;
      loaded_detectors <= loaded_detectors + 1;
    end
  end

  // Sort check
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      internal_index <= 0;
      error <= 0;
    end else if (current_state == SORT_CHECK) begin
      if (internal_index == 0) begin
        prev_position <= detector_positions[0];
        internal_index <= internal_index + 1;
      end else begin
        if (detector_positions[internal_index] <= prev_position) begin
          error <= 1;
        end
        prev_position <= detector_positions[internal_index];
        internal_index <= internal_index + 1;
      end
    end
  end

  // Processing data
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      internal_index <= 0;
      cumulative_max <= 0;
      accumulated_sum <= 0;
    end else if (current_state == PROCESS_DATA) begin
      if (internal_index == 0) begin
        cumulative_max <= detector_counts[0];
        accumulated_sum <= detector_counts[0];
        internal_index <= internal_index + 1;
      end else begin
        // Update cumulative max
        if (detector_counts[internal_index] > cumulative_max) begin
          cumulative_max <= detector_counts[internal_index];
        end
        // Accumulate non-overlapping portions
        accumulated_sum <= accumulated_sum + detector_counts[internal_index];
        internal_index <= internal_index + 1;
      end
    end
  end

  // Compute result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_calls <= 0;
      done <= 0;
    end else if (current_state == COMPUTE_RESULT) begin
      min_calls <= (cumulative_max > accumulated_sum) ? cumulative_max : accumulated_sum;
      done <= 1;
    end else if (current_state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule