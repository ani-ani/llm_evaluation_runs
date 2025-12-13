module highest_power_2 (
  input        clk,
  input        rst_n,
  input        start,
  input  [5:0] n_in,
  output reg [5:0] result,
  output reg       done
);

  reg [5:0] counter;
  reg       active;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result  <= 6'd0;
      done    <= 1'b0;
      counter <= 6'd0;
      active  <= 1'b0;
    end else begin
      if (start) begin
        // Start a new calculation
        counter <= n_in;
        active  <= 1'b1;
        done    <= 1'b0;
        result  <= 6'd0;
      end else if (active && !done) begin
        if ((counter & (counter - 6'd1)) == 6'd0) begin
          // Found highest power of 2 <= n_in
          result <= counter;
          done   <= 1'b1;
          active <= 1'b0;
        end else if (counter > 6'd1) begin
          // Continue decrementing
          counter <= counter - 6'd1;
        end else begin
          // Reached 1 (which is 2^0), must be the result
          result <= 6'd1;
          done   <= 1'b1;
          active <= 1'b0;
        end
      end
      // If done is high and no new start, hold result and done
    end
  end

endmodule