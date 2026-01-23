module replace_spaces (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input char_valid,
  output reg char_read,
  output reg [7:0] char_out,
  output reg char_valid_out,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] READ_CHAR = 3'b001;
  localparam [2:0] CHECK_SPACE = 3'b010;
  localparam [2:0] OUTPUT_CHAR = 3'b011;
  localparam [2:0] WAIT_FOR_NEXT = 3'b100;
  localparam [2:0] FINISHED = 3'b101;

  // FSM state register
  reg [2:0] state, next_state;

  // Current character storage
  reg [7:0] current_char;

  // Position counter (max 15)
  reg [3:0] position;

  // Space mode flag
  reg space_mode;

  // '%20' sequence counter
  reg [1:0] space_counter;

  // Output character register
  reg [7:0] next_char_out;

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (!rst_n) next_state = IDLE;
        else if (start) next_state = READ_CHAR;
        else next_state = IDLE;
      end

      READ_CHAR: begin
        if (!rst_n) next_state = IDLE;
        else if (char_valid) next_state = CHECK_SPACE;
        else next_state = READ_CHAR;
      end

      CHECK_SPACE: begin
        if (!rst_n) next_state = IDLE;
        else next_state = OUTPUT_CHAR;
      end

      OUTPUT_CHAR: begin
        if (!rst_n) next_state = IDLE;
        else if (space_mode && space_counter != 2'b10) next_state = OUTPUT_CHAR;
        else next_state = WAIT_FOR_NEXT;
      end

      WAIT_FOR_NEXT: begin
        if (!rst_n) next_state = IDLE;
        else if (char_valid && char_in != 8'h00 && position != 4'b1111) next_state = READ_CHAR;
        else next_state = FINISHED;
      end

      FINISHED: begin
        if (!rst_n) next_state = IDLE;
        else if (start) next_state = READ_CHAR;
        else next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // State register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Output logic
  always @(*) begin
    char_read = 1'b0;
    char_valid_out = 1'b0;
    done = 1'b0;
    char_out = 8'h00;

    case (state)
      IDLE: begin
        char_read = 1'b0;
        char_valid_out = 1'b0;
        done = 1'b0;
      end

      READ_CHAR: begin
        char_read = 1'b1;
        char_valid_out = 1'b0;
        done = 1'b0;
      end

      CHECK_SPACE: begin
        char_read = 1'b0;
        char_valid_out = 1'b0;
        done = 1'b0;
        current_char = char_in;
        position = position + 1'b1;
        space_mode = (char_in == 8'h20);
        space_counter = 2'b00;
      end

      OUTPUT_CHAR: begin
        char_read = 1'b0;
        char_valid_out = 1'b1;
        done = 1'b0;

        if (space_mode) begin
          case (space_counter)
            2'b00: next_char_out = 8'h25; // '%'
            2'b01: next_char_out = 8'h30; // '0'
            2'b10: next_char_out = 8'h30; // '0'
            default: next_char_out = 8'h00;
          endcase
          space_counter = space_counter + 1'b1;
        end
        else begin
          next_char_out = current_char;
        end
        char_out = next_char_out;
      end

      WAIT_FOR_NEXT: begin
        char_read = 1'b0;
        char_valid_out = 1'b0;
        done = 1'b0;
      end

      FINISHED: begin
        char_read = 1'b0;
        char_valid_out = 1'b0;
        done = 1'b1;
      end

      default: begin
        char_read = 1'b0;
        char_valid_out = 1'b0;
        done = 1'b0;
      end
    endcase
  end

  // Reset logic
  always @(negedge rst_n) begin
    if (!rst_n) begin
      position <= 4'b0000;
      space_mode <= 1'b0;
      space_counter <= 2'b00;
    end
  end

endmodule