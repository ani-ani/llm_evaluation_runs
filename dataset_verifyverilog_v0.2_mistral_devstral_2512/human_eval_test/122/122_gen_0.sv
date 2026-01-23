module sum_two_digit_k (
  input clk,
  input rst_n,
  input [2:0] k,
  input signed [7:0] arr [0:7],
  output reg signed [10:0] result,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [2:0] i = 0;
  reg signed [10:0] sum = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          state <= PROCESSING;
          i <= 0;
          sum <= 0;
          result <= 0;
          done <= 0;
        end
        PROCESSING: begin
          if (i < k) begin
            if (($signed(arr[i]) >= -99) && ($signed(arr[i]) <= 99)) begin
              sum <= sum + $signed(arr[i]);
            end
            i <= i + 1;
          end else begin
            state <= DONE;
            result <= sum;
            done <= 1;
          end
        end
        DONE: begin
          // Stay in DONE state
        end
      endcase
    end
  end

endmodule