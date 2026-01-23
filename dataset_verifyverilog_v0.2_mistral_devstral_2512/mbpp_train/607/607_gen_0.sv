module string_matcher (
  input clk,
  input rst_n,
  input start,
  input [7:0] text [0:7],
  input [7:0] pattern [0:3],
  input [2:0] pattern_length,
  output reg [2:0] start_index,
  output reg [2:0] end_index,
  output reg found,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COMPARE,
    SLIDE,
    FOUND,
    NOT_FOUND
  } state_t;

  state_t current_state, next_state;
  reg [2:0] current_pos;
  reg [2:0] match_pos;
  reg [2:0] counter;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      start_index <= 0;
      end_index <= 0;
      found <= 0;
      done <= 0;
      current_pos <= 0;
      match_pos <= 0;
      counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State transition logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = COMPARE;
          current_pos = 0;
          match_pos = 0;
          counter = 0;
        end
      end
      COMPARE: begin
        if (text[current_pos] == pattern[match_pos]) begin
          if (match_pos == pattern_length - 1) begin
            next_state = FOUND;
          end else begin
            match_pos = match_pos + 1;
            counter = counter + 1;
          end
        end else begin
          next_state = SLIDE;
        end
      end
      SLIDE: begin
        if (current_pos == 7 - pattern_length + 1) begin
          next_state = NOT_FOUND;
        end else begin
          current_pos = current_pos + 1;
          match_pos = 0;
          next_state = COMPARE;
        end
      end
      FOUND: begin
        next_state = IDLE;
      end
      NOT_FOUND: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_index <= 0;
      end_index <= 0;
      found <= 0;
      done <= 0;
    end else begin
      case (current_state)
        FOUND: begin
          start_index <= current_pos;
          end_index <= current_pos + pattern_length;
          found <= 1;
          done <= 1;
        end
        NOT_FOUND: begin
          start_index <= 0;
          end_index <= 0;
          found <= 0;
          done <= 1;
        end
        default: begin
          start_index <= 0;
          end_index <= 0;
          found <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule