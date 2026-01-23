module fib (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    CALCULATE,
    COMPLETE
  } state_t;

  state_t state, next_state;
  reg [31:0] fib_prev, fib_curr, fib_next;
  reg [15:0] counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 32'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        if (n == 0 || n == 1) next_state = COMPLETE;
        else next_state = CALCULATE;
      end
      CALCULATE: begin
        if (counter == n - 1) next_state = COMPLETE;
      end
      COMPLETE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fib_prev <= 32'b0;
      fib_curr <= 32'b0;
      counter <= 16'b0;
    end else begin
      case (state)
        INIT: begin
          if (n == 0) result <= 32'b0;
          else if (n == 1) result <= 32'b1;
          else begin
            fib_prev <= 32'b0;
            fib_curr <= 32'b1;
            counter <= 16'b1;
          end
        end
        CALCULATE: begin
          fib_next = fib_prev + fib_curr;
          fib_prev <= fib_curr;
          fib_curr <= fib_next;
          counter <= counter + 1;
        end
        COMPLETE: begin
          result <= fib_curr;
          done <= 1'b1;
        end
        IDLE: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule