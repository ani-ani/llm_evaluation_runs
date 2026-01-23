module vowel_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input char_valid,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK_FIRST,
    DONE
  } state_t;

  state_t current_state, next_state;

  // First character storage
  reg [7:0] first_char;
  reg first_char_received;

  // Vowel detection logic (combinational)
  wire first_char_is_vowel = 
    (first_char == 8'h61) || (first_char == 8'h65) || 
    (first_char == 8'h69) || (first_char == 8'h6F) || 
    (first_char == 8'h75) || (first_char == 8'h41) || 
    (first_char == 8'h45) || (first_char == 8'h49) || 
    (first_char == 8'h4F) || (first_char == 8'h55);

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      first_char_received <= 0;
      first_char <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_FIRST;
        end
      end
      CHECK_FIRST: begin
        if (char_valid) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          result <= 0;
          done <= 0;
        end
        CHECK_FIRST: begin
          if (char_valid && !first_char_received) begin
            first_char <= char_in;
            first_char_received <= 1;
          end
          result <= 0;
          done <= 0;
        end
        DONE: begin
          result <= first_char_is_vowel;
          done <= 1;
        end
      endcase
    end
  end

endmodule