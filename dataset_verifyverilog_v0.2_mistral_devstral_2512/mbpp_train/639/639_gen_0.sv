module name_filter_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_data,
  input valid_char,
  output reg [2:0] name_addr,
  output reg [2:0] char_addr,
  output reg fetch_next,
  output reg [7:0] result,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    FETCH_NAME,
    FETCH_CHAR,
    VALIDATE,
    COUNT_LENGTH,
    ADD_TO_SUM,
    NEXT_NAME,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] current_name_idx;
  reg [2:0] current_char_idx;
  reg [7:0] current_name_length;
  reg [7:0] total_sum;
  reg [7:0] current_char;
  reg is_valid_name;
  reg is_first_char;
  reg is_null_char;

  // Character validation logic
  wire is_uppercase = (char_data >= 8'h41 && char_data <= 8'h5A);
  wire is_lowercase = (char_data >= 8'h61 && char_data <= 8'h7A);
  wire is_valid_char = (is_first_char && is_uppercase) || (!is_first_char && is_lowercase);

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_name_idx <= 0;
      current_char_idx <= 0;
      current_name_length <= 0;
      total_sum <= 0;
      is_valid_name <= 1;
      is_first_char <= 1;
      is_null_char <= 0;
      result <= 0;
      done <= 0;
      error <= 0;
      name_addr <= 0;
      char_addr <= 0;
      fetch_next <= 0;
    end else begin
      current_state <= next_state;

      // State-specific actions
      case (current_state)
        IDLE: begin
          if (start) begin
            current_name_idx <= 0;
            current_char_idx <= 0;
            current_name_length <= 0;
            total_sum <= 0;
            is_valid_name <= 1;
            is_first_char <= 1;
            is_null_char <= 0;
            result <= 0;
            done <= 0;
            error <= 0;
          end
        end

        FETCH_NAME: begin
          name_addr <= current_name_idx;
          char_addr <= 0;
          current_char_idx <= 0;
          is_first_char <= 1;
          is_null_char <= 0;
        end

        FETCH_CHAR: begin
          if (valid_char) begin
            current_char <= char_data;
            is_null_char <= (char_data == 8'h00);
          end
        end

        VALIDATE: begin
          if (!is_valid_char) begin
            is_valid_name <= 0;
          end
        end

        COUNT_LENGTH: begin
          if (!is_null_char) begin
            current_name_length <= current_name_length + 1;
          end
        end

        ADD_TO_SUM: begin
          if (is_valid_name) begin
            total_sum <= total_sum + current_name_length;
          end
        end

        NEXT_NAME: begin
          current_name_idx <= current_name_idx + 1;
          current_char_idx <= 0;
          current_name_length <= 0;
          is_valid_name <= 1;
          is_first_char <= 1;
          is_null_char <= 0;
        end

        DONE: begin
          result <= total_sum;
          done <= 1;
        end

        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    fetch_next = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = FETCH_NAME;
        end
      end

      FETCH_NAME: begin
        next_state = FETCH_CHAR;
        fetch_next = 1;
      end

      FETCH_CHAR: begin
        if (valid_char) begin
          next_state = VALIDATE;
        end
      end

      VALIDATE: begin
        next_state = COUNT_LENGTH;
      end

      COUNT_LENGTH: begin
        if (current_char_idx == 7) begin
          next_state = ADD_TO_SUM;
        end else begin
          current_char_idx <= current_char_idx + 1;
          is_first_char <= 0;
          next_state = FETCH_CHAR;
          fetch_next = 1;
          char_addr <= current_char_idx + 1;
        end
      end

      ADD_TO_SUM: begin
        if (current_name_idx == 7) begin
          next_state = DONE;
        end else begin
          next_state = NEXT_NAME;
        end
      end

      NEXT_NAME: begin
        next_state = FETCH_NAME;
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done <= 0;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule