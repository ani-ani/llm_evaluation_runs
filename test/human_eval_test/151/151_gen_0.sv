module sum_odd_squares(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0][15:0] numbers,
  output reg [19:0] sum,
  output reg        done
);

  reg [2:0] idx;
  reg       busy;

  // Synchronous control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum  <= 20'd0;
      done <= 1'b0;
      idx  <= 3'd0;
      busy <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Start a new computation
        sum  <= 20'd0;
        done <= 1'b0;
        idx  <= 3'd0;
        busy <= 1'b1;
      end else if (busy) begin
        // Process current index
        // Conditions:
        // - positive:          numbers[idx][15] == 0
        // - integer (Q8.0):    numbers[idx][7:0] are used; fractional bits assumed 0 per spec
        // - odd:               numbers[idx][0] == 1
        if ((numbers[idx][15] == 1'b0) && (numbers[idx][0] == 1'b1)) begin
          sum <= sum + (numbers[idx][7:0] * numbers[idx][7:0]);
        end

        // Advance index and check completion
        if (idx == 3'd7) begin
          busy <= 1'b0;
          done <= 1'b1;
        end else begin
          idx <= idx + 3'd1;
        end
      end
      // If not busy and no new start, hold sum and done
    end
  end

endmodule