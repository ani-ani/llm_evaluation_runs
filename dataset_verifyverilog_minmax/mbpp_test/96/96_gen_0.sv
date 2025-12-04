module divisor_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] count,
  output reg done
);

  // Iteration counter and state
  reg [7:0] i;
  reg compute_en;

  // Combinational division remainder for current i
  reg [7:0] r;
  always @(*) begin
    if (i == 8'h0) begin
      r = 8'h0; // Avoid division by zero; won't be used when i==0
    end else begin
      r = n / i; // Integer division; n % i == 0 iff r*i == n
    end
  end

  // FSM + datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 8'h0;
      count <= 8'h0;
      done <= 1'b0;
      compute_en <= 1'b0;
    end else begin
      if (start) begin
        // Initialize computation
        i <= 8'h1;
        count <= 8'h0;
        done <= (n == 8'h0) ? 1'b1 : 1'b0; // Edge case: n == 0
        compute_en <= (n != 8'h0);
      end else if (compute_en) begin
        if (i < n) begin
          // Check if i divides n: (n / i) * i == n
          if (r * i == n) begin
            count <= count + 1'b1;
          end
          i <= i + 1'b1;
          done <= 1'b0;
        end else begin
          // i == n: perform final check
          if (r * i == n) begin
            count <= count + 1'b1;
          end
          i <= i;
          done <= 1'b1;
          compute_en <= 1'b0;
        end
      end else begin
        // Hold final results when not computing
        done <= done;
        count <= count;
      end
    end
  end

endmodule
