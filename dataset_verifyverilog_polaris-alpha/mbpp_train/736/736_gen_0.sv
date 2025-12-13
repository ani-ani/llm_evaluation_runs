module bisect_left(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0]      value,
  input  [7:0][3:0] array,
  output reg [3:0]  index,
  output reg        done
);

  // Latched inputs and persistent bounds
  reg [3:0] value_q;
  reg [7:0][3:0] array_q;

  reg [3:0] low_s0,  high_s0;
  reg [3:0] low_s1,  high_s1;
  reg [3:0] low_s2,  high_s2;

  // Mid and compare pipeline
  reg [3:0] mid_s0;
  reg [3:0] mid_s1;
  reg [3:0] mid_s2;

  reg       cmp_s0; // array_q[mid_s0] < value_q
  reg       cmp_s1;
  reg       cmp_s2;

  // Control: track active pipeline and final stage validity
  reg [2:0] cycle_cnt;
  reg       busy;

  // Combinational mid calculations
  wire [3:0] mid_calc_s0 = (low_s0 + high_s0) >> 1;
  wire [3:0] mid_calc_s1 = (low_s1 + high_s1) >> 1;
  wire [3:0] mid_calc_s2 = (low_s2 + high_s2) >> 1;

  // Synchronous pipeline
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      value_q   <= 4'd0;
      array_q   <= '{default:4'd0};

      low_s0    <= 4'd0;
      high_s0   <= 4'd7;
      low_s1    <= 4'd0;
      high_s1   <= 4'd7;
      low_s2    <= 4'd0;
      high_s2   <= 4'd7;

      mid_s0    <= 4'd0;
      mid_s1    <= 4'd0;
      mid_s2    <= 4'd0;

      cmp_s0    <= 1'b0;
      cmp_s1    <= 1'b0;
      cmp_s2    <= 1'b0;

      cycle_cnt <= 3'd0;
      busy      <= 1'b0;

      index     <= 4'd0;
      done      <= 1'b0;
    end else begin
      // Default outputs
      done <= 1'b0;

      // Start new search
      if (start && !busy) begin
        value_q   <= value;
        array_q   <= array;

        low_s0    <= 4'd0;
        high_s0   <= 4'd7;
        low_s1    <= 4'd0;
        high_s1   <= 4'd7;
        low_s2    <= 4'd0;
        high_s2   <= 4'd7;

        mid_s0    <= 4'd0;
        mid_s1    <= 4'd0;
        mid_s2    <= 4'd0;

        cmp_s0    <= 1'b0;
        cmp_s1    <= 1'b0;
        cmp_s2    <= 1'b0;

        cycle_cnt <= 3'd0;
        busy      <= 1'b1;
      end else if (busy) begin
        cycle_cnt <= cycle_cnt + 3'd1;

        // Stage 0: compute mid_s0, do compare, update its low/high for next iter
        mid_s0 <= mid_calc_s0;
        cmp_s0 <= (array_q[mid_calc_s0] < value_q);

        if (array_q[mid_calc_s0] < value_q) begin
          low_s0  <= mid_calc_s0 + 4'd1;
          high_s0 <= high_s0;
        end else begin
          low_s0  <= low_s0;
          high_s0 <= (mid_calc_s0 == 0) ? 4'd15 : (mid_calc_s0 - 4'd1);
        end

        // Stage 1: use previous low_s1/high_s1 to compute mid and compare
        mid_s1 <= mid_calc_s1;
        cmp_s1 <= (array_q[mid_calc_s1] < value_q);

        if (array_q[mid_calc_s1] < value_q) begin
          low_s1  <= mid_calc_s1 + 4'd1;
          high_s1 <= high_s1;
        end else begin
          low_s1  <= low_s1;
          high_s1 <= (mid_calc_s1 == 0) ? 4'd15 : (mid_calc_s1 - 4'd1);
        end

        // Stage 2: final stage
        mid_s2 <= mid_calc_s2;
        cmp_s2 <= (array_q[mid_calc_s2] < value_q);

        if (array_q[mid_calc_s2] < value_q) begin
          low_s2  <= mid_calc_s2 + 4'd1;
          high_s2 <= high_s2;
        end else begin
          low_s2  <= low_s2;
          high_s2 <= (mid_calc_s2 == 0) ? 4'd15 : (mid_calc_s2 - 4'd1);
        end

        // After 3 iterations plus 2 cycles of pipeline latency => done at cycle 5
        if (cycle_cnt == 3'd4) begin
          // low_s2 holds final insertion index for 8-element array
          index <= low_s2;
          done  <= 1'b1;
          busy  <= 1'b0;
        end
      end
    end
  end

endmodule