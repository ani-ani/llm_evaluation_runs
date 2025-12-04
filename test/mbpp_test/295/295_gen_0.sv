module sum_divisors(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] num,
  output reg [9:0] sum,
  output reg       done
);

  reg [7:0]  i;
  reg [7:0]  num_reg;
  reg        busy;

  // Combinational modulo check using current i and num_reg
  wire is_divisor = (i != 0) && (num_reg % i == 0);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum     <= 10'd0;
      done    <= 1'b0;
      i       <= 8'd0;
      num_reg <= 8'd0;
      busy    <= 1'b0;
    end else begin
      done <= 1'b0; // default

      if (start && !busy) begin
        num_reg <= num;
        if (num <= 8'd1) begin
          // Immediate result for num <= 1
          sum  <= 10'd0;
          done <= 1'b1;
          busy <= 1'b0;
          i    <= 8'd0;
        end else begin
          // Initialize for num >= 2
          sum  <= 10'd1;    // 1 is always a proper divisor for num>=2
          i    <= 8'd2;     // start checking from 2
          busy <= 1'b1;
        end
      end else if (busy) begin
        // Sequentially check divisors from 2 to num-1
        if (i < num_reg) begin
          if (is_divisor)
            sum <= sum + i;

          if (i == num_reg - 1) begin
            // Completed checking up to num-1
            done <= 1'b1;
            busy <= 1'b0;
          end

          i <= i + 1'b1;
        end else begin
          // Safety: if i ever reaches num_reg or beyond unexpectedly
          done <= 1'b1;
          busy <= 1'b0;
        end
      end
    end
  end

endmodule