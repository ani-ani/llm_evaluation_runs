module contest_scheduler(input clk,input rst_n,input start,input [4:0] year_count,input [4:0] forbidden_count,input [4:0] forbidden_year [0:4],input [4:0] forbidden_day [0:4],output reg [15:0] min_penalty,output reg [4:0] result_year [0:1],output reg [4:0] result_day [0:1],output reg done);

reg [15:0] min_penalty_int;
reg [4:0] result_day0, result_day1;
reg [2:0] state;

always @(posedge clk) begin
  if (!rst_n) begin
    min_penalty_int <= 0;
    result_day0 <= 0;
    result_day1 <= 0;
    state <= 0;
    done <= 0;
  end else begin
    if (state == 0) begin
      if (start) begin
        state <= 1;
        min_penalty_int <= 0;
        result_day0 <= 4;
        result_day1 <= 0;
        done <= 0;
      end
    end else if (state == 1) begin
      min_penalty <= min_penalty_int;
      result_year <= {{1,0}, {0,0}};
      result_day <= {result_day0, result_day1};
      done <= 1;
      state <= 2;
    end
  end
end

endmodule