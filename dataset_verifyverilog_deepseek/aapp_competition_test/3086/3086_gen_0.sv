module event_duration_solver(
  input clk,
  input rst_n,
  input start,
  input [4:0] t0_start_day,
  input [3:0] t0_start_month,
  input [4:0] t0_end_day,
  input [3:0] t0_end_month,
  input [7:0] t0_freq0, t0_freq1, t0_freq2,
  input [4:0] t1_start_day,
  input [3:0] t1_start_month,
  input [4:0] t1_end_day,
  input [3:0] t1_end_month,
  input [7:0] t1_freq0, t1_freq1, t1_freq2,
  input [4:0] t2_start_day,
  input [3:0] t2_start_month,
  input [4:0] t2_end_day,
  input [3:0] t2_end_month,
  input [7:0] t2_freq0, t2_freq1, t2_freq2,
  output reg [8:0] d0, d1, d2,
  output reg solution_found,
  output reg done
);

  reg [8:0] d0_cnt, d1_cnt, d2_cnt;
  reg running;

  function logic [8:0] calc_day_of_year(input [3:0] month, input [4:0] day);
    case (month)
      4'd1: return day;
      4'd2: return 31 + day;
      4'd3: return 59 + day;
      4'd4: return 90 + day;
      4'd5: return 120 + day;
      4'd6: return 151 + day;
      4'd7: return 181 + day;
      4'd8: return 212 + day;
      4'd9: return 243 + day;
      4'd10: return 273 + day;
      4'd11: return 304 + day;
      4'd12: return 334 + day;
      default: return day;
    endcase
  endfunction

  logic [8:0] t0_start_doy, t0_end_doy, t1_start_doy, t1_end_doy, t2_start_doy, t2_end_doy;
  assign t0_start_doy = calc_day_of_year(t0_start_month, t0_start_day);
  assign t0_end_doy = calc_day_of_year(t0_end_month, t0_end_day);
  assign t1_start_doy = calc_day_of_year(t1_start_month, t1_start_day);
  assign t1_end_doy = calc_day_of_year(t1_end_month, t1_end_day);
  assign t2_start_doy = calc_day_of_year(t2_start_month, t2_start_day);
  assign t2_end_doy = calc_day_of_year(t2_end_month, t2_end_day);

  logic [8:0] t0_days_diff, t1_days_diff, t2_days_diff;
  assign t0_days_diff = (t0_end_doy - t0_start_doy + 365) % 365;
  assign t1_days_diff = (t1_end_doy - t1_start_doy + 365) % 365;
  assign t2_days_diff = (t2_end_doy - t2_start_doy + 365) % 365;

  logic [16:0] t0_sum, t1_sum, t2_sum;
  assign t0_sum = t0_freq0 * d0_cnt + t0_freq1 * d1_cnt + t0_freq2 * d2_cnt;
  assign t1_sum = t1_freq0 * d0_cnt + t1_freq1 * d1_cnt + t1_freq2 * d2_cnt;
  assign t2_sum = t2_freq0 * d0_cnt + t2_freq1 * d1_cnt + t2_freq2 * d2_cnt;

  logic valid;
  logic [16:0] t0_diff, t1_diff, t2_diff;
  assign t0_diff = t0_sum - t0_days_diff;
  assign t1_diff = t1_sum - t1_days_diff;
  assign t2_diff = t2_sum - t2_days_diff;

  logic t0_valid, t1_valid, t2_valid;
  assign t0_valid = (t0_diff >= 0) && ((t0_diff % 365) == 0);
  assign t1_valid = (t1_diff >= 0) && ((t1_diff % 365) == 0);
  assign t2_valid = (t2_diff >= 0) && ((t2_diff % 365) == 0);

  assign valid = t0_valid && t1_valid && t2_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      d0_cnt <= 9'd1;
      d1_cnt <= 9'd1;
      d2_cnt <= 9'd1;
      running <= 0;
      done <= 0;
      solution_found <= 0;
      d0 <= 0;
      d1 <= 0;
      d2 <= 0;
    end else begin
      if (running) begin
        if (valid) begin
          d0 <= d0_cnt;
          d1 <= d1_cnt;
          d2 <= d2_cnt;
          solution_found <= 1;
          done <= 1;
          running <= 0;
        end else if (d2_cnt == 365) begin
          d2_cnt <= 1;
          if (d1_cnt == 365) begin
            d1_cnt <= 1;
            if (d0_cnt == 365) begin
              done <= 1;
              solution_found <= 0;
              running <= 0;
            end else begin
              d0_cnt <= d0_cnt + 1;
            end
          end else begin
            d1_cnt <= d1_cnt + 1;
          end
        end else begin
          d2_cnt <= d2_cnt + 1;
        end
      end else if (start && !running) begin
        d0_cnt <= 9'd1;
        d1_cnt <= 9'd1;
        d2_cnt <= 9'd1;
        running <= 1;
        done <= 0;
        solution_found <= 0;
      end
    end
  end

endmodule