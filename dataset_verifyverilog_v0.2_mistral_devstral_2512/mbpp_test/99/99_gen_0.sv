module decimal_to_binary (
  input clk,
  input rst_n,
  input start,
  input [15:0] decimal_in,
  output reg [79:0] binary_str,
  output reg [3:0] length,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] temp_decimal;
  reg [15:0] shift_reg;
  reg [3:0] bit_count;
  reg [3:0] char_index;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      temp_decimal <= 0;
      shift_reg <= 0;
      bit_count <= 0;
      char_index <= 0;
      binary_str <= 0;
      length <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            temp_decimal <= decimal_in;
            shift_reg <= 0;
            bit_count <= 0;
            char_index <= 0;
            binary_str <= 0;
            length <= 0;
            done <= 0;
          end
        end

        CALCULATE: begin
          if (bit_count < 16) begin
            shift_reg <= {shift_reg[14:0], temp_decimal[0]};
            temp_decimal <= temp_decimal >> 1;
            bit_count <= bit_count + 1;
          end
        end

        DONE: begin
          if (char_index < 10) begin
            if (char_index < bit_count) begin
              binary_str[(char_index+1)*8-1:char_index*8] <= shift_reg[bit_count - char_index - 1] ? 8'h31 : 8'h30;
            end else begin
              binary_str[(char_index+1)*8-1:char_index*8] <= 8'h30;
            end
            char_index <= char_index + 1;
          end
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CALCULATE;
      end

      CALCULATE: begin
        if (bit_count == 16) next_state = DONE;
      end

      DONE: begin
        if (char_index == 10) begin
          next_state = IDLE;
          done = 1;
          length = bit_count;
        end
      end
    endcase
  end

endmodule