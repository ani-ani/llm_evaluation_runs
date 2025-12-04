module missing_number_finder (
  input clk,
  input rst_n,
  input start,
  input [3:0] array [0:7],
  output reg [3:0] missing,
  output reg done
);

  typedef enum logic [1:0] { IDLE, PROCESS, DONE } state_t;
  state_t state, next_state;
  reg [2:0] current_start, current_end;
  reg [2:0] next_start, next_end;

  always_comb begin
    next_state = state;
    next_start = current_start;
    next_end = current_end;

    case(state)
      IDLE: if (start) begin
        next_state = PROCESS;
        next_start = 3'b000;
        next_end = 3'b111;
      end
      PROCESS: begin
        logic [2:0] mid = (current_start + current_end) >> 1;
        if (array[mid] == mid) next_start = mid + 1;
        else next_end = mid;
        next_state = (next_start > next_end) ? DONE : PROCESS;
      end
      DONE: begin
        next_state = IDLE;
        next_start = 3'b000;
        next_end = 3'b111;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_start <= 3'b000;
      current_end <= 3'b111;
      missing <= 4'b0000;
      done <= 1'b0;
    end else begin
      state <= next_state;
      current_start <= next_start;
      current_end <= next_end;
      done <= (next_state == DONE);
      if (next_state == DONE) missing <= {1'b0, next_start};
    end
  end

endmodule