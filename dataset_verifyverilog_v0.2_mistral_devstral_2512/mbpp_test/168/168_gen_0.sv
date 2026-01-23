module frequency_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] target,
  input [7:0] list [0:7],
  output reg [3:0] count,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] index;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      done <= 0;
      index <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == IDLE && start) begin
        count <= 0;
        index <= 0;
      end else if (current_state == PROCESSING) begin
        if (list[index] == target) begin
          count <= count + 1;
        end
        index <= index + 1;
      end
    end
  end

  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
        else
          next_state = IDLE;
      end
      PROCESSING: begin
        if (index == 7)
          next_state = DONE;
        else
          next_state = PROCESSING;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  always @(*) begin
    done = (current_state == DONE);
  end

endmodule