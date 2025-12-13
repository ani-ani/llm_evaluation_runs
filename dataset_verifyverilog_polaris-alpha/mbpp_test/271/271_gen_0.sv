module even_power_sum(
  input  logic        clk,
  input  logic        rst_n,
  input  logic [4:0]  n,
  input  logic        start,
  output logic [29:0] sum,
  output logic        done
);

  // Internal registers
  logic [4:0]  i;            // iteration counter (1..n)
  logic [29:0] running_sum;  // accumulator
  logic        busy;         // indicates active computation
  logic        start_d;      // delayed start for edge detection

  // Start pulse detection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  wire start_pulse = start & ~start_d; // rising edge detect

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i           <= 5'd0;
      running_sum <= 30'd0;
      sum         <= 30'd0;
      done        <= 1'b0;
      busy        <= 1'b0;
    end else begin
      if (start_pulse) begin
        // Initialize for new computation
        i           <= 5'd1;
        running_sum <= 30'd0;
        done        <= 1'b0;
        busy        <= 1'b1;
      end else if (busy) begin
        // Compute (2*i)^5 = 32 * i^5 and accumulate
        // i^2
        logic [9:0]  i2;
        // i^3
        logic [14:0] i3;
        // i^4
        logic [19:0] i4;
        // i^5
        logic [24:0] i5;
        // 32 * i^5 fits in 30 bits for i<=31
        logic [29:0] term;

        i2   = i * i;          // up to 961
        i3   = i2 * i;         // up to 29791
        i4   = i3 * i;         // up to 923521
        i5   = i4 * i;         // up to 28629151
        term = {i5,5'b0};      // *32 shift left by 5

        running_sum <= running_sum + term;

        if (i == n) begin
          // Finished after exactly n iterations
          sum  <= running_sum + term;
          done <= 1'b1;
          busy <= 1'b0;
          i    <= i;           // hold
        end else begin
          i    <= i + 5'd1;
          done <= 1'b0;
        end
      end else begin
        // Idle: hold outputs until next start
        done <= done;
        sum  <= sum;
      end
    end
  end

endmodule