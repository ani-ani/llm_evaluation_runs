module digit_counter (
  input clk,
  input rst_n,
  input start,
  input [127:0] str,
  output reg [4:0] count,
  output reg done
);

reg start_prev;
wire start_rising;
assign start_rising = start && !start_prev;

reg [1:0] state;
parameter IDLE = 2'b00;
parameter COUNT = 2'b01;

reg [3:0] idx;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    idx <= 4'b0;
    count <= 5'b0;
    done <= 1'b0;
    start_prev <= 1'b0;
  end else begin
    start_prev <= start;
    case (state)
      IDLE: begin
        if (start_rising) begin
          state <= COUNT;
          idx <= 4'b0;
          count <= 5'b0;
          done <= 1'b0;
        end
      end
      COUNT: begin
        if (str[127 - (idx * 8) -: 8] >= 8'h30 && str[127 - (idx * 8) -: 8] <= 8'h39) begin
          count <= count + 1;
        end
        if (idx == 4'b1111) begin
          state <= IDLE;
          done <= 1'b1;
        end
        idx <= idx + 1;
      end
    endcase
  end
end

endmodule