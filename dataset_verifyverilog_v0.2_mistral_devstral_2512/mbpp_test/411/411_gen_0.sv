module snake_to_camel (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] char_index,
  input [3:0] num_chars,
  output reg [7:0] char_out,
  output reg [3:0] out_index,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CAP_FIRST,
    CAP_AFTER_UNDERSCORE,
    OUTPUT_CHAR,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] current_index;
  reg capitalize_next;
  reg [7:0] processed_char;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_index <= 0;
      capitalize_next <= 1'b0;
      char_out <= 8'b0;
      out_index <= 4'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      if (next_state == OUTPUT_CHAR) begin
        current_index <= current_index + 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CAP_FIRST;
      end
      CAP_FIRST: begin
        next_state = OUTPUT_CHAR;
      end
      CAP_AFTER_UNDERSCORE: begin
        next_state = OUTPUT_CHAR;
      end
      OUTPUT_CHAR: begin
        if (current_index == num_chars - 1) begin
          next_state = DONE;
        end else begin
          if (char_in == 8'h5F) begin  // underscore
            next_state = CAP_AFTER_UNDERSCORE;
          end else begin
            next_state = OUTPUT_CHAR;
          end
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(*) begin
    char_out = 8'b0;
    out_index = 4'b0;
    done = 1'b0;
    case (current_state)
      CAP_FIRST: begin
        if (char_in >= 8'h61 && char_in <= 8'h7A) begin  // lowercase
          processed_char = char_in - 8'h20;  // convert to uppercase
        end else begin
          processed_char = char_in;
        end
        capitalize_next = 1'b0;
      end
      CAP_AFTER_UNDERSCORE: begin
        if (char_in >= 8'h61 && char_in <= 8'h7A) begin  // lowercase
          processed_char = char_in - 8'h20;  // convert to uppercase
        end else begin
          processed_char = char_in;
        end
        capitalize_next = 1'b0;
      end
      OUTPUT_CHAR: begin
        if (capitalize_next) begin
          if (char_in >= 8'h61 && char_in <= 8'h7A) begin  // lowercase
            processed_char = char_in - 8'h20;  // convert to uppercase
          end else begin
            processed_char = char_in;
          end
          capitalize_next = 1'b0;
        end else begin
          processed_char = char_in;
        end
        char_out = processed_char;
        out_index = current_index;
        if (char_in == 8'h5F) begin  // underscore
          capitalize_next = 1'b1;
        end
      end
      DONE: begin
        done = 1'b1;
      end
    endcase
  end

endmodule