module event_duration_solver(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // begins computation
  // Telescope 0 inputs
  input [4:0] t0_start_day, // 1-31
  input [3:0] t0_start_month, // 1-12
  input [4:0] t0_end_day, // 1-31
  input [3:0] t0_end_month, // 1-12
  input [7:0] t0_freq0, t0_freq1, t0_freq2, // event frequencies (0-200)
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
  output reg [8:0] d0, d1, d2, // event durations (1-365)
  output reg solution_found, // high when valid solution found
  output reg done // high when computation completes
);

  // Day-of-year calculation (non-leap year)
  function [8:0] doy_start;
    input [4:0] day;
    input [3:0] month;
    reg [4:0] max_day;
  begin
    max_day = 31;
    case (month)
      2:  max_day = 28;
      3:  max_day = 31;
      4:  max_day = 30;
      5:  max_day = 31;
      6:  max_day = 30;
      7:  max_day = 31;
      8:  max_day = 31;
      9:  max_day = 30;
      10: max_day = 31;
      11: max_day = 30;
      12: max_day = 31;
      default: max_day = 31;
    endcase
    if (day > max_day) begin
      doy_start = 9'b0; // invalid date -> doy 0
    end else begin
      case (month)
        1:  doy_start = day - 1;
        2:  doy_start = 31 + (day - 1);
        3:  doy_start = 31 + 28 + (day - 1);
        4:  doy_start = 31 + 28 + 31 + (day - 1);
        5:  doy_start = 31 + 28 + 31 + 30 + (day - 1);
        6:  doy_start = 31 + 28 + 31 + 30 + 31 + (day - 1);
        7:  doy_start = 31 + 28 + 31 + 30 + 31 + 30 + (day - 1);
        8:  doy_start = 31 + 28 + 31 + 30 + 31 + 30 + 31 + (day - 1);
        9:  doy_start = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + (day - 1);
        10: doy_start = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + (day - 1);
        11: doy_start = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + (day - 1);
        12: doy_start = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30 + (day - 1);
        default: doy_start = 9'b0;
      endcase
    end
  end
  endfunction

  function [8:0] doy_end;
    input [4:0] day;
    input [3:0] month;
    reg [4:0] max_day;
  begin
    max_day = 31;
    case (month)
      2:  max_day = 28;
      3:  max_day = 31;
      4:  max_day = 30;
      5:  max_day = 31;
      6:  max_day = 30;
      7:  max_day = 31;
      8:  max_day = 31;
      9:  max_day = 30;
      10: max_day = 31;
      11: max_day = 30;
      12: max_day = 31;
      default: max_day = 31;
    endcase
    if (day > max_day) begin
      doy_end = 9'b0; // invalid date -> doy 0
    end else begin
      case (month)
        1:  doy_end = day - 1;
        2:  doy_end = 31 + (day - 1);
        3:  doy_end = 31 + 28 + (day - 1);
        4:  doy_end = 31 + 28 + 31 + (day - 1);
        5:  doy_end = 31 + 28 + 31 + 30 + (day - 1);
        6:  doy_end = 31 + 28 + 31 + 30 + 31 + (day - 1);
        7:  doy_end = 31 + 28 + 31 + 30 + 31 + 30 + (day - 1);
        8:  doy_end = 31 + 28 + 31 + 30 + 31 + 30 + 31 + (day - 1);
        9:  doy_end = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + (day - 1);
        10: doy_end = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + (day - 1);
        11: doy_end = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + (day - 1);
        12: doy_end = 31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30 + (day - 1);
        default: doy_end = 9'b0;
      endcase
    end
  end
  endfunction

  // Iteration counters (9-bit to cover 1..365)
  reg [8:0] d0_cnt;
  reg [8:0] d1_cnt;
  reg [8:0] d2_cnt;
  // FSM state
  reg [1:0] state;
  localparam IDLE = 2'b00, RUN = 2'b01, FINISH = 2'b10;

  // Precomputed day-of-year and difference (valid on start, stable during search)
  reg [8:0] t0_s_doy, t0_e_doy, t0_diff;
  reg [8:0] t1_s_doy, t1_e_doy, t1_diff;
  reg [8:0] t2_s_doy, t2_e_doy, t2_diff;

  // Compute comparisons in one cycle (to ensure pipelined 1-combination/cycle throughput)
  wire t0_ok;
  wire t1_ok;
  wire t2_ok;
  wire all_ok;

  // Current sums using counter values
  wire [16:0] sum0;
  wire [16:0] sum1;
  wire [16:0] sum2;

  assign sum0 = t0_freq0 * d0_cnt + t0_freq1 * d1_cnt + t0_freq2 * d2_cnt;
  assign sum1 = t1_freq0 * d0_cnt + t1_freq1 * d1_cnt + t1_freq2 * d2_cnt;
  assign sum2 = t2_freq0 * d0_cnt + t2_freq1 * d1_cnt + t2_freq2 * d2_cnt;

  // Condition: (sum - days_diff) % 365 == 0 AND sum >= days_diff
  // Equivalent to: sum >= days_diff && (sum - days_diff) divisible by 365
  // Since max sum < 365*3*200 = 219000, we can safely test k*365 difference up to 365*600
  // but we only need to check if the remainder matches days_diff.
  assign t0_ok = (sum0 >= t0_diff) && ((sum0 - t0_diff) % 365 == 0);
  assign t1_ok = (sum1 >= t1_diff) && ((sum1 - t1_diff) % 365 == 0);
  assign t2_ok = (sum2 >= t2_diff) && ((sum2 - t2_diff) % 365 == 0);
  assign all_ok = t0_ok && t1_ok && t2_ok;

  // Sequential iteration logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset outputs and state
      d0 <= 9'b0;
      d1 <= 9'b0;
      d2 <= 9'b0;
      solution_found <= 1'b0;
      done <= 1'b0;
      d0_cnt <= 9'b0;
      d1_cnt <= 9'b0;
      d2_cnt <= 9'b0;
      state <= IDLE;
      // Precomputed differences
      t0_s_doy <= 9'b0; t0_e_doy <= 9'b0; t0_diff <= 9'b0;
      t1_s_doy <= 9'b0; t1_e_doy <= 9'b0; t1_diff <= 9'b0;
      t2_s_doy <= 9'b0; t2_e_doy <= 9'b0; t2_diff <= 9'b0;
    end else begin
      case (state)
        IDLE: begin
          d0 <= 9'b0; d1 <= 9'b0; d2 <= 9'b0;
          solution_found <= 1'b0; done <= 1'b0;
          d0_cnt <= 9'b0; d1_cnt <= 9'b0; d2_cnt <= 9'b0;
          // Precompute day-of-year and differences from inputs (combinational)
          t0_s_doy <= doy_start(t0_start_day, t0_start_month);
          t0_e_doy <= doy_end(t0_end_day, t0_end_month);
          t0_diff  <= (t0_e_doy >= t0_s_doy) ? (t0_e_doy - t0_s_doy) : (t0_e_doy + (9'd365 - t0_s_doy));
          t1_s_doy <= doy_start(t1_start_day, t1_start_month);
          t1_e_doy <= doy_end(t1_end_day, t1_end_month);
          t1_diff  <= (t1_e_doy >= t1_s_doy) ? (t1_e_doy - t1_s_doy) : (t1_e_doy + (9'd365 - t1_s_doy));
          t2_s_doy <= doy_start(t2_start_day, t2_start_month);
          t2_e_doy <= doy_end(t2_end_day, t2_end_month);
          t2_diff  <= (t2_e_doy >= t2_s_doy) ? (t2_e_doy - t2_s_doy) : (t2_e_doy + (9'd365 - t2_s_doy));

          if (start) begin
            d0_cnt <= 9'd1;
            d1_cnt <= 9'd1;
            d2_cnt <= 9'd1;
            state <= RUN;
          end
        end

        RUN: begin
          // Evaluate current combination in the same cycle
          if (all_ok) begin
            d0 <= d0_cnt;
            d1 <= d1_cnt;
            d2 <= d2_cnt;
            solution_found <= 1'b1;
            done <= 1'b1;
            state <= FINISH;
          end else begin
            // Nested counters: d0 -> d1 -> d2
            if (d0_cnt < 9'd365) begin
              d0_cnt <= d0_cnt + 1;
            end else begin
              d0_cnt <= 9'd1;
              if (d1_cnt < 9'd365) begin
                d1_cnt <= d1_cnt + 1;
              end else begin
                d1_cnt <= 9'd1;
                if (d2_cnt < 9'd365) begin
                  d2_cnt <= d2_cnt + 1;
                end else begin
                  // Completed all combinations without finding a solution
                  done <= 1'b1;
                  solution_found <= 1'b0;
                  state <= FINISH;
                end
              end
            end
          end
        end

        FINISH: begin
          // Hold final outputs and signals until reset or a new start
          done <= 1'b1;
          if (start) begin
            // Allow re-start
            d0_cnt <= 9'd1; d1_cnt <= 9'd1; d2_cnt <= 9'd1;
            d0 <= 9'b0; d1 <= 9'b0; d2 <= 9'b0;
            solution_found <= 1'b0;
            // Re-latch precomputed differences (combinational)
            t0_s_doy <= doy_start(t0_start_day, t0_start_month);
            t0_e_doy <= doy_end(t0_end_day, t0_end_month);
            t0_diff  <= (t0_e_doy >= t0_s_doy) ? (t0_e_doy - t0_s_doy) : (t0_e_doy + (9'd365 - t0_s_doy));
            t1_s_doy <= doy_start(t1_start_day, t1_start_month);
            t1_e_doy <= doy_end(t1_end_day, t1_end_month);
            t1_diff  <= (t1_e_doy >= t1_s_doy) ? (t1_e_doy - t1_s_doy) : (t1_e_doy + (9'd365 - t1_s_doy));
            t2_s_doy <= doy_start(t2_start_day, t2_start_month);
            t2_e_doy <= doy_end(t2_end_day, t2_end_month);
            t2_diff  <= (t2_e_doy >= t2_s_doy) ? (t2_e_doy - t2_s_doy) : (t2_e_doy + (9'd365 - t2_s_doy));
            state <= RUN;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
