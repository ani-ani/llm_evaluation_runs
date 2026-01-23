module tower_defense_solver (input clk, input rst_n, input start, input [7:0] village_x [0:3], input [7:0] village_y [0:3], input [3:0] village_r [0:3], input [7:0] minion_x [0:9], input [7:0] minion_y [0:9], input [3:0] n_used, input [4:0] m_used, input [7:0] max_r, output reg [4:0] max_killed, output reg done);
always @(posedge clk) begin
    if (!rst_n) begin
        max_killed <= 0;
        done <=0;
    end
end
assign max_killed = max_killed;
assign done = done;
endmodule