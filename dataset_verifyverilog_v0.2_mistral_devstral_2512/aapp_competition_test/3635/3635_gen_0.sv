module executive_reward (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_briefcases,
  input [23:0] bananas [0:7],
  output reg [7:0] max_executives,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] briefcase_idx;
  reg [2:0] group_idx;
  reg [23:0] current_sum;
  reg [23:0] prev_sum;
  reg [7:0] executive_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      briefcase_idx <= 0;
      group_idx <= 0;
      current_sum <= 0;
      prev_sum <= 0;
      executive_count <= 0;
      max_executives <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          briefcase_idx <= 0;
          group_idx <= 0;
          current_sum <= 0;
          prev_sum <= 0;
          executive_count <= 0;
          max_executives <= 0;
          done <= 0;
        end

        COMPUTE: begin
          if (briefcase_idx == num_briefcases) begin
            // All briefcases processed
            max_executives <= executive_count;
            done <= 1;
          end else begin
            // Add current briefcase to current group
            current_sum <= current_sum + bananas[briefcase_idx];

            // Check if we can form a new group
            if (current_sum >= prev_sum) begin
              executive_count <= executive_count + 1;
              prev_sum <= current_sum;
              current_sum <= 0;
              group_idx <= group_idx + 1;
            end

            briefcase_idx <= briefcase_idx + 1;
          end
        end

        DONE: begin
          // Wait for reset
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = COMPUTE;
        end
      end

      COMPUTE: begin
        if (briefcase_idx == num_briefcases) begin
          next_state = DONE;
        end
      end

      DONE: begin
        if (!rst_n) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule