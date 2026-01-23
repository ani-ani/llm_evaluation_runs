module count_element_in_list (
  input clk,
  input rst_n,
  input start,
  input [7:0] target_element,
  input [3:0][3:0][7:0] sublists,
  output reg [1:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [1:0] sublist_counter;
  reg [1:0] element_counter;
  reg [1:0] temp_result;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      sublist_counter <= 0;
      element_counter <= 0;
      temp_result <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == PROCESSING) begin
        if (element_counter == 3) begin
          sublist_counter <= sublist_counter + 1;
          element_counter <= 0;
        end else begin
          element_counter <= element_counter + 1;
        end
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (sublist_counter == 3 && element_counter == 3) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Processing logic
  always @(*) begin
    case (current_state)
      PROCESSING: begin
        // Check if current element matches target
        reg element_match = (sublists[sublist_counter][element_counter] == target_element);
        
        // Check if any element in current sublist matches
        reg sublist_has_match = |(
          sublists[sublist_counter][0] == target_element,
          sublists[sublist_counter][1] == target_element,
          sublists[sublist_counter][2] == target_element,
          sublists[sublist_counter][3] == target_element
        );
        
        // Update temporary result when moving to next sublist
        if (element_counter == 3) begin
          if (sublist_has_match) temp_result = temp_result + 1;
        end
      end
      DONE: temp_result = temp_result;
      default: temp_result = 0;
    endcase
  end

  // Output logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        result = 0;
        done = 0;
      end
      PROCESSING: begin
        result = 0;
        done = 0;
      end
      DONE: begin
        result = temp_result;
        done = 1;
      end
    endcase
  end

endmodule