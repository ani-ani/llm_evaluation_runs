module divisible_subset (
  input clk,
  input rst_n,
  input start,
  input [7:0] numbers [7:0],
  input [2:0] size,
  output reg [3:0] max_size,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESS,
    DONE
  } state_t;

  state_t current_state;

  logic [3:0] dp [7:0];
  logic [2:0] i, j;
  logic [2:0] size_reg;
  logic [3:0] current_max;
  logic [3:0] overall_max;
  logic [3:0] i_finished;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      max_size <= 4'b0;
      foreach (dp[idx]) dp[idx] <= 4'b0;
      i <= 3'b0;
      j <= 3'b0;
      current_max <= 4'b0;
      overall_max <= 4'b0;
      size_reg <= 3'b0;
      i_finished <= 4'b0;
    end
    else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_state <= PROCESS;
            size_reg <= size;
            foreach (dp[idx]) dp[idx] <= 4'b0;
            i <= size - 1;
            j <= size;
            current_max <= 4'b0;
            overall_max <= 4'b0;
            i_finished <= 4'b0;
          end
        end

        PROCESS: begin
          if (i_finished == size_reg) begin
            current_state <= DONE;
          end
          else begin
            if (j < size_reg) begin
              logic cond_j, cond_j1;
              logic [3:0] valid_j, valid_j1;
              logic [3:0] found_max;

              cond_j = ((numbers[j] % numbers[i] == 0) || (numbers[i] % numbers[j] == 0));
              valid_j = cond_j ? dp[j] : 4'h0;

              if ((j + 1) < size_reg) begin
                cond_j1 = ((numbers[j + 1] % numbers[i] == 0) || (numbers[i] % numbers[j + 1] == 0));
                valid_j1 = cond_j1 ? dp[j + 1] : 4'h0;
                found_max = (valid_j > valid_j1) ? valid_j : valid_j1;
              end
              else begin
                found_max = valid_j;
              end

              if (found_max > current_max) begin
                current_max <= found_max;
              end

              j <= j + 2;
            end
            else begin
              dp[i] <= current_max + 1;
              if ((current_max + 1) > overall_max) begin
                overall_max <= current_max + 1;
              end
              i_finished <= i_finished + 1;
              if (i == 0) begin
                current_state <= DONE;
              end
              else begin
                i <= i - 1;
                j <= i;
                current_max <= 4'b0;
              end
            end
          end
        end

        DONE: begin
          max_size <= overall_max;
          done <= 1'b1;
          current_state <= IDLE;
        end

        default: current_state <= IDLE;
      endcase
    end
  end
endmodule