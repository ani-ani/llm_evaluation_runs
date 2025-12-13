module fibonacci (
  input  wire        clk,
  input  wire        rst_n,
  input  wire [7:0]  n,
  input  wire        start,
  output reg  [15:0] result,
  output reg         done
);

  reg [7:0]   count;
  reg [7:0]   target_n;
  reg [15:0]  fib_prev;
  reg [15:0]  fib_curr;
  reg         busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result    <= 16'd0;
      done      <= 1'b0;
      busy      <= 1'b0;
      count     <= 8'd0;
      target_n  <= 8'd0;
      fib_prev  <= 16'd0;
      fib_curr  <= 16'd0;
    end else begin
      if (!busy) begin
        done <= 1'b0;
        if (start) begin
          // Latch target_n and initialize
          target_n <= n;
          count    <= 8'd0;
          fib_prev <= 16'd0;  // Fib(0)
          fib_curr <= 16'd1;  // Fib(1)
          busy     <= 1'b1;
          // First cycle after start is cycle 0; result at cycle target_n
        end
      end else begin
        // busy == 1: performing iterative computation
        if (count == target_n) begin
          // Done at exactly n+1 cycles after start
          result <= (target_n == 8'd0) ? 16'd0 : fib_prev;
          done   <= 1'b1;
          busy   <= 1'b0;
        end else begin
          // Iteration step: advance Fibonacci sequence
          {fib_prev, fib_curr} <= {fib_curr, fib_prev + fib_curr};
          count <= count + 8'd1;
        end
      end
    end
  end

endmodule