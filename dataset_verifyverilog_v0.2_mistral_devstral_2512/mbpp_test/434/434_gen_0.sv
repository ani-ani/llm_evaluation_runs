module regex_matcher (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [2:0] char_index,
  output reg match_result,
  output reg done
);

  // State definitions
  localparam [1:0] STATE_IDLE = 2'b00;
  localparam [1:0] STATE_SEARCH = 2'b01;
  localparam [1:0] STATE_FOUND_A = 2'b10;
  localparam [1:0] STATE_COMPLETE = 2'b11;

  // State register
  reg [1:0] current_state, next_state;

  // ASCII values
  localparam [7:0] ASCII_a = 8'h61;
  localparam [7:0] ASCII_b = 8'h62;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= STATE_IDLE;
      match_result <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state and output logic
  always @(*) begin
    case (current_state)
      STATE_IDLE: begin
        if (start) begin
          next_state = STATE_SEARCH;
          match_result = 1'b0;
          done = 1'b0;
        end else begin
          next_state = STATE_IDLE;
          match_result = 1'b0;
          done = 1'b0;
        end
      end

      STATE_SEARCH: begin
        if (char_index == 3'b111) begin
          next_state = STATE_COMPLETE;
          done = 1'b1;
        end else begin
          if (char_in == ASCII_a) begin
            next_state = STATE_FOUND_A;
          end else begin
            next_state = STATE_SEARCH;
          end
          done = 1'b0;
        end
      end

      STATE_FOUND_A: begin
        if (char_index == 3'b111) begin
          next_state = STATE_COMPLETE;
          done = 1'b1;
        end else begin
          if (char_in == ASCII_b) begin
            match_result = 1'b1;
            next_state = STATE_FOUND_A;
          end else begin
            next_state = STATE_SEARCH;
          end
          done = 1'b0;
        end
      end

      STATE_COMPLETE: begin
        next_state = STATE_IDLE;
        done = 1'b1;
      end

      default: begin
        next_state = STATE_IDLE;
        match_result = 1'b0;
        done = 1'b0;
      end
    endcase
  end

endmodule