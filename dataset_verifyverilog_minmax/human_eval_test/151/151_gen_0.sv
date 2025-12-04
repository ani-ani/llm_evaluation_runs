module sum_odd_squares(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [7:0][15:0] numbers,
  output reg [19:0] sum,
  output reg done
);

  typedef enum logic {IDLE, RUN} state_t;
  state_t state;
  logic [2:0] cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum <= 20'b0;
      done <= 1'b0;
      cnt <= 3'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= RUN;
            sum <= 20'b0;
            done <= 1'b0;
            cnt <= 3'b0;
          end
        end
        RUN: begin
          // Process current number
          if ((numbers[cnt] > 0) && numbers[cnt][0]) begin
            sum <= sum + {4'b0, numbers[cnt][7:0] * numbers[cnt][7:0]};
          end
          // Increment counter and check for completion
          if (cnt == 3'b111) begin
            state <= IDLE;
            done <= 1'b1;
            cnt <= 3'b0;
          end else begin
            cnt <= cnt + 1;
            done <= 1'b0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule