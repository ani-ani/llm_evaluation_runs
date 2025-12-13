module event_duration_solver(
  input clk,
  input rst_n,
  input start,
  // Telescope 0 inputs
  input [4:0] t0_start_day,
  input [3:0] t0_start_month,
  input [4:0] t0_end_day,
  input [3:0] t0_end_month,
  input [7:0] t0_freq0, t0_freq1, t0_freq2,
  // Telescope 1 inputs
  input [4:0] t1_start_day,
  input [3:0] t1_start_month,
  input [4:0] t1_end_day,
  input [3:0] t1_end_month,
  input [7:0] t1_freq0, t1_freq1, t1_freq2,
  // Telescope 2 inputs
  input [4:0] t2_start_day,
  input [3:0] t2_start_month,
  input [4:0] t2_end_day,
  input [3:0] t2_end_month,
  input [7:0] t2_freq0, t2_freq1, t2_freq2,
  // Outputs
  output reg [8:0] d0,
  output reg [8:0] d1,
  output reg [8:0] d2,
  output reg solution_found,
  output reg done
);

  // Internal counters for iteration
  reg [8:0] d0_cnt;
  reg [8:0] d1_cnt;
  reg [8:0] d2_cnt;

  // Internal control
  reg running;

  // Day-of-year calculations using hardcoded month offsets (non-leap year)
  function automatic [8:0] month_offset(input [3:0] m);
    begin
      case (m)
        4'd1:  month_offset = 9'd0;   // Jan
        4'd2:  month_offset = 9'd31;  // Feb
        4'd3:  month_offset = 9'd59;  // Mar
        4'd4:  month_offset = 9'd90;  // Apr
        4'd5:  month_offset = 9'd120; // May
        4'd6:  month_offset = 9'd151; // Jun
        4'd7:  month_offset = 9'd181; // Jul
        4'd8:  month_offset = 9'd212; // Aug
        4'd9:  month_offset = 9'd243; // Sep
        4'd10: month_offset = 9'd273; // Oct
        4'd11: month_offset = 9'd304; // Nov
        4'd12: month_offset = 9'd334; // Dec
        default: month_offset = 9'd0;
      endcase
    end
  endfunction

  wire [8:0] t0_start_doy = month_offset(t0_start_month) + t0_start_day;
  wire [8:0] t0_end_doy   = month_offset(t0_end_month)   + t0_end_day;
  wire [8:0] t1_start_doy = month_offset(t1_start_month) + t1_start_day;
  wire [8:0] t1_end_doy   = month_offset(t1_end_month)   + t1_end_day;
  wire [8:0] t2_start_doy = month_offset(t2_start_month) + t2_start_day;
  wire [8:0] t2_end_doy   = month_offset(t2_end_month)   + t2_end_day;

  // days_diff = (end - start + 365) % 365
  wire [9:0] t0_diff_tmp = t0_end_doy + 10'd365 - t0_start_doy;
  wire [9:0] t1_diff_tmp = t1_end_doy + 10'd365 - t1_start_doy;
  wire [9:0] t2_diff_tmp = t2_end_doy + 10'd365 - t2_start_doy;

  wire [8:0] t0_days_diff = (t0_diff_tmp >= 10'd365) ? (t0_diff_tmp - 10'd365) : t0_diff_tmp[8:0];
  wire [8:0] t1_days_diff = (t1_diff_tmp >= 10'd365) ? (t1_diff_tmp - 10'd365) : t1_diff_tmp[8:0];
  wire [8:0] t2_days_diff = (t2_diff_tmp >= 10'd365) ? (t2_diff_tmp - 10'd365) : t2_diff_tmp[8:0];

  // Compute sums for each telescope: freq0*d0 + freq1*d1 + freq2*d2
  // Max: (200*365)*3 = 219000 -> needs 18 bits; use 19 bits for safety
  wire [16:0] p0_0 = t0_freq0 * d0_cnt;
  wire [16:0] p0_1 = t0_freq1 * d1_cnt;
  wire [16:0] p0_2 = t0_freq2 * d2_cnt;
  wire [18:0] sum0 = p0_0 + p0_1 + p0_2;

  wire [16:0] p1_0 = t1_freq0 * d0_cnt;
  wire [16:0] p1_1 = t1_freq1 * d1_cnt;
  wire [16:0] p1_2 = t1_freq2 * d2_cnt;
  wire [18:0] sum1 = p1_0 + p1_1 + p1_2;

  wire [16:0] p2_0 = t2_freq0 * d0_cnt;
  wire [16:0] p2_1 = t2_freq1 * d1_cnt;
  wire [16:0] p2_2 = t2_freq2 * d2_cnt;
  wire [18:0] sum2 = p2_0 + p2_1 + p2_2;

  // Check (sum - days_diff) >=0 and divisible by 365
  function automatic is_valid_sum(
    input [18:0] sum,
    input [8:0] days_diff
  );
    reg [18:0] diff;
    reg [8:0] rem;
    integer i;
    begin
      if (sum < days_diff) begin
        is_valid_sum = 1'b0;
      end else begin
        diff = sum - days_diff;
        // Compute diff % 365 via subtractive method (synthesizable)
        rem = diff[8:0];
        // Use repeated subtraction but bounded: diff max about 219000
        // 219000 / 365 < 600, so 600 iterations upper bound
        for (i = 0; i < 600; i = i + 1) begin
          if (rem >= 9'd365)
            rem = rem - 9'd365;
        end
        is_valid_sum = (rem == 9'd0);
      end
    end
  endfunction

  wire valid0 = is_valid_sum(sum0, t0_days_diff);
  wire valid1 = is_valid_sum(sum1, t1_days_diff);
  wire valid2 = is_valid_sum(sum2, t2_days_diff);

  wire all_valid = valid0 & valid1 & valid2;

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      d0_cnt <= 9'd0;
      d1_cnt <= 9'd0;
      d2_cnt <= 9'd0;
      d0 <= 9'd0;
      d1 <= 9'd0;
      d2 <= 9'd0;
      solution_found <= 1'b0;
      done <= 1'b0;
      running <= 1'b0;
    end else begin
      if (!running) begin
        // Idle state
        if (start && !done) begin
          // Initialize counters when start asserted
          d0_cnt <= 9'd1;
          d1_cnt <= 9'd1;
          d2_cnt <= 9'd1;
          solution_found <= 1'b0;
          done <= 1'b0;
          running <= 1'b1;
        end
      end else begin
        // Running search
        if (all_valid) begin
          // Found a valid solution
          d0 <= d0_cnt;
          d1 <= d1_cnt;
          d2 <= d2_cnt;
          solution_found <= 1'b1;
          done <= 1'b1;
          running <= 1'b0;
        end else begin
          // Advance counters (nested loops)
          if (d2_cnt < 9'd365) begin
            d2_cnt <= d2_cnt + 9'd1;
          end else begin
            d2_cnt <= 9'd1;
            if (d1_cnt < 9'd365) begin
              d1_cnt <= d1_cnt + 9'd1;
            end else begin
              d1_cnt <= 9'd1;
              if (d0_cnt < 9'd365) begin
                d0_cnt <= d0_cnt + 9'd1;
              end else begin
                // Exhausted all combinations
                done <= 1'b1;
                solution_found <= 1'b0;
                running <= 1'b0;
              end
            end
          end
        end
      end
    end
  end

endmodule