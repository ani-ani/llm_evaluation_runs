module sum_two_digit_elements(
  input clk,
  input rst_n,
  input start,
  input signed [12:0] arr [0:15],
  input [3:0] k,
  output reg signed [10:0] sum,
  output reg done
);

  typedef enum {IDLE, PROCESS, DONE_ST} state_t;
  state_t state;
  reg [4:0] counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= '0;
      done <= 0;
      state <= IDLE;
      counter <= '0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            sum <= '0;
            counter <= '0;
            state <= PROCESS;
          end
        end

        PROCESS: begin
          if (counter < k) begin
            automatic logic signed [12:0] elem = arr[counter];
            if ((elem >= 10 && elem <= 99) || (elem <= -10 && elem >= -99)) begin
              sum <= sum + elem;
            end
            counter <= counter + 1;
          end else begin
            state <= DONE_ST;
          end
        end

        DONE_ST: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule