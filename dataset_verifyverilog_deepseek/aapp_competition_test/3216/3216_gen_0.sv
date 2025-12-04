module repeating_decimal_to_fraction(
  input clk,
  input rst_n,
  input start,
  input [9:0] integer_part,
  input [13:0] non_rep_frac,
  input [13:0] rep_frac,
  input [3:0] repeat_count,
  output reg [26:0] numerator,
  output reg [26:0] denominator,
  output reg done
);

typedef enum {
  IDLE,
  CALC_DENOM,
  CALC_NUM,
  GCD_CALC,
  DIVIDE,
  DONE
} state_t;

reg [2:0] state;
reg [9:0] int_reg;
reg [13:0] nonrep_reg, rep_reg;
reg [3:0] rpt_reg, nv_reg;
reg [26:0] denominator_temp, numerator_temp;
reg [26:0] a_reg, b_reg;
reg [26:0] gcd_value;
reg [5:0] gcd_counter;
reg gcd_init;

function [26:0] power_10(input [3:0] exp);
  case(exp)
    4'd0: power_10 = 27'd1;
    4'd1: power_10 = 27'd10;
    4'd2: power_10 = 27'd100;
    4'd3: power_10 = 27'd1000;
    4'd4: power_10 = 27'd10000;
    4'd5: power_10 = 27'd100000;
    4'd6: power_10 = 27'd1000000;
    4'd7: power_10 = 27'd10000000;
    4'd8: power_10 = 27'd100000000;
    default: power_10 = 27'd1;
  endcase
endfunction

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    gcd_init <= 1;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        gcd_init <= 1;
        gcd_counter <= 0;
        if (start) begin
          int_reg <= integer_part;
          nonrep_reg <= non_rep_frac;
          rep_reg <= rep_frac;
          rpt_reg <= repeat_count;
          nv_reg <= 4'd4 - repeat_count;
          state <= CALC_DENOM;
        end
      end

      CALC_DENOM: begin
        denominator_temp <= power_10(nv_reg + rpt_reg) - power_10(nv_reg);
        state <= CALC_NUM;
      end

      CALC_NUM: begin
        numerator_temp <= (int_reg * power_10(4'd4)) + 
                         (nonrep_reg * power_10(rpt_reg)) + rep_reg - 
                         (int_reg * power_10(nv_reg) + nonrep_reg);
        state <= GCD_CALC;
      end

      GCD_CALC: begin
        if (gcd_init) begin
          a_reg <= numerator_temp;
          b_reg <= denominator_temp;
          gcd_counter <= 6'd50;
          gcd_init <= 0;
        end else if (gcd_counter > 0) begin
          gcd_counter <= gcd_counter - 1;
          if (a_reg > b_reg) begin
            a_reg <= a_reg - b_reg;
          end else if (b_reg > a_reg) begin
            b_reg <= b_reg - a_reg;
          end else begin
            gcd_value <= a_reg;
            state <= DIVIDE;
          end
          if (gcd_counter == 6'd1) begin
            gcd_value <= (a_reg > b_reg) ? (a_reg - b_reg) : (b_reg - a_reg);
            state <= DIVIDE;
          end
        end else begin
          gcd_value <= (a_reg != 0) ? a_reg : b_reg;
          state <= DIVIDE;
        end
      end

      DIVIDE: begin
        numerator <= numerator_temp / gcd_value;
        denominator <= denominator_temp / gcd_value;
        state <= DONE;
      end

      DONE: begin
        done <= 1;
        if (!start) state <= IDLE;
      end
    endcase
  end
end

endmodule