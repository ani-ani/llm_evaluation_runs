module digit_sum_finder(
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0] A,
  input  [15:0] B,
  input  [5:0]  S,
  output reg [13:0] count,
  output reg [15:0] smallest_num,
  output reg done
);

  // Internal registers
  reg [15:0] current_num;
  reg        running;

  // Digit extraction wires
  reg [3:0] thousands;
  reg [3:0] hundreds;
  reg [3:0] tens;
  reg [3:0] units;
  reg [6:0] digit_sum; // max 9+9+9+9 = 36

  // Combinational digit extraction and sum
  always @* begin
    thousands = current_num / 1000;
    hundreds  = (current_num % 1000) / 100;
    tens      = (current_num % 100) / 10;
    units     = current_num % 10;
    digit_sum = thousands + hundreds + tens + units;
  end

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_num  <= 16'd0;
      count        <= 14'd0;
      smallest_num <= 16'd0;
      done         <= 1'b0;
      running      <= 1'b0;
    end else begin
      if (start && !running && !done) begin
        // Initialize on start
        current_num  <= A;
        count        <= 14'd0;
        smallest_num <= 16'hFFFF; // invalid / max
        done         <= 1'b0;
        running      <= 1'b1;
      end else if (running) begin
        if (A > B) begin
          // Special case: empty range
          done    <= 1'b1;
          running <= 1'b0;
        end else begin
          if (current_num <= B) begin
            if (digit_sum == S) begin
              count <= count + 14'd1;
              if (current_num < smallest_num) begin
                smallest_num <= current_num;
              end
            end
            // Increment current number for next cycle
            current_num <= current_num + 16'd1;
            // If this increment passes B, we will finish next cycle
            if (current_num == B) begin
              // After processing B, next state should be done
              // Mark completion in advance
              done    <= 1'b1;
              running <= 1'b0;
            end
          end else begin
            // Safety: if out of range, finish
            done    <= 1'b1;
            running <= 1'b0;
          end
        end
      end
    end
  end

endmodule