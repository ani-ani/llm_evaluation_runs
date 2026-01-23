module fibfib (
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
    COMPUTE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [15:0] prev3, prev2, prev1; // fibfib(i-3), fibfib(i-2), fibfib(i-1)
  reg [4:0] counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 16'b0;
      counter <= 5'b0;
      prev3 <= 16'b0;
      prev2 <= 16'b0;
      prev1 <= 16'b0;
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
        if (n <= 2) next_state = DONE;
        else next_state = COMPUTE;
      end
      COMPUTE: begin
        if (counter == n) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state register
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
        end
        INIT: begin
          case (n)
            5'b00000: begin // n=0
              result <= 16'b0;
              prev3 <= 16'b0;
              prev2 <= 16'b0;
              prev1 <= 16'b0;
            end
            5'b00001: begin // n=1
              result <= 16'b0;
              prev3 <= 16'b0;
              prev2 <= 16'b0;
              prev1 <= 16'b0;
            end
            5'b00010: begin // n=2
              result <= 16'b1;
              prev3 <= 16'b0;
              prev2 <= 16'b0;
              prev1 <= 16'b1;
            end
            default: begin // n>=3
              prev3 <= 16'b0;
              prev2 <= 16'b0;
              prev1 <= 16'b1;
              counter <= 5'b00011; // Start from i=3
            end
          endcase
        end
        COMPUTE: begin
          if (counter != n) begin
            reg [15:0] next_val = prev1 + prev2 + prev3;
            prev3 <= prev2;
            prev2 <= prev1;
            prev1 <= next_val;
            counter <= counter + 1;
          end
        end
        DONE: begin
          done <= 1'b1;
          if (n > 2) result <= prev1;
        end
      endcase
    end
  end

endmodule