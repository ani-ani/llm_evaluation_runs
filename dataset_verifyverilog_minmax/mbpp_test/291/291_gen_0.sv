module fence_painting (input clk, input rst_n, input start, input [2:0] n, input [1:0] k, output reg [15:0] result, output reg done);

localparam IDLE = 2'b00;
localparam CALCULATE = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [3:0] i;
reg [15:0] dp_curr, dp_prev1, dp_prev2, result;
reg start_prev;
logic [15:0] new_dp;

always_comb begin
  if (i == 1) begin
    new_dp = k;
  end else if (i == 2) begin
    new_dp = k * k;
  end else begin
    new_dp = (k-1) * (dp_prev1 + dp_prev2);
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    i <= 0;
    dp_curr <= 0;
    dp_prev1 <= 0;
    dp_prev2 <= 0;
    result <= 0;
    start_prev <= 0;
  end else begin
    start_prev <= start;
    case(state)
      IDLE: begin
        if (start && !start_prev) begin
          state <= CALCULATE;
          i <= 4'b0001;
          dp_prev1 <= 0;
          dp_prev2 <= 0;
        end else begin
          state <= IDLE;
        end
      end
      CALCULATE: begin
        dp_curr <= new_dp;
        if (i == n) begin
          state <= DONE;
          done <= 1;
          result <= new_dp;
        end else begin
          state <= CALCULATE;
          i <= i + 1;
          dp_prev2 <= dp_prev1;
          dp_prev1 <= new_dp;
        end
      end
      DONE: begin
        if (start && !start_prev) begin
          state <= IDLE;
          done <= 0;
        end else begin
          state <= DONE;
          done <= 1;
        end
      end
    endcase
  end
end

endmodule