module virus_spread (input clk, input rst_n, input start, input [7:0] init_infected, input [3:0] D, input [7:0][3:0] p_start_t, input [7:0][3:0] p_end_t, output reg [7:0] infected_status, output reg done);
localparam IDLE = 3'd0, SIMULATING = 3'd1, DONE = 3'd2;
reg [7:0] current_infected;
reg [3:0] days_count;
reg [2:0] state;
wire [15:0] time_mask[8];
wire [7:0][7:0] contact;
wire [7:0] infected_others_contact;
wire [7:0] new_infections;
generate
for (int i=0; i<8; i++) begin
wire [15:0] tm;
assign tm = 16'b0;
for (int t=0; t<16; t++) begin
assign tm[t] = (p_start_t[i] <= t) && (t <= p_end_t[i]);
end
endgenerate
generate
for (int i=0; i<8; i++) begin
for (int j=0; j<8; j++) begin
contact[i][j] = (time_mask[i] & time_mask[j]) != 0 ? 1'b1 : 1'b0;
end
endgenerate
generate
for (int k=0; k<8; k++) begin
infected_others_contact[k] = current_infected[0] & contact[0][k] | current_infected[1] & contact[1][k] | current_infected[2] & contact[2][k] | current_infected[3] & contact[3][k] | current_infected[4] & contact[4][k] | current_infected[5] & contact[5][k] | current_infected[6] & contact[6][k] | current_infected[7] & contact[7][k];
end
endgenerate
assign new_infections = infected_others_contact & ~current_infected;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
current_infected <= 8'b0;
days_count <= 4'd0;
state <= IDLE;
infected_status <= 8'b0;
done <= 1'b0;
end else begin
if (state == IDLE) begin
if (start) begin
current_infected <= init_infected;
days_count <= 4'd0;
state <= SIMULATING;
end
end else if (state == SIMULATING) begin
if (days_count < D) begin
current_infected <= current_infected | new_infections;
days_count <= days_count + 1;
end else begin
state <= DONE;
infected_status <= current_infected;
done <= 1'b1;
end
end
end
end
endmodule