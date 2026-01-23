module surgery_solver (
 input clk,
 input rst_n, // Active-low reset
 input start,
 input [5:0] grid_in,
 output reg [2:0] move_out,
 output reg move_valid,
 output reg done
);
reg [1:0] state;
reg [2:0] blank_pos;
reg [3:0] count;
always @(*) begin
 blank_pos = 0;
 if (grid_in[0] == 0) blank_pos = 0;
 else if (grid_in[1] == 0) blank_pos = 1;
 else if (grid_in[2] == 0) blank_pos = 2;
 else if (grid_in[3] == 0) blank_pos = 3;
 else if (grid_in[4] == 0) blank_pos = 4;
 else if (grid_in[5] == 0) blank_pos = 5;
end
always @(*) begin
 count = 0;
 if (grid_in[0] != 0) begin
 if (grid_in[1] != 0 && grid_in[0] > grid_in[1]) count = count + 1;
 if (grid_in[2] != 0 && grid_in[0] > grid_in[2]) count = count + 1;
 if (grid_in[3] != 0 && grid_in[0] > grid_in[3]) count = count + 1;
 if (grid_in[4] != 0 && grid_in[0] > grid_in[4]) count = count + 1;
 if (grid_in[5] != 0 && grid_in[0] > grid_in[5]) count = count + 1;
 end
 if (grid_in[1] != 0) begin
 if (grid_in[2] != 0 && grid_in[1] > grid_in[2]) count = count + 1;
 if (grid_in[3] != 0 && grid_in[1] > grid_in[3]) count = count + 1;
 if (grid_in[4] != 0 && grid_in[1] > grid_in[4]) count = count + 1;
 if (grid_in[5] != 0 && grid_in[1] > grid_in[5]) count = count + 1;
 end
 if (grid_in[2] != 0) begin
 if (grid_in[3] != 0 && grid_in[2] > grid_in[3]) count = count + 1;
 if (grid_in[4] != 0 && grid_in[2] > grid_in[4]) count = count + 1;
 if (grid_in[5] != 0 && grid_in[2] > grid_in[5]) count = count + 1;
 end
 if (grid_in[3] != 0) begin
 if (grid_in[4] != 0 && grid_in[3] > grid_in[4]) count = count + 1;
 if (grid_in[5] != 0 && grid_in[3] > grid_in[5]) count = count + 1;
 end
 if (grid_in[4] != 0) begin
 if (grid_in[5] != 0 && grid_in[4] > grid_in[5]) count = count + 1;
 end
end
wire solvable = (count % 2 == 0);
wire target_met = (grid_in[0] == 1 && grid_in[1] == 2 && grid_in[2] == 3 && grid_in[3] == 4 && grid_in[4] == 5 && grid_in[5] == 6);
reg [2:0] temp_move_out;
reg temp_move_valid;
always @(*) begin
 temp_move_out = 3'b000;
 temp_move_valid = 0;
 if (blank_pos >= 3) begin // up valid
 temp_move_out = 3'b001;
 temp_move_valid = 1;
 end else if (blank_pos < 3) begin // down valid
 temp_move_out = 3'b010;
 temp_move_valid = 1;
 end else if (blank_pos % 3 != 0) begin // left valid
 temp_move_out = 3'b011;
 temp_move_valid = 1;
 end else if (blank_pos % 3 != 2) begin // right valid
 temp_move_out = 3'b100;
 temp_move_valid = 1;
 end
end
always @(posedge clk or negedge rst_n) begin
 if (!rst_n) begin
 state <= 2'b00; // IDLE
 end else begin
 if (state == 2'b00) begin // IDLE
 if (start)
 state <= 2'b01; // SOLVE
 end else if (state == 2'b01) begin // SOLVE
 if (target_met || !solvable)
 state <= 2'b10; // DONE
 end
 end
end
assign done = (state == 2'b10);
always @(*) begin
 move_out = 3'b000;
 move_valid = 0;
 if (state == 2'b01) begin
 move_out = temp_move_out;
 move_valid = temp_move_valid;
 end
end
endmodule