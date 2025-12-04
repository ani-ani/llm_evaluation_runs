module lucas_number(input clk, input rst_n, input start, input [3:0] n, output reg [10:0] result, output reg done);

  reg [3:0] count;
  reg [10:0] prev2;
  reg [10:0] prev1;
  reg state;

  localparam STATE_IDLE = 1'b0;
  localparam STATE_COMPUTING = 1'b1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      done <= 1'b0;
      result <= 11'd0;
      count <= 4'd0;
      prev2 <= 11'd0;
      prev1 <= 11'd0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (start) begin
            done <= 1'b0;
            if (n == 4'd0) begin
              result <= 11'd2;
              done <= 1'b1;
            end else if (n == 4'd1) begin
              result <= 11'd1;
              done <= 1'b1;
            end else begin
              prev2 <= 11'd2;
              prev1 <= 11'd1;
              count <= 4'd1;
              state <= STATE_COMPUTING;
            end
          end
        end

        STATE_COMPUTING: begin
          if (count < n) begin
            prev2 <= prev1;
            prev1 <= prev2 + prev1;
            count <= count + 4'd1;
          end else begin
            result <= prev1;
            done <= 1'b1;
            state <= STATE_IDLE;
          end
        end
      endcase
    end
  end
endmodule