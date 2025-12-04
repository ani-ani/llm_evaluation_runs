module divisor_counter (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] n,
  output reg [7:0] count,
  output reg done
);

  reg [7:0] i;
  reg [7:0] n_reg;
  reg       busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 8'd0;
      done  <= 1'b0;
      i     <= 8'd0;
      n_reg <= 8'd0;
      busy  <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Initialize computation on start
        n_reg <= n;
        count <= 8'd0;
        done  <= 1'b0;
        i     <= 8'd1;
        busy  <= 1'b1;
      end else if (busy) begin
        if (n_reg == 8'd0) begin
          // Special case: n=0, defined result is 0
          count <= 8'd0;
          done  <= 1'b1;
          busy  <= 1'b0;
        end else if (i <= n_reg) begin
          if ((n_reg % i) == 8'd0)
            count <= count + 8'd1;

          if (i == n_reg) begin
            done <= 1'b1;
            busy <= 1'b0;
          end
          i <= i + 8'd1;
        end
      end else begin
        // Idle when not busy and no start
        done <= 1'b0;
      end
    end
  end

endmodule