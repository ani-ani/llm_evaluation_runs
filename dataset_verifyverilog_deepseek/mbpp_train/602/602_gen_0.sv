module first_repeated_char (
  input clk,
  input rst_n,
  input start,
  input [7:0] str [0:7],
  output reg [7:0] result,
  output reg found,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
  state_t state, next_state;
  reg [2:0] current_index, next_index;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_index <= 3'b0;
      result <= 8'b0;
      found <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      current_index <= next_index;
      done <= 1'b0;

      case (next_state)
        IDLE: begin
          result <= 8'b0;
          found <= 1'b0;
        end
        PROCESSING: begin
          if (next_state == DONE) begin
            result <= str[current_index];
            found <= (current_index >= 1) ? 1'b1 : 1'b0;
          end
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    next_index = current_index;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          next_index = 3'b0;
        end
      end
      PROCESSING: begin
        if (current_index >= 1 && |(str[0:current_index-1] == str[current_index])) begin
          next_state = DONE;
        end else if (current_index == 3'd7) begin
          next_state = DONE;
        end else 
          next_index = current_index + 3'b1;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end
endmodule