module text_match_z_middle (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [2:0] char_index,
  input char_valid,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] position_counter;
  reg z_found_flag;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      position_counter <= 0;
      z_found_flag <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == PROCESSING && char_valid) begin
        position_counter <= char_index;
        if (char_in == 8'h7A && char_index != 0 && char_index != 7) begin
          z_found_flag <= 1;
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
      end
      PROCESSING: begin
        if (char_index == 7 && char_valid) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(*) begin
    result = 0;
    done = 0;
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
        result = z_found_flag;
        done = 1;
      end
    endcase
  end

endmodule