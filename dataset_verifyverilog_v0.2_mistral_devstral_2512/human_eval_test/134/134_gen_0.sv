module check_if_last_char_is_a_letter (
  input clk,
  input rst_n,
  input start,
  input [127:0] string_data,
  input [3:0] string_len,
  output reg result,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end
      PROCESSING: begin
        next_state = DONE;
      end
      DONE: begin
        if (start) begin
          next_state = PROCESSING;
        end else begin
          next_state = IDLE;
        end
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == PROCESSING) begin
      result <= compute_result(string_data, string_len);
      done <= 1;
    end else if (current_state == DONE && start) begin
      done <= 0;
    end
  end

  function automatic logic compute_result(input [127:0] str_data, input [3:0] str_len);
    logic is_letter;
    logic is_standalone;
    logic [7:0] last_char;
    logic [7:0] prev_char;

    if (str_len == 0) begin
      return 0;
    end

    last_char = str_data[(str_len * 8 - 1):(str_len * 8 - 8)];

    is_letter = (last_char >= 8'h41 && last_char <= 8'h5A) || (last_char >= 8'h61 && last_char <= 8'h7A);

    if (!is_letter) begin
      return 0;
    end

    if (str_len == 1) begin
      return 1;
    end

    prev_char = str_data[(str_len * 8 - 9):(str_len * 8 - 16)];

    if (prev_char == 8'h20) begin
      return 1;
    end

    return 0;
  endfunction

endmodule