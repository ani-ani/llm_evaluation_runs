module parse_nested_parens (
  input clk,
  input rst_n,
  input start,
  input [6:0] char_in,
  input valid,
  input done_in,
  output reg [3:0] result,
  output reg done,
  output reg [2:0] group_count
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PARSE,
    WAIT_SPACE,
    COMPLETE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] current_depth;
  reg [3:0] group_depth;
  reg [2:0] group_count_reg;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_depth <= 0;
      group_depth <= 0;
      result <= 0;
      done <= 0;
      group_count <= 0;
      group_count_reg <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            current_depth <= 0;
            group_depth <= 0;
            result <= 0;
            done <= 0;
            group_count <= 0;
            group_count_reg <= 0;
          end
        end

        PARSE: begin
          if (valid) begin
            if (char_in == 40) begin // '('
              current_depth <= current_depth + 1;
              if (current_depth > group_depth) begin
                group_depth <= current_depth;
              end
            end else if (char_in == 41) begin // ')'
              current_depth <= current_depth - 1;
            end else if (char_in == 32) begin // space
              if (group_depth > result) begin
                result <= group_depth;
              end
              group_count_reg <= group_count_reg + 1;
              group_depth <= 0;
              current_depth <= 0;
            end
          end
        end

        WAIT_SPACE: begin
          if (valid && char_in != 32) begin
            current_depth <= 0;
            group_depth <= 0;
          end
        end

        COMPLETE: begin
          if (group_depth > result) begin
            result <= group_depth;
          end
          group_count_reg <= group_count_reg + 1;
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

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PARSE;
        end
      end

      PARSE: begin
        if (done_in) begin
          next_state = COMPLETE;
        end else if (valid && char_in == 32) begin
          next_state = WAIT_SPACE;
        end
      end

      WAIT_SPACE: begin
        if (valid && char_in != 32) begin
          next_state = PARSE;
        end
      end

      COMPLETE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output assignments
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      group_count <= 0;
    end else begin
      group_count <= group_count_reg;
    end
  end

endmodule