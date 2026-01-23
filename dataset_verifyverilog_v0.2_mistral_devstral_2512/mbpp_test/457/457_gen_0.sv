module find_min_sublist (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_sublists,
  input [2:0] sublist_lengths [0:3],
  input [7:0] all_elements [0:31],
  output reg [2:0] min_index,
  output reg [2:0] min_length,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    FIND_MIN,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] current_index;
  reg [2:0] current_min_index;
  reg [2:0] current_min_length;
  reg [1:0] cycle_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_index <= 0;
      current_min_index <= 0;
      current_min_length <= 0;
      cycle_count <= 0;
      min_index <= 0;
      min_length <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          if (start) begin
            current_index <= 0;
            current_min_index <= 0;
            current_min_length <= sublist_lengths[0];
            cycle_count <= 0;
          end
        end
        
        FIND_MIN: begin
          if (cycle_count < 3) begin
            current_index <= current_index + 1;
            if (sublist_lengths[current_index] < current_min_length && current_index < num_sublists) begin
              current_min_length <= sublist_lengths[current_index];
              current_min_index <= current_index;
            end
            cycle_count <= cycle_count + 1;
          end
        end
        
        DONE: begin
          min_index <= current_min_index;
          min_length <= current_min_length;
          done <= 1;
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
          next_state = FIND_MIN;
        end
      end
      
      FIND_MIN: begin
        if (cycle_count == 3) begin
          next_state = DONE;
        end
      end
      
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule