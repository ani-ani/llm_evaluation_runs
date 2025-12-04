module string_interleave_check (input clk, input rst_n, input start, input [2:0] len_s, input [7:0][4:0] s, input [2:0] len_s1, input [7:0][4:0] s1, input [2:0] len_s2, input [7:0][4:0] s2, output reg done, output reg result);
  typedef enum logic [1:0] {IDLE, COMPUTE_ROW, CHECK_COMPLETE, DONE} state_t;
  state_t state, next_state;
  reg [2:0] i, j;
  reg [7:0] dp_current;
  reg [7:0] dp_next;
  reg result_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      result_reg <= 0;
      i <= 0;
      j <= 0;
      dp_current <= 0;
      dp_next <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 0;
          result <= 0;
          if (start) begin
            if (len_s != (len_s1 + len_s2)) begin
              result_reg <= 0;
              next_state <= DONE;
            end else begin
              i <= 0;
              j <= 0;
              dp_current <= 0;
              dp_current[0] <= 1'b1;
              dp_next <= 0;
              next_state <= COMPUTE_ROW;
            end
          end else begin
            next_state <= IDLE;
          end
        end

        COMPUTE_ROW: begin
          if (i == 0) begin
            if (j < len_s2 + 1) begin
              if (j > 0) begin
                if (j <= len_s2) begin
                  if (dp_current[j-1] && (s2[j-1] == s[j-1]))
                    dp_current[j] <= 1'b1;
                  else
                    dp_current[j] <= 1'b0;
                end
                j <= j + 1;
              end else begin
                j <= j + 1;
              end
            end else begin
              if (i == len_s1) begin
                next_state <= CHECK_COMPLETE;
              end else begin
                i <= i + 1;
                j <= 0;
              end
            end
          end else begin
            if (j < len_s2 + 1) begin
              if (j <= len_s2) begin
                automatic logic cond1 = dp_current[j] && (s1[i-1] == s[i+j-1]);
                automatic logic cond2 = (j > 0) ? (dp_next[j-1] && (s2[j-1] == s[i+j-1])) : 1'b0;
                dp_next[j] <= cond1 || cond2;
              end
              j <= j + 1;
            end else begin
              dp_current <= dp_next;
              dp_next <= 0;
              if (i == len_s1) begin
                next_state <= CHECK_COMPLETE;
              end else begin
                i <= i + 1;
                j <= 0;
              end
            end
          end
        end

        CHECK_COMPLETE: begin
          result_reg <= (dp_current[len_s2] && (i == len_s1) && (j > len_s2));
          next_state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          result <= result_reg;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end
endmodule