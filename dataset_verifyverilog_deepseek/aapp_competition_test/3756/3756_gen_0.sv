module grade_rounder(
  input clk,
  input rst_n,
  input start,
  input [3:0] grade_len,
  input [119:0] grade_in,
  input [2:0] t_in,
  output reg [119:0] grade_out,
  output reg [3:0] out_len,
  output reg done
);

  typedef enum logic [1:0] { 
    IDLE,
    FIND_POSITION,
    ROUND_PROPAGATE,
    TRIM_TRAILING
  } state_t;

  reg [1:0] state;
  reg [3:0] grade_len_reg;
  reg [119:0] grade_in_reg;
  reg [2:0] t_capped;
  reg [3:0] decimal_pos;
  reg [3:0] round_pos;
  reg has_rounding;
  reg [3:0] j_pos;
  reg [119:0] temp_grade;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      grade_out <= 0;
      out_len <= 0;
      grade_len_reg <= 0;
      grade_in_reg <= 0;
      t_capped <= 0;
      decimal_pos <= 0;
      round_pos <= 0;
      has_rounding <= 0;
      j_pos <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            grade_len_reg <= grade_len;
            grade_in_reg <= grade_in;
            t_capped <= (t_in > 4) ? 3'd4 : t_in;
            state <= FIND_POSITION;
          end
        end

        FIND_POSITION: begin
          decimal_pos <= 4'd15;
          for (int i=0; i<15; i++) begin
            if (i < grade_len_reg && grade_in_reg[i*8 +:8] == 8'h2E) begin
              decimal_pos <= i;
            end
          end

          if (decimal_pos == 15 || decimal_pos >= grade_len_reg -1) begin
            has_rounding <= 1'b0;
            state <= TRIM_TRAILING;
          end else begin
            automatic int num_frac_digits = grade_len_reg - decimal_pos -1;
            automatic int num_steps = (t_capped < num_frac_digits) ? t_capped : num_frac_digits;
            automatic reg found = 1'b0;
            automatic reg [3:0] j_pos_temp = 4'd15;

            for (int k=0; k<num_steps; k++) begin
              automatic int pos = decimal_pos +1 + k;
              if (pos < grade_len_reg && grade_in_reg[pos*8 +:8] >= 8'h35
                  && grade_in_reg[pos*8 +:8] <=8'h39 && !found) begin
                j_pos_temp = pos;
                found = 1'b1;
              end
            end

            if (found) begin
              has_rounding <= 1'b1;
              round_pos <= j_pos_temp -1;
              j_pos <= j_pos_temp;
            end else begin
              has_rounding <= 1'b0;
            end
            state <= ROUND_PROPAGATE;
          end
        end

        ROUND_PROPAGATE: begin
          temp_grade = grade_in_reg;
          if (has_rounding) begin
            automatic reg carry = 1'b1;
            for (int i=round_pos; i>=0; i--) begin
              if (temp_grade[i*8 +:8] != 8'h2E) begin
                automatic logic [7:0] c = temp_grade[i*8 +:8];
                automatic logic [3:0] digit_val = c - 8'h30;
                automatic logic [3:0] sum = digit_val + carry;
                if (sum >= 10) begin
                  temp_grade[i*8 +:8] = 8'h30 + sum -10;
                  carry = 1'b1;
                end else begin
                  temp_grade[i*8 +:8] = 8'h30 + sum;
                  carry = 1'b0;
                  break;
                end
              end
            end
            for (int i=j_pos; i<15; i++) begin
              if (i < grade_len_reg && temp_grade[i*8 +:8] != 8'h2E) begin
                temp_grade[i*8 +:8] = 8'h30;
              end
            end
          end
          grade_in_reg <= temp_grade;
          state <= TRIM_TRAILING;
        end

        TRIM_TRAILING: begin
          automatic reg [3:0] last_non_zero = decimal_pos;
          automatic reg soft_found = 0;
          if (decimal_pos < grade_len_reg) begin
            for (int i=grade_len_reg-1; i>decimal_pos; i--) begin
              if (!soft_found && grade_in_reg[i*8 +:8] != 8'h30
                  && grade_in_reg[i*8 +:8] != 8'h2E) begin
                last_non_zero = i;
                soft_found = 1;
              end
            end
            if (last_non_zero == decimal_pos) begin
              out_len <= decimal_pos;
            end else begin
              out_len <= last_non_zero +1;
            end
          end else begin
            out_len <= grade_len_reg;
          end

          if (grade_len_reg != 0) begin
            grade_out <= grade_in_reg;
            grade_out[((last_non_zero+1)*8) +: (15-last_non_zero-1)*8] <= '0;
          end
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
