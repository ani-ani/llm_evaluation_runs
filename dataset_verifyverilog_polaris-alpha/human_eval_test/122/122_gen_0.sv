module sum_two_digit_elements(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic signed [12:0] arr [0:15],
  input  logic       [3:0]  k,
  output logic signed [10:0] sum,
  output logic              done
);

  // Internal signals
  logic [3:0]              idx;       // index counter (0-15)
  logic                    busy;      // indicates processing in progress
  logic signed [12:0]      cur_val;   // current array value
  logic signed [12:0]      abs_val;   // absolute value of current element
  logic signed [12:0]      acc;       // accumulator (internal, 13 bits for safety)

  // Combinational absolute value
  always_comb begin
    cur_val = arr[idx];
    if (cur_val[12] == 1'b1)
      abs_val = -cur_val;
    else
      abs_val = cur_val;
  end

  // Sequential control and accumulation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx  <= 4'd0;
      acc  <= 13'sd0;
      sum  <= 11'sd0;
      done <= 1'b0;
      busy <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Start new operation
        idx  <= 4'd0;
        acc  <= 13'sd0;
        sum  <= 11'sd0;
        done <= 1'b0;
        busy <= 1'b1;
      end else if (busy && !done) begin
        // Process current element if within k
        if (idx < k) begin
          if ((abs_val >= 13'sd10) && (abs_val <= 13'sd99)) begin
            acc <= acc + cur_val;
          end
          idx <= idx + 4'd1;
        end
        // After processing k elements, finalize
        if (idx == k) begin
          // Truncate/saturate to 11-bit signed if needed (here: simple truncation)
          sum  <= acc[10:0];
          done <= 1'b1;
          busy <= 1'b0;
        end
      end else begin
        // Idle state: hold result until next start
        done <= done;
        sum  <= sum;
      end
    end
  end

endmodule