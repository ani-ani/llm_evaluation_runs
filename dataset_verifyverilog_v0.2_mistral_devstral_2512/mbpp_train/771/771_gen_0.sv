module balanced_parentheses (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
  output reg balanced,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] PUSH = 3'b001;
  localparam [2:0] POP = 3'b010;
  localparam [2:0] VALIDATE = 3'b011;
  localparam [2:0] ERROR = 3'b100;
  localparam [2:0] COMPLETE = 3'b101;

  // Stack implementation
  reg [1:0] stack [0:7]; // Each slot holds bracket type (0=None, 1='(', 2='{', 3='[')
  reg [2:0] stack_ptr = 0; // Stack pointer (0-7)

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Character processing
  reg [7:0] current_char;
  reg [2:0] char_index = 0;

  // Bracket detection
  wire is_open_paren = (current_char == 8'h28);
  wire is_close_paren = (current_char == 8'h29);
  wire is_open_brace = (current_char == 8'h7B);
  wire is_close_brace = (current_char == 8'h7D);
  wire is_open_bracket = (current_char == 8'h5B);
  wire is_close_bracket = (current_char == 8'h5D);

  wire is_opening = is_open_paren || is_open_brace || is_open_bracket;
  wire is_closing = is_close_paren || is_close_brace || is_close_bracket;

  // Stack operations
  wire stack_empty = (stack_ptr == 0);
  wire stack_full = (stack_ptr == 7);

  // Character selection
  always @(*) begin
    case (char_index)
      3'd0: current_char = char_0;
      3'd1: current_char = char_1;
      3'd2: current_char = char_2;
      3'd3: current_char = char_3;
      3'd4: current_char = char_4;
      3'd5: current_char = char_5;
      3'd6: current_char = char_6;
      3'd7: current_char = char_7;
      default: current_char = 8'h00;
    endcase
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      stack_ptr <= 0;
      char_index <= 0;
      balanced <= 0;
      done <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        stack[i] <= 0;
      end
    end else begin
      state <= next_state;

      // State actions
      case (state)
        IDLE: begin
          balanced <= 0;
          done <= 0;
          char_index <= 0;
          stack_ptr <= 0;
        end

        PUSH: begin
          if (is_open_paren && !stack_full) begin
            stack[stack_ptr] <= 2'd1;
            stack_ptr <= stack_ptr + 1;
          end else if (is_open_brace && !stack_full) begin
            stack[stack_ptr] <= 2'd2;
            stack_ptr <= stack_ptr + 1;
          end else if (is_open_bracket && !stack_full) begin
            stack[stack_ptr] <= 2'd3;
            stack_ptr <= stack_ptr + 1;
          end
          char_index <= char_index + 1;
        end

        POP: begin
          if (is_close_paren && !stack_empty && stack[stack_ptr-1] == 2'd1) begin
            stack_ptr <= stack_ptr - 1;
          end else if (is_close_brace && !stack_empty && stack[stack_ptr-1] == 2'd2) begin
            stack_ptr <= stack_ptr - 1;
          end else if (is_close_bracket && !stack_empty && stack[stack_ptr-1] == 2'd3) begin
            stack_ptr <= stack_ptr - 1;
          end else if (is_closing && (stack_empty || 
                   (is_close_paren && stack[stack_ptr-1] != 2'd1) ||
                   (is_close_brace && stack[stack_ptr-1] != 2'd2) ||
                   (is_close_bracket && stack[stack_ptr-1] != 2'd3))) begin
            next_state = ERROR;
          end
          char_index <= char_index + 1;
        end

        VALIDATE: begin
          if (stack_empty) begin
            balanced <= 1;
            done <= 1;
          end else begin
            balanced <= 0;
            done <= 1;
          end
        end

        ERROR: begin
          balanced <= 0;
          done <= 1;
        end

        COMPLETE: begin
          balanced <= 1;
          done <= 1;
        end

        default: begin
          balanced <= 0;
          done <= 0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = (is_opening) ? PUSH : ((is_closing) ? POP : IDLE);
        end
      end

      PUSH: begin
        if (char_index == 7) begin
          next_state = VALIDATE;
        end else begin
          next_state = (is_opening) ? PUSH : ((is_closing) ? POP : PUSH);
        end
      end

      POP: begin
        if (char_index == 7) begin
          next_state = VALIDATE;
        end else begin
          next_state = (is_opening) ? PUSH : ((is_closing) ? POP : POP);
        end
      end

      VALIDATE: begin
        if (stack_empty) begin
          next_state = COMPLETE;
        end else begin
          next_state = ERROR;
        end
      end

      ERROR: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      COMPLETE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule