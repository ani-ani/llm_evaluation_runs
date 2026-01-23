module bracket_nested_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] char_array,
  output reg result,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [2:0] depth = 0;
  reg nested_flag = 0;
  reg valid_flag = 1;
  reg [2:0] index = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      depth <= 0;
      nested_flag <= 0;
      valid_flag <= 1;
      index <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            depth <= 0;
            nested_flag <= 0;
            valid_flag <= 1;
            index <= 0;
            result <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (index == 8) begin
            state <= DONE;
            result <= (valid_flag && nested_flag && (depth == 0)) ? 1 : 0;
            done <= 1;
          end else begin
            if (char_array[index] == 8'h5B) begin // '['
              depth <= depth + 1;
              if (depth > 1) nested_flag <= 1;
            end else if (char_array[index] == 8'h5D) begin // ']'
              depth <= depth - 1;
              if (depth < 0) valid_flag <= 0;
            end
            index <= index + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule