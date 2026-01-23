module calorie_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] m,
  input [3:0] n,
  input [15:0] courses [0:9],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD,
    PROCESS_HOUR,
    UPDATE_STATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] hour_counter;
  reg [2:0] streak_counter;
  reg [1:0] skip_counter;
  reg [1:0] cap_idx;
  reg [31:0] dp_current, dp_next;
  reg [15:0] capacities [0:3];
  reg [31:0] max_result;

  // Precompute capacities
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      capacities[0] <= 16'd0;
      capacities[1] <= 16'd0;
      capacities[2] <= 16'd0;
      capacities[3] <= 16'd0;
    end else if (current_state == LOAD) begin
      capacities[0] <= m;
      capacities[1] <= (m * 2) / 3;
      capacities[2] <= (capacities[1] * 2) / 3;
      capacities[3] <= (capacities[2] * 2) / 3;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      hour_counter <= 4'd0;
      streak_counter <= 3'd0;
      skip_counter <= 2'd0;
      cap_idx <= 2'd0;
      dp_current <= 32'd0;
      dp_next <= 32'd0;
      max_result <= 32'd0;
      result <= 32'd0;
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
        if (start) next_state = LOAD;
      end
      LOAD: begin
        next_state = PROCESS_HOUR;
      end
      PROCESS_HOUR: begin
        next_state = UPDATE_STATE;
      end
      UPDATE_STATE: begin
        if (hour_counter == n - 1) begin
          next_state = DONE;
        end else begin
          next_state = PROCESS_HOUR;
        end
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hour_counter <= 4'd0;
      streak_counter <= 3'd0;
      skip_counter <= 2'd0;
      cap_idx <= 2'd0;
      dp_current <= 32'd0;
      dp_next <= 32'd0;
      max_result <= 32'd0;
    end else if (current_state == PROCESS_HOUR) begin
      // Initialize for new hour
      if (hour_counter == 0) begin
        dp_current <= 32'd0;
        streak_counter <= 3'd0;
        skip_counter <= 2'd0;
        cap_idx <= 2'd0;
      end
    end else if (current_state == UPDATE_STATE) begin
      // Compute next state values
      if (hour_counter < n) begin
        // Option 1: Eat
        if (capacities[cap_idx] >= courses[hour_counter]) begin
          dp_next <= dp_current + courses[hour_counter];
          streak_counter <= streak_counter + 1'b1;
          if (streak_counter > 4'd4) streak_counter <= 4'd4;
          skip_counter <= 2'd0;
          cap_idx <= cap_idx + 1'b1;
          if (cap_idx > 2'd3) cap_idx <= 2'd3;
        end
        // Option 2: Skip
        else begin
          dp_next <= dp_current;
          skip_counter <= skip_counter + 1'b1;
          if (skip_counter > 2'd2) skip_counter <= 2'd2;
          streak_counter <= 3'd0;
          if (skip_counter == 2'd2) cap_idx <= 2'd0;
        end
        
        // Update max result
        if (hour_counter == n - 1) begin
          if (dp_next > max_result) max_result <= dp_next;
        end
        
        // Move to next hour
        hour_counter <= hour_counter + 1'b1;
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 32'd0;
      done <= 1'b0;
    end else if (current_state == DONE) begin
      result <= max_result;
      done <= 1'b1;
    end else begin
      done <= 1'b0;
    end
  end

endmodule