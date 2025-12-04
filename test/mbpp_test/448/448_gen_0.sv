module perrin_sum(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [31:0] sum,
  output reg done
);

  reg [31:0] a, b, c, d;
  reg [7:0]  count;
  reg [7:0]  target_n;
  reg        busy;

  // Sequential control and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      sum      <= 32'd0;
      done     <= 1'b0;
      a        <= 32'd0;
      b        <= 32'd0;
      c        <= 32'd0;
      d        <= 32'd0;
      count    <= 8'd0;
      target_n <= 8'd0;
      busy     <= 1'b0;
    end else begin
      // Default values each cycle
      done <= 1'b0;

      if (start && !busy) begin
        // Latch n and start a new computation
        target_n <= n;
        busy     <= 1'b1;
        sum      <= 32'd0;
        a        <= 32'd3; // P(0)
        b        <= 32'd0; // P(1)
        c        <= 32'd2; // P(2)
        count    <= 8'd0;
      end else if (busy) begin
        if (target_n == 8'd0) begin
          // n == 0: sum = P(0) = 3
          sum  <= 32'd3;
          done <= 1'b1;
          busy <= 1'b0;
        end else if (target_n == 8'd1) begin
          // n == 1: sum = P(0)+P(1) = 3
          sum  <= 32'd3;
          done <= 1'b1;
          busy <= 1'b0;
        end else if (target_n == 8'd2) begin
          // n == 2: sum = P(0)+P(1)+P(2) = 5
          sum  <= 32'd5;
          done <= 1'b1;
          busy <= 1'b0;
        end else begin
          // n > 2: iterative Perrin computation
          if (count == 8'd0) begin
            // Initialize sum with P(0)+P(1)+P(2) = 5 on first cycle
            sum   <= 32'd5;
            count <= 8'd1;
          end else begin
            // Compute next Perrin number: d = a + b
            d <= a + b;

            // Use temporary wires via non-blocking semantics
            // Previous a,b,c used to update
            sum <= sum + (a + b);
            a   <= b;
            b   <= c;
            c   <= a + b;

            if (count == (target_n - 8'd2)) begin
              // Completed computation
              done <= 1'b1;
              busy <= 1'b0;
            end else begin
              count <= count + 8'd1;
            end
          end
        end
      end
    end
  end

endmodule