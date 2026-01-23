module leader_determiner #(
  parameter N = 8,  // Number of participants (max 8)
  parameter M = 16  // Number of log messages (max 16)
) (
  input clk,
  input rst_n,
  input start,
  input [3:0] msg_id,
  input msg_type,
  input msg_valid,
  output reg [N-1:0] possible_leaders,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_MSG,
    PROCESS_MSG,
    UPDATE_STATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] msg_counter;
  reg [N-1:0] active_participants;
  reg [N-1:0] gap_detected;
  reg [3:0] current_msg_id;
  reg current_msg_type;
  reg current_msg_valid;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      msg_counter <= 0;
      active_participants <= 0;
      gap_detected <= 0;
      possible_leaders <= {(N){1'b1}};
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
        if (start) next_state = LOAD_MSG;
      end
      LOAD_MSG: begin
        next_state = PROCESS_MSG;
      end
      PROCESS_MSG: begin
        next_state = UPDATE_STATE;
      end
      UPDATE_STATE: begin
        if (msg_counter == M-1) next_state = DONE;
        else next_state = LOAD_MSG;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load message data
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_msg_id <= 0;
      current_msg_type <= 0;
      current_msg_valid <= 0;
    end else begin
      if (current_state == LOAD_MSG && msg_valid) begin
        current_msg_id <= msg_id;
        current_msg_type <= msg_type;
        current_msg_valid <= msg_valid;
      end
    end
  end

  // Process message and update state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      msg_counter <= 0;
      active_participants <= 0;
      gap_detected <= 0;
    end else begin
      case (current_state)
        LOAD_MSG: begin
          if (msg_valid) msg_counter <= msg_counter + 1;
        end
        PROCESS_MSG: begin
          if (current_msg_valid) begin
            // Update active participants
            if (current_msg_type) begin  // Log on
              active_participants <= active_participants | (1 << (current_msg_id - 1));
            end else begin  // Log off
              active_participants <= active_participants & ~(1 << (current_msg_id - 1));
            end
          end
        end
        UPDATE_STATE: begin
          if (current_msg_valid) begin
            // Check for gaps
            if (!current_msg_type) begin  // Only check on log off
              if (active_participants != 0) begin
                gap_detected <= gap_detected | (1 << (current_msg_id - 1));
              end
            end
            // Update possible leaders
            possible_leaders <= {(N){1'b1}} & ~gap_detected;
          end
        end
        DONE: begin
          done <= 1;
        end
        default: ;
      endcase
    end
  end

endmodule