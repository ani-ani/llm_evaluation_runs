module vertex_cover_solver( input clk, input rst_n, input start, input [9:0] team_stockholm, input [9:0] team_london, input team_valid, input team_done, output reg [4:0] result_count, output reg [9:0] result_ids [0:15], output reg result_valid, output reg done );
reg [1:0] state;
reg [7:0] count;
parameter IDLE = 2'd0, INPUT_TEAMS=2'd1, COMPUTE=2'd2, OUTPUT=2'd3;
always @(posedge clk) if (!rst_n) begin state <= IDLE; count <=8'd0; result_count <=5'd0; result_valid <=1'b0; done <=1'b0; end else begin if (state == IDLE) if (start) state <= INPUT_TEAMS; else if (state == INPUT_TEAMS) if (team_done) state <= COMPUTE; end
always @(posedge clk) if (state == COMPUTE) count <= count +1;
always @(posedge clk) if (state == OUTPUT) result_valid <=1'b1;
done <= result_valid;
endmodule