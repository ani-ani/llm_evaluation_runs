module lucas_number (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    ITER,
    DONE
  } state_t;

  state_t state, next_state;
  reg [15:0] prev, curr, next;
  reg [4:0] counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'b0;
      done <= 1'b0;
      prev <= 16'b0;
      curr <= 16'b0;
      counter <= 5'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (n == 5'b0) begin
            next_state = DONE;
            result = 16'd2;
          end else if (n == 5'b1) begin
            next_state = DONE;
            result = 16'd1;
          end else begin
            next_state = INIT;
          end
        end
      end
      INIT: begin
        next_state = ITER;
        prev = 16'd2;
        curr = 16'd1;
        counter = 5'd2;
      end
      ITER: begin
        next = prev + curr;
        prev = curr;
        curr = next;
        counter = counter + 1'b1;
        if (counter > n) begin
          next_state = DONE;
          result = curr;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 1'b0;
        end
      end
    endcase
  end

  // Done signal
  always @(*) begin
    done = (state == DONE);
  end

endmodule