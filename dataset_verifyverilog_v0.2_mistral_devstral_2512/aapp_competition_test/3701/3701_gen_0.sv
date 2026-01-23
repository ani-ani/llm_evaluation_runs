module binary_string_cost (
  input clk,
  input rst_n,
  input start,
  input [7:0] str_len,
  input [7:0] char_in,
  input valid_in,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam x = 10;
  localparam y = 1;

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READING,
    COMPUTING,
    DONE
  } state_t;

  // State registers
  state_t current_state, next_state;

  // Internal registers
  reg [3:0] char_count = 0;
  reg [3:0] groups = 0;
  reg prev_char = 1'b1; // Start with '1' to detect first '0' segment
  reg [31:0] counter = 0;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_count <= 0;
      groups <= 0;
      prev_char <= 1'b1;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      // State actions
      case (current_state)
        IDLE: begin
          if (start) begin
            char_count <= 0;
            groups <= 0;
            prev_char <= 1'b1;
            counter <= 0;
          end
        end

        READING: begin
          if (valid_in) begin
            // Detect '1' to '0' transition
            if (prev_char && !char_in[0]) begin
              groups <= groups + 1;
            end
            prev_char <= char_in[0];
            char_count <= char_count + 1;
          end
        end

        COMPUTING: begin
          counter <= counter + 1;
        end

        DONE: begin
          // Keep result and done until reset
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = READING;
      end

      READING: begin
        if (char_count == str_len - 1 && valid_in) begin
          next_state = COMPUTING;
        end
      end

      COMPUTING: begin
        if (counter == 9) begin // 10 cycles total (0-9)
          next_state = DONE;
        end
      end

      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Result calculation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == COMPUTING && counter == 9) begin
      if (groups == 0) begin
        result <= 0;
      end else if (x <= y) begin
        result <= (groups - 1) * x + y;
      end else begin
        result <= groups * y;
      end
      done <= 1;
    end else if (current_state == IDLE) begin
      done <= 0;
    end
  end

endmodule