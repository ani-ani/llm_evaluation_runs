module fib4_calculator(
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] n,
  output reg [31:0] result,
  output reg   done
);

  // FSM States
  localparam IDLE = 1'b0;
  localparam CALC = 1'b1;

  reg        state;
  reg [31:0] a, b, c, d;
  reg [31:0] next_val;
  reg [15:0] steps_left;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      done       <= 1'b1;
      result     <= 32'd0;
      a          <= 32'd0;
      b          <= 32'd0;
      c          <= 32'd0;
      d          <= 32'd0;
      next_val   <= 32'd0;
      steps_left <= 16'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b1;
          if (start) begin
            // Latch n and start operation
            if (n <= 16'd3) begin
              // Handle base cases; result valid next cycle
              case (n)
                16'd0: result <= 32'd0;
                16'd1: result <= 32'd0;
                16'd2: result <= 32'd2;
                16'd3: result <= 32'd0;
                default: result <= 32'd0; // should not occur
              endcase
              // Remain in IDLE, done stays 1 (immediate completion)
            end else begin
              // n > 3: initialize for iterative computation
              a          <= 32'd0;
              b          <= 32'd0;
              c          <= 32'd2;
              d          <= 32'd0;
              steps_left <= n - 16'd3;
              done       <= 1'b0;
              state      <= CALC;
            end
          end
        end

        CALC: begin
          // Perform one iteration per cycle
          next_val <= a + b + c + d;

          // Shift window
          a <= b;
          b <= c;
          c <= d;
          d <= a + b + c + d;

          if (steps_left == 16'd1) begin
            // This is the final step; next_val is the result
            result     <= a + b + c + d;
            done       <= 1'b1;
            state      <= IDLE;
            steps_left <= 16'd0;
          end else begin
            steps_left <= steps_left - 16'd1;
            done       <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
          done  <= 1'b1;
        end
      endcase
    end
  end

endmodule