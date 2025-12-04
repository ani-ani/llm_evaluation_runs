module sequential_search (
  input clk,
  input rst_n,
  input start,
  input [7:0] item,
  input [7:0][7:0] array,
  output reg found,
  output reg [3:0] index,
  output reg done
);
  typedef enum logic [1:0] {IDLE, SEARCHING, DONE} state_t;
  state_t state, next_state;
  reg [3:0] curr_idx, next_idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      curr_idx <= 4'b0;
      found <= 1'b0;
      index <= 4'b1111;
      done <= 1'b0;
    end else begin
      state <= next_state;
      curr_idx <= next_idx;
      found <= (next_state == DONE) ? (state == SEARCHING && array[curr_idx] == item) : found;
      index <= (next_state == DONE)
               ? ((state == SEARCHING && array[curr_idx] == item) ? curr_idx : 4'b1111)
               : index;
      done <= (next_state == DONE);
    end
  end

  always_comb begin
    next_state = state;
    next_idx = curr_idx;
    case (state)
      IDLE: begin
        next_idx = 4'b0;
        if (start) next_state = SEARCHING;
      end
      SEARCHING: begin
        if (array[curr_idx] == item) begin
          next_state = DONE;
        end else if (curr_idx == 4'd7) begin
          next_state = DONE;
        end else begin
          next_idx = curr_idx + 1;
        end
      end
      DONE: begin
        next_idx = curr_idx;
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end
endmodule