module remove_parenthesis (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input char_valid,
  output reg [7:0] char_out,
  output reg char_out_valid,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    COPY_CHAR,
    SKIP_CHARS,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg inside_parenthesis;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      inside_parenthesis <= 1'b0;
      char_out <= 8'b0;
      char_out_valid <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      if (current_state == COPY_CHAR && char_valid) begin
        if (char_in == 8'h28) begin // '('
          inside_parenthesis <= 1'b1;
        end else if (char_in == 8'h29) begin // ')'
          // Error case: unmatched ')', stay in SKIP_CHARS
          inside_parenthesis <= 1'b1;
        end else if (char_in == 8'h00) begin // null terminator
          inside_parenthesis <= 1'b0;
        end
      end else if (current_state == SKIP_CHARS && char_valid) begin
        if (char_in == 8'h29) begin // ')'
          inside_parenthesis <= 1'b0;
        end else if (char_in == 8'h00) begin // null terminator
          inside_parenthesis <= 1'b0;
        end
      end
    end
  end

  always @(*) begin
    next_state = current_state;
    char_out = 8'b0;
    char_out_valid = 1'b0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = COPY_CHAR;
        end
      end

      COPY_CHAR: begin
        if (char_valid) begin
          if (char_in == 8'h28) begin // '('
            next_state = SKIP_CHARS;
          end else if (char_in == 8'h00) begin // null terminator
            next_state = DONE;
            char_out = 8'b0;
            char_out_valid = 1'b1;
          end else begin
            char_out = char_in;
            char_out_valid = 1'b1;
          end
        end
      end

      SKIP_CHARS: begin
        if (char_valid) begin
          if (char_in == 8'h29) begin // ')'
            next_state = COPY_CHAR;
          end else if (char_in == 8'h00) begin // null terminator
            next_state = DONE;
            char_out = 8'b0;
            char_out_valid = 1'b1;
          end
        end
      end

      DONE: begin
        char_out = 8'b0;
        char_out_valid = 1'b0;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      if (current_state == DONE) begin
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule