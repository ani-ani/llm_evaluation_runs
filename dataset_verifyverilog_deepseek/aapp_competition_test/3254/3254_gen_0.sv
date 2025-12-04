module min_papers_average(
  input clk,
  input rst_n,
  input start,
  input [21:0] P_fixed,
  output reg [4:0] ones, twos, threes, fours, fives,
  output reg done
);

  enum logic [2:0] {IDLE, SEARCH, COMPUTE, CHECK, DONE} state;
  reg [4:0] ones_ctr, twos_ctr, threes_ctr, fours_ctr, fives_ctr;
  reg [4:0] best_ones, best_twos, best_threes, best_fours, best_fives;
  reg [8:0] minimal_total;
  reg [8:0] total_count;
  reg [9:0] sum_values;
  reg [19:0] product_sum, product_total;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      ones <= 0;
      twos <= 0;
      threes <= 0;
      fours <= 0;
      fives <= 0;
      best_ones <= 0;
      best_twos <= 0;
      best_threes <= 0;
      best_fours <= 0;
      best_fives <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            fives_ctr <= 31;
            fours_ctr <= 31;
            threes_ctr <= 31;
            twos_ctr <= 31;
            ones_ctr <= 31;
            minimal_total <= 155;
            state <= SEARCH;
          end
        end

        SEARCH: begin
          total_count = ones_ctr + twos_ctr + threes_ctr + fours_ctr + fives_ctr;
          if (total_count > minimal_total) begin
            if (ones_ctr == 0) begin
              ones_ctr <= 31;
              if (twos_ctr == 0) begin
                twos_ctr <= 31;
                if (threes_ctr == 0) begin
                  threes_ctr <= 31;
                  if (fours_ctr == 0) begin
                    fours_ctr <= 31;
                    if (fives_ctr == 0) begin
                      state <= DONE;
                    end else begin
                      fives_ctr <= fives_ctr - 1;
                    end
                  end else begin
                    fours_ctr <= fours_ctr - 1;
                  end
                end else begin
                  threes_ctr <= threes_ctr - 1;
                end
              end else begin
                twos_ctr <= twos_ctr - 1;
              end
            end else begin
              ones_ctr <= ones_ctr - 1;
            end
          end else begin
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          sum_values = (ones_ctr * 1) + (twos_ctr * 2) + (threes_ctr * 3) + (fours_ctr * 4) + (fives_ctr * 5);
          product_sum = sum_values * 20'd1024;
          product_total = total_count * P_fixed;
          state <= CHECK;
        end

        CHECK: begin
          if (product_sum == product_total[19:0] && product_total[21:20] == 0) begin
            if (total_count <= minimal_total) begin
              minimal_total <= total_count;
              best_ones <= ones_ctr;
              best_twos <= twos_ctr;
              best_threes <= threes_ctr;
              best_fours <= fours_ctr;
              best_fives <= fives_ctr;
            end
          end

          if (fives_ctr == 0 && fours_ctr == 0 && threes_ctr == 0 && twos_ctr == 0 && ones_ctr == 0) begin
            state <= DONE;
          end else begin
            state <= SEARCH;
            if (ones_ctr == 0) begin
              ones_ctr <= 31;
              if (twos_ctr == 0) begin
                twos_ctr <= 31;
                if (threes_ctr == 0) begin
                  threes_ctr <= 31;
                  if (fours_ctr == 0) begin
                    fours_ctr <= 31;
                    if (fives_ctr != 0) begin
                      fives_ctr <= fives_ctr - 1;
                    end
                  end else begin
                    fours_ctr <= fours_ctr - 1;
                  end
                end else begin
                  threes_ctr <= threes_ctr - 1;
                end
              end else begin
                twos_ctr <= twos_ctr - 1;
              end
            end else begin
              ones_ctr <= ones_ctr - 1;
            end
          end
        end

        DONE: begin
          done <= 1;
          ones <= best_ones;
          twos <= best_twos;
          threes <= best_threes;
          fours <= best_fours;
          fives <= best_fives;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end
endmodule