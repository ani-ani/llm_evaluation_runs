module series_sum(input clk, input rst_n, input start, input [4:0] n_in, output reg [7:0] sum, output reg done);
  typedef enum logic {IDLE, COMPUTE} state_t;
  state_t state;
  reg signed [5:0] current;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= 8'b0;
      done <= 1'b0;
      state <= IDLE;
      current <= 6'sb0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            sum <= {3'b0, n_in};
            current <= $signed({1'b0, n_in}) - 6'sd2;
            state <= COMPUTE;
          end
        end
        COMPUTE: begin
          if (current > 0) begin
            sum <= sum + current;
            current <= current - 6'sd2;
          end else begin
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule