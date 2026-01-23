module contest_scheduler (
  input clk,
  input rst_n,
  input start,
  input [4:0] year_count,
  input [4:0] forbidden_count,
  input [4:0] forbidden_year [0:4],
  input [4:0] forbidden_day [0:4],
  output reg [15:0] min_penalty,
  output reg [4:0] result_year [0:1],
  output reg [4:0] result_day [0:1],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_THANKSGIVING,
    FIND_FRIDAYS,
    BUILD_DP,
    EXTRACT_RESULT,
    DONE
  } state_t;

  state_t state;
  reg [4:0] current_year;
  reg [4:0] current_day;
  reg [4:0] thanksgiving_day [0:1];
  reg [4:0] valid_fridays [0:1][0:30];
  reg [4:0] valid_count [0:1];
  reg [15:0] dp [0:1][0:31];
  reg [4:0] prev_date [0:1];
  reg [4:0] i, j, k;
  reg [15:0] temp_penalty;

  // Helper functions
  function logic is_leap_year(input [4:0] year);
    return (year == 2020);
  endfunction

  function logic [4:0] day_of_week(input [4:0] year, input [4:0] month, input [4:0] day);
    // Zeller's congruence simplified for October (month=10)
    reg [7:0] m = 10;
    reg [7:0] K = 1;
    reg [7:0] h;
    if (m < 3) begin
      m = m + 12;
      K = 0;
    end
    h = (day + (13*(m+1))/5 + K + year + year/4 - year/100 + year/400) % 7;
    return h;
  endfunction

  function logic [4:0] find_thanksgiving(input [4:0] year);
    // Canadian Thanksgiving is 2nd Monday in October
    reg [4:0] day;
    for (day = 1; day <= 31; day = day + 1) begin
      if (day_of_week(year, 10, day) == 1) begin // Monday
        if (day >= 8 && day <= 14) return day;
      end
    end
    return 8; // Default if not found
  endfunction

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_penalty <= 0;
      for (i = 0; i < 2; i = i + 1) begin
        result_year[i] <= 0;
        result_day[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_THANKSGIVING;
            current_year <= 0;
          end
        end

        CALC_THANKSGIVING: begin
          if (current_year < year_count) begin
            thanksgiving_day[current_year] <= find_thanksgiving(2019 + current_year);
            current_year <= current_year + 1;
          end else begin
            state <= FIND_FRIDAYS;
            current_year <= 0;
            current_day <= 0;
          end
        end

        FIND_FRIDAYS: begin
          if (current_year < year_count) begin
            if (current_day < 31) begin
              reg [4:0] dow = day_of_week(2019 + current_year, 10, current_day + 1);
              reg [4:0] day = current_day + 1;
              reg valid = (dow == 5) && (day != thanksgiving_day[current_year] - 1);
              
              // Check forbidden dates
              for (k = 0; k < forbidden_count; k = k + 1) begin
                if (forbidden_year[k] == current_year + 1 && forbidden_day[k] == day) begin
                  valid = 0;
                end
              end
              
              if (valid) begin
                valid_fridays[current_year][valid_count[current_year]] <= day;
                valid_count[current_year] <= valid_count[current_year] + 1;
              end
              current_day <= current_day + 1;
            end else begin
              current_year <= current_year + 1;
              current_day <= 0;
            end
          end else begin
            state <= BUILD_DP;
            i <= 0;
            j <= 0;
            // Initialize DP table
            for (k = 0; k < 32; k = k + 1) begin
              dp[0][k] <= 0;
            end
          end
        end

        BUILD_DP: begin
          if (i < year_count - 1) begin
            if (j < valid_count[i+1]) begin
              reg [4:0] current_date = valid_fridays[i+1][j];
              reg [15:0] min_val = 16'hFFFF;
              reg [4:0] best_prev = 0;
              
              for (k = 0; k < valid_count[i]; k = k + 1) begin
                reg [4:0] prev_date_val = valid_fridays[i][k];
                reg [15:0] penalty = dp[i][prev_date_val] + (current_date - prev_date_val)*(current_date - prev_date_val);
                if (penalty < min_val) begin
                  min_val = penalty;
                  best_prev = prev_date_val;
                end
              end
              
              dp[i+1][current_date] <= min_val;
              prev_date[i+1] <= best_prev;
              j <= j + 1;
            end else begin
              i <= i + 1;
              j <= 0;
            end
          end else begin
            state <= EXTRACT_RESULT;
            i <= year_count - 1;
            min_penalty <= 16'hFFFF;
            result_day[i] <= 0;
          end
        end

        EXTRACT_RESULT: begin
          if (i >= 0) begin
            reg [4:0] best_date = 0;
            reg [15:0] min_val = 16'hFFFF;
            
            for (k = 0; k < valid_count[i]; k = k + 1) begin
              reg [4:0] date = valid_fridays[i][k];
              if (dp[i][date] < min_val) begin
                min_val = dp[i][date];
                best_date = date;
              end
            end
            
            result_day[i] <= best_date;
            result_year[i] <= i + 1;
            min_penalty <= min_val;
            
            if (i > 0) begin
              i <= i - 1;
              result_day[i] <= prev_date[i+1];
              result_year[i] <= i + 1;
            end else begin
              state <= DONE;
              done <= 1;
            end
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule