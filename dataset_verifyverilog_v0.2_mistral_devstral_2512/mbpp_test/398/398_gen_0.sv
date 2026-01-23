module sum_of_digits (
  input clk,
  input rst_n,
  input start,
  input [7:0] num_count,
  input [63:0] str_data [0:7],
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    PARSE_CHAR,
    NEXT_CHAR,
    NEXT_NUMBER,
    DONE
  } state_t;

  // Internal registers
  state_t current_state, next_state;
  reg [2:0] current_num_index;
  reg [2:0] current_char_index;
  reg [15:0] running_sum;
  reg [7:0] temp_sum;
  reg [7:0] current_byte;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_num_index <= 0;
      current_char_index <= 0;
      running_sum <= 0;
      temp_sum <= 0;
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
        if (start) begin
          next_state = PARSE_CHAR;
          current_num_index = 0;
          current_char_index = 0;
          running_sum = 0;
          temp_sum = 0;
          done = 0;
        end
      end
      PARSE_CHAR: begin
        current_byte = str_data[current_num_index][(current_char_index << 3) +: 8];
        if (current_byte >= "0" && current_byte <= "9") begin
          temp_sum = temp_sum + (current_byte - "0");
        end
        next_state = NEXT_CHAR;
      end
      NEXT_CHAR: begin
        if (current_char_index < 7) begin
          current_char_index = current_char_index + 1;
          next_state = PARSE_CHAR;
        end else begin
          running_sum = running_sum + temp_sum;
          temp_sum = 0;
          next_state = NEXT_NUMBER;
        end
      end
      NEXT_NUMBER: begin
        if (current_num_index < num_count - 1) begin
          current_num_index = current_num_index + 1;
          current_char_index = 0;
          next_state = PARSE_CHAR;
        end else begin
          next_state = DONE;
        end
      end
      DONE: begin
        result = running_sum;
        done = 1;
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

endmodule