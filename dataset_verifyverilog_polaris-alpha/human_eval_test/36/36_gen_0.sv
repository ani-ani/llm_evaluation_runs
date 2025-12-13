module seven_counter(
  input  clk,
  input  rst_n,
  input  start,
  input  [9:0] n,
  output reg [7:0] count,
  output reg done
);

  // Internal registers
  reg [9:0] i;                // current number index
  reg [9:0] cur;              // number being examined
  reg [7:0] count_next;       // next value of count
  reg       running;          // indicates computation in progress

  // Digit extraction variables
  reg [9:0] temp;             // temporary for decimal extraction
  reg [3:0] d0, d1, d2, d3;   // decimal digits for up to 1023
  reg [1:0] seven_cnt;        // number of '7' digits in current number (0..3)

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i       <= 10'd0;
      count   <= 8'd0;
      done    <= 1'b0;
      running <= 1'b0;
    end else begin
      if (start && !running) begin
        // Start new computation
        i       <= 10'd0;
        count   <= 8'd0;
        done    <= 1'b0;
        running <= 1'b1;
      end else if (running) begin
        // If there is still work (0..n-1), process current i
        if (i < n) begin
          count <= count_next;
          i     <= i + 10'd1;
          // done remains low while processing
          done  <= 1'b0;
        end else begin
          // Completed processing 0..n-1; assert done for at least one cycle
          running <= 1'b0;
          done    <= 1'b1;
          // Hold count and i stable
          count   <= count;
          i       <= i;
        end
      end else begin
        // Idle state; keep done and count stable unless new start
        done <= done;
      end
    end
  end

  // Combinational logic to compute next count based on current i
  always @* begin
    // Default: no change
    count_next = count;

    // Only compute when actively running and i < n
    if (running && (i < n)) begin
      cur = i;

      // Check divisibility by 11 or 13
      if (((cur % 11) == 0) || ((cur % 13) == 0)) begin
        // Extract decimal digits for 0..1023
        temp = cur;

        // Thousands digit (0..1) ignored for '7' count since max is 1
        if (temp >= 10'd1000)
          temp = temp - 10'd1000;

        // Hundreds digit
        d3 = (temp >= 10'd900) ? 4'd9 :
             (temp >= 10'd800) ? 4'd8 :
             (temp >= 10'd700) ? 4'd7 :
             (temp >= 10'd600) ? 4'd6 :
             (temp >= 10'd500) ? 4'd5 :
             (temp >= 10'd400) ? 4'd4 :
             (temp >= 10'd300) ? 4'd3 :
             (temp >= 10'd200) ? 4'd2 :
             (temp >= 10'd100) ? 4'd1 : 4'd0;

        if (d3 != 4'd0)
          temp = temp - (d3 * 10'd100);

        // Tens digit
        d2 = (temp >= 10'd90) ? 4'd9 :
             (temp >= 10'd80) ? 4'd8 :
             (temp >= 10'd70) ? 4'd7 :
             (temp >= 10'd60) ? 4'd6 :
             (temp >= 10'd50) ? 4'd5 :
             (temp >= 10'd40) ? 4'd4 :
             (temp >= 10'd30) ? 4'd3 :
             (temp >= 10'd20) ? 4'd2 :
             (temp >= 10'd10) ? 4'd1 : 4'd0;

        if (d2 != 4'd0)
          temp = temp - (d2 * 10'd10);

        // Ones digit
        d1 = temp[3:0];

        // For completeness, d0 is unused (no more digits for <=1023)
        d0 = 4'd0;

        // Count number of '7' digits
        seven_cnt = 2'd0;
        if (d3 == 4'd7) seven_cnt = seven_cnt + 2'd1;
        if (d2 == 4'd7) seven_cnt = seven_cnt + 2'd1;
        if (d1 == 4'd7) seven_cnt = seven_cnt + 2'd1;

        // Accumulate
        count_next = count + seven_cnt;
      end
    end
  end

endmodule