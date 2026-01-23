module jackpot_checker (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_inputs,
  input [15:0] data_in,
  input data_valid,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COLLECT,
    PROCESS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] stored_values [0:7];
  reg [2:0] input_count;
  reg [15:0] core_calc;
  reg [2:0] process_index;
  reg [15:0] first_core;
  reg mismatch_flag;
  reg [9:0] cycle_counter;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      input_count <= 0;
      process_index <= 0;
      cycle_counter <= 0;
      mismatch_flag <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end
      COLLECT: begin
        if (input_count == num_inputs - 1 && data_valid) next_state = PROCESS;
      end
      PROCESS: begin
        if (process_index == num_inputs - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Data collection logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      input_count <= 0;
    end else if (current_state == COLLECT && data_valid) begin
      if (input_count < num_inputs) begin
        stored_values[input_count] <= data_in;
        input_count <= input_count + 1;
      end
    end
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      process_index <= 0;
      core_calc <= 0;
      first_core <= 0;
      mismatch_flag <= 0;
      cycle_counter <= 0;
    end else if (current_state == PROCESS) begin
      if (cycle_counter == 0) begin
        // Initialize core calculation for current number
        core_calc <= stored_values[process_index];
        cycle_counter <= cycle_counter + 1;
      end else begin
        // Core calculation loop
        if (core_calc % 2 == 0) begin
          core_calc <= core_calc / 2;
        end else if (core_calc % 3 == 0) begin
          core_calc <= core_calc / 3;
        end else begin
          // Core calculation complete
          if (process_index == 0) begin
            first_core <= core_calc;
          end else if (core_calc != first_core) begin
            mismatch_flag <= 1;
          end
          process_index <= process_index + 1;
          cycle_counter <= 0;
        end
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == DONE) begin
      result <= !mismatch_flag;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule