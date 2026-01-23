module attendance_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] student_name_in,
  input [2:0] required_name_in,
  output reg [7:0] total_inspections,
  output reg [7:0] position_history [0:7],
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_QUEUE,
    LOAD_LIST,
    SIMULATE,
    OUTPUT_RESULT
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] student_queue [0:7];
  reg [2:0] required_list [0:7];
  reg [2:0] current_front;
  reg [7:0] queue_ptr;
  reg [7:0] list_ptr;
  reg [7:0] inspections;
  reg [7:0] history_ptr;
  reg [7:0] position_temp [0:7];
  reg [7:0] cycle_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      queue_ptr <= 0;
      list_ptr <= 0;
      inspections <= 0;
      history_ptr <= 0;
      cycle_count <= 0;
      done <= 0;
      total_inspections <= 0;
      for (int i = 0; i < 8; i++) begin
        student_queue[i] <= 0;
        required_list[i] <= 0;
        position_history[i] <= 0;
        position_temp[i] <= 0;
      end
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            next_state <= LOAD_QUEUE;
          end
        end

        LOAD_QUEUE: begin
          if (queue_ptr < 8) begin
            student_queue[queue_ptr] <= student_name_in;
            queue_ptr <= queue_ptr + 1;
          end else begin
            next_state <= LOAD_LIST;
          end
        end

        LOAD_LIST: begin
          if (list_ptr < 8) begin
            required_list[list_ptr] <= required_name_in;
            list_ptr <= list_ptr + 1;
          end else begin
            next_state <= SIMULATE;
            current_front <= student_queue[0];
          end
        end

        SIMULATE: begin
          if (cycle_count < 500) begin
            cycle_count <= cycle_count + 1;
            if (current_front == required_list[0]) begin
              // Match: strike name, move to front (position 1)
              position_temp[history_ptr] <= 1;
              inspections <= inspections + 1;
              history_ptr <= history_ptr + 1;

              // Remove from list
              for (int i = 0; i < 7; i++) begin
                required_list[i] <= required_list[i+1];
              end
              required_list[7] <= 0;

              // Move to front (position 1)
              for (int i = 0; i < 7; i++) begin
                student_queue[i] <= student_queue[i+1];
              end
              student_queue[7] <= current_front;
              current_front <= student_queue[0];
            end else begin
              // No match: move to back (position 8)
              position_temp[history_ptr] <= 8;
              inspections <= inspections + 1;
              history_ptr <= history_ptr + 1;

              // Move to back
              for (int i = 0; i < 7; i++) begin
                student_queue[i] <= student_queue[i+1];
              end
              student_queue[7] <= current_front;
              current_front <= student_queue[0];
            end

            // Check if list is empty
            if (required_list[0] == 0) begin
              next_state <= OUTPUT_RESULT;
            end
          end else begin
            next_state <= OUTPUT_RESULT;
          end
        end

        OUTPUT_RESULT: begin
          done <= 1;
          total_inspections <= inspections;
          for (int i = 0; i < 8; i++) begin
            position_history[i] <= position_temp[i];
          end
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
  end

endmodule