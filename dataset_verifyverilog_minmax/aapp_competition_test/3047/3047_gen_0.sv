module puzzle_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] burger [0:2],
  input [7:0] slop [0:2],
  input [7:0] sushi [0:2],
  input [7:0] drumstick [0:2],
  output reg [15:0] num_solutions,
  output reg many_flag,
  output reg done
);

  // Internal registers
  reg [7:0] b_reg [0:2];
  reg [7:0] s_reg [0:2];
  reg [7:0] su_reg [0:2];
  reg [7:0] d_reg [0:2];

  reg [1:0] monster_idx;
  reg [1:0] sub_state; // 0=INIT, 1=CASE2, 2=FINISH
  reg [1:0] factor_state; // 0=init, 1=loop, 2=done
  reg [1:0] case2_type; // 0=unknown, 1=factor, 2=gcd
  reg [7:0] prod_case2;
  reg [7:0] known_left, known_right;
  reg [7:0] a_start, a;
  reg [7:0] count_factor;
  reg [7:0] count_monster;
  reg many_monster;

  // Current monster known flags and values
  reg known_b, known_s, known_su, known_d;
  reg [1:0] known_count;
  reg left_has_zero, right_has_zero;

  // Total solution counter
  reg [15:0] total_solutions;
  reg [31:0] temp_prod;

  // State encoding
  typedef enum logic [1:0] {ST_IDLE=2'b00, ST_CAPTURE=2'b01, ST_PROC=2'b10, ST_DONE=2'b11} state_t;
  state_t state;

  // GCD function for 8-bit values
  function [7:0] gcd8;
    input [7:0] a, b;
    reg [7:0] x, y;
    begin
      x = a; y = b;
      while (y != 8'h00) begin
        reg [7:0] t;
        t = y;
        y = x % y;
        x = t;
      end
      gcd8 = x;
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      done <= 1'b0;
      many_flag <= 1'b0;
      total_solutions <= 16'h0001;
      monster_idx <= 2'b00;
      sub_state <= 2'b00;
      factor_state <= 2'b00;
      case2_type <= 2'b00;
      prod_case2 <= 8'h00;
      known_left <= 8'h00;
      known_right <= 8'h00;
      a_start <= 8'h00;
      a <= 8'h00;
      count_factor <= 8'h00;
      count_monster <= 8'h00;
      many_monster <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          many_flag <= 1'b0;
          total_solutions <= 16'h0001;
          monster_idx <= 2'b00;
          sub_state <= 2'b00;
          factor_state <= 2'b00;
          case2_type <= 2'b00;
          if (start) begin
            state <= ST_CAPTURE;
          end
        end

        ST_CAPTURE: begin
          // Capture inputs
          b_reg[0] <= burger[0];
          b_reg[1] <= burger[1];
          b_reg[2] <= burger[2];
          s_reg[0] <= slop[0];
          s_reg[1] <= slop[1];
          s_reg[2] <= slop[2];
          su_reg[0] <= sushi[0];
          su_reg[1] <= sushi[1];
          su_reg[2] <= sushi[2];
          d_reg[0] <= drumstick[0];
          d_reg[1] <= drumstick[1];
          d_reg[2] <= drumstick[2];
          state <= ST_PROC;
          sub_state <= 2'b00; // start with INIT
        end

        ST_PROC: begin
          // Process current monster
          case (sub_state)
            2'b00: begin // INIT
              // Load current monster values and known flags
              known_b <= (b_reg[monster_idx] != 8'hFF);
              known_s <= (s_reg[monster_idx] != 8'hFF);
              known_su <= (su_reg[monster_idx] != 8'hFF);
              known_d <= (d_reg[monster_idx] != 8'hFF);

              // Count known values
              known_count <= (known_b ? 1 : 0) + (known_s ? 1 : 0) + (known_su ? 1 : 0) + (known_d ? 1 : 0);

              // Determine zero presence on each side
              left_has_zero <= ((known_b && (b_reg[monster_idx] == 8'h00)) || (known_d && (d_reg[monster_idx] == 8'h00)));
              right_has_zero <= ((known_s && (s_reg[monster_idx] == 8'h00)) || (known_su && (su_reg[monster_idx] == 8'h00)));

              // Initialize per-monster outputs
              many_monster <= 1'b0;
              count_monster <= 8'h00;

              // Handle zero cases
              if (left_has_zero && right_has_zero) begin
                // Infinite solutions (0 = 0)
                many_monster <= 1'b1;
                sub_state <= 2'b10; // go to FINISH
              end else if (left_has_zero || right_has_zero) begin
                // No solutions (cannot achieve 0 with positive values)
                count_monster <= 8'h00;
                sub_state <= 2'b10; // FINISH
              end else begin
                // No zeros, proceed based on known_count
                case (known_count)
                  2'b00: begin // all missing
                    many_monster <= 1'b1;
                    sub_state <= 2'b10; // FINISH
                  end
                  2'b01: begin // one known value
                    many_monster <= 1'b1;
                    sub_state <= 2'b10; // FINISH
                  end
                  2'b10: begin // two known values -> need to handle factor/gcd
                    sub_state <= 2'b01; // go to CASE2
                    factor_state <= 2'b00; // init factor loop
                    case2_type <= 2'b00; // unknown yet
                  end
                  2'b11: begin // three known values -> unique solution check
                    // Determine which value is missing
                    if (!known_b) begin
                      // b missing: b = (s*su)/d
                      if (d_reg[monster_idx] != 8'h00) begin
                        reg [15:0] numerator = s_reg[monster_idx] * su_reg[monster_idx];
                        if (numerator % d_reg[monster_idx] == 8'h00) begin
                          reg [15:0] b_candidate = numerator / d_reg[monster_idx];
                          if (b_candidate >= 1 && b_candidate <= 255) count_monster <= 8'h01;
                        end
                      end
                    end else if (!known_s) begin
                      // s missing: s = (b*d)/su
                      if (su_reg[monster_idx] != 8'h00) begin
                        reg [15:0] numerator = b_reg[monster_idx] * d_reg[monster_idx];
                        if (numerator % su_reg[monster_idx] == 8'h00) begin
                          reg [15:0] s_candidate = numerator / su_reg[monster_idx];
                          if (s_candidate >= 1 && s_candidate <= 255) count_monster <= 8'h01;
                        end
                      end
                    end else if (!known_su) begin
                      // su missing: su = (b*d)/s
                      if (s_reg[monster_idx] != 8'h00) begin
                        reg [15:0] numerator = b_reg[monster_idx] * d_reg[monster_idx];
                        if (numerator % s_reg[monster_idx] == 8'h00) begin
                          reg [15:0] su_candidate = numerator / s_reg[monster_idx];
                          if (su_candidate >= 1 && su_candidate <= 255) count_monster <= 8'h01;
                        end
                      end
                    end else begin
                      // d missing: d = (s*su)/b
                      if (b_reg[monster_idx] != 8'h00) begin
                        reg [15:0] numerator = s_reg[monster_idx] * su_reg[monster_idx];
                        if (numerator % b_reg[monster_idx] == 8'h00) begin
                          reg [15:0] d_candidate = numerator / b_reg[monster_idx];
                          if (d_candidate >= 1 && d_candidate <= 255) count_monster <= 8'h01;
                        end
                      end
                    end
                    sub_state <= 2'b10; // FINISH
                  end
                  default: begin // four known values
                    if ((b_reg[monster_idx] * d_reg[monster_idx]) == (s_reg[monster_idx] * su_reg[monster_idx]))
                      count_monster <= 8'h01;
                    else
                      count_monster <= 8'h00;
                    sub_state <= 2'b10; // FINISH
                  end
                endcase
              end
            end

            2'b01: begin // CASE2 (two known values)
              if (case2_type == 2'b00) begin
                // Determine which two are known and set case2_type
                if (known_b && known_d) begin
                  // (b,d) product
                  case2_type <= 2'b01; // factor
                  prod_case2 <= b_reg[monster_idx] * d_reg[monster_idx];
                end else if (known_s && known_su) begin
                  // (s,su) product
                  case2_type <= 2'b01;
                  prod_case2 <= s_reg[monster_idx] * su_reg[monster_idx];
                end else if (known_b && known_s) begin
                  // (b,s) product
                  case2_type <= 2'b01;
                  prod_case2 <= b_reg[monster_idx] * s_reg[monster_idx];
                end else if (known_d && known_su) begin
                  // (d,su) product
                  case2_type <= 2'b01;
                  prod_case2 <= d_reg[monster_idx] * su_reg[monster_idx];
                end else if (known_b && known_su) begin
                  // (b,su) gcd case
                  case2_type <= 2'b10; // gcd
                  known_left <= b_reg[monster_idx];
                  known_right <= su_reg[monster_idx];
                end else if (known_d && known_s) begin
                  // (d,s) gcd case
                  case2_type <= 2'b10;
                  known_left <= d_reg[monster_idx];
                  known_right <= s_reg[monster_idx];
                end else begin
                  // Should not happen
                  case2_type <= 2'b01; // default to factor with product 0
                  prod_case2 <= 8'h00;
                end
                // After setting case2_type, proceed to next cycle for handling
                factor_state <= 2'b00; // reset factor_state for factor case
              end else begin
                // case2_type already set, handle accordingly
                if (case2_type == 2'b01) begin // factor case
                  if (factor_state == 2'b00) begin
                    // Initialize factor loop
                    if (prod_case2 == 8'h00) begin
                      count_monster <= 8'h00;
                      sub_state <= 2'b10; // FINISH
                    end else begin
                      // Compute a_start = ceil(prod/255)
                      a_start <= (prod_case2 + 8'd254) / 8'd255; // integer division
                      a <= a_start;
                      count_factor <= 8'h00;
                      factor_state <= 2'b01; // go to loop
                    end
                  end else if (factor_state == 2'b01) begin
                    // Factor loop
                    if (a <= 8'd255 && (a * a) <= prod_case2) begin
                      if (prod_case2 % a == 8'h00) count_factor <= count_factor + 1;
                      a <= a + 1;
                    end else begin
                      // Loop finished
                      count_monster <= count_factor;
                      sub_state <= 2'b10; // FINISH
                    end
                  end
                end else if (case2_type == 2'b10) begin // gcd case
                  // Compute count directly using gcd
                  reg [7:0] g = gcd8(known_left, known_right);
                  reg [7:0] a_prime = known_left / g;
                  reg [7:0] b_prime = known_right / g;
                  reg [7:0] t_max1 = 8'd255 / a_prime;
                  reg [7:0] t_max2 = 8'd255 / b_prime;
                  reg [7:0] t_max = (t_max1 < t_max2) ? t_max1 : t_max2;
                  count_monster <= t_max;
                  sub_state <= 2'b10; // FINISH
                end
              end
            end

            2'b10: begin // FINISH: update totals and move to next monster
              if (many_monster) many_flag <= 1'b1;
              else if (!many_flag) begin
                if (count_monster == 8'h00) total_solutions <= 16'h0000;
                else begin
                  temp_prod = total_solutions * count_monster;
                  if (temp_prod > 16'hFFFF) total_solutions <= 16'hFFFF;
                  else total_solutions <= temp_prod[15:0];
                end
              end
              // Move to next monster or finish
              if (monster_idx == 2'b10) begin
                // All monsters processed
                num_solutions <= total_solutions;
                done <= 1'b1;
                state <= ST_IDLE;
              end else begin
                monster_idx <= monster_idx + 1;
                sub_state <= 2'b00; // start next monster
              end
            end

            default: begin
              sub_state <= 2'b00;
            end
          endcase
        end

        ST_DONE: begin
          // Wait for start deassertion or reset
          if (!start) begin
            done <= 1'b0;
            state <= ST_IDLE;
          end
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule