module geometric_sum(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTING,
    DONE
  } state_t;

  // Internal signals
  state_t state;
  reg [3:0] iter;
  reg [31:0] sum;
  reg [31:0] term;

  // Initial term value (1.0 in Q16.16 format)
  parameter INIT_TERM = 32'h0001_0000;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      state <= IDLE;
      iter <= 0;
      sum <= 0;
      term <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTING;
            iter <= 0;
            sum <= 0;
            term <= INIT_TERM;
            done <= 0;
          end
        end
        
        COMPUTING: begin
          if (iter == n) begin
            state <= DONE;
            result <= sum;
            done <= 1;
          end else begin
            sum <= sum + term;
            term <= term >>> 1; // Arithmetic right shift
            iter <= iter + 1;
          end
        end
        
        DONE: begin
          if (start) begin
            state <= COMPUTING;
            iter <= 0;
            sum <= 0;
            term <= INIT_TERM;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule