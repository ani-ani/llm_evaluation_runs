module max_path_average (
 input clk,
 input rst_n,
 input start,
 input [7:0] cost_0_0, cost_0_1, cost_0_2,
 input [7:0] cost_1_0, cost_1_1, cost_1_2,
 input [7:0] cost_2_0, cost_2_1, cost_2_2,
 output reg [31:0] result,
 output reg done
);

 reg [11:0] dp_reg [2][3];
 reg [7:0] cost_reg [2][3];
 reg [3:0] divide_counter;
 reg [2:0] state;
 reg [1:0] row_subcounter;
 reg [31:0] result_reg;
 reg done_reg;

 localparam IDLE = 3'b000,
 ROW0 = 3'b001,
 ROW1 = 3'b010,
 ROW2 = 3'b011,
 DIVIDE = 3'b100,
 DONE = 3'b111;

 always @(posedge clk) begin
 if (!rst_n) begin
 state <= IDLE;
 row_subcounter <= 2'b00;
 divide_counter <= 4'b0000;
 dp_reg[0][0] <= 12'b0;
 dp_reg[0][1] <= 12'b0;
 dp_reg[0][2] <= 12'b0;
 dp_reg[1][0] <= 12'b0;
 dp_reg[1][1] <= 12'b0;
 dp_reg[1][2] <= 12'b0;
 cost_reg[0][0] <= 8'b0;
 cost_reg[0][1] <= 8'b0;
 cost_reg[0][2] <= 8'b0;
 cost_reg[1][0] <= 8'b0;
 cost_reg[1][1] <= 8'b0;
 cost_reg[1][2] <= 8'b0;
 cost_reg[2][0] <= 8'b0;
 cost_reg[2][1] <= 8'b0;
 cost_reg[2][2] <= 8'b0;
 result_reg <= 32'b0;
 done_reg <= 1'b0;
 end else begin
 if (state == IDLE) begin
 if (start) begin
 cost_reg[0][0] <= cost_0_0;
 cost_reg[0][1] <= cost_0_1;
 cost_reg[0][2] <= cost_0_2;
 cost_reg[1][0] <= cost_1_0;
 cost_reg[1][1] <= cost_1_1;
 cost_reg[1][2] <= cost_1_2;
 cost_reg[2][0] <= cost_2_0;
 cost_reg[2][1] <= cost_2_1;
 cost_reg[2][2] <= cost_2_2;
 state <= ROW0;
 row_subcounter <= 2'b00;
 end
 end
 else if (state == ROW0) begin
 if (row_subcounter == 2'b00) begin
 dp_reg[0][0] <= cost_reg[0][0];
 end else if (row_subcounter == 2'b01) begin
 dp_reg[0][1] <= dp_reg[0][0] + cost_reg[0][1];
 end else if (row_subcounter == 2'b10) begin
 dp_reg[0][2] <= dp_reg[0][1] + cost_reg[0][2];
 end
 if (row_subcounter == 2'b10) begin
 state <= ROW1;
 row_subcounter <= 2'b00;
 end
 end
 else if (state == ROW1) begin
 if (row_subcounter == 2'b00) begin
 dp_reg[1][0] <= dp_reg[0][0] + cost_reg[1][0];
 end else if (row_subcounter == 2'b01) begin
 dp_reg[1][1] <= max(dp_reg[0][1], dp_reg[1][0]) + cost_reg[1][1];
 end else if (row_subcounter == 2'b10) begin
 dp_reg[1][2] <= max(dp_reg[0][2], dp_reg[1][1]) + cost_reg[1][2];
 end
 if (row_subcounter == 2'b10) begin
 state <= ROW2;
 row_subcounter <= 2'b00;
 end
 end
 else if (state == ROW2) begin
 if (row_subcounter == 2'b00) begin
 dp_reg[2][0] <= dp_reg[1][0] + cost_reg[2][0];
 end else if (row_subcounter == 2'b01) begin
 dp_reg[2][1] <= max(dp_reg[1][1], dp_reg[2][0]) + cost_reg[2][1];
 end else if (row_subcounter == 2'b10) begin
 dp_reg[2][2] <= max(dp_reg[1][2], dp_reg[2][1]) + cost_reg[2][2];
 state <= DIVIDE;
 row_subcounter <= 2'b00;
 divide_counter <= 4'b0000;
 done_reg <= 1'b1;
 end
 if (row_subcounter < 2'b10) begin
 row_subcounter <= row_subcounter + 1;
 end
 end
 else if (state == DIVIDE) begin
 if (divide_counter < 4'd10) begin
 divide_counter <= divide_counter + 1;
 end else begin
 result_reg <= (dp_reg[2][2] << 16) / 5;
 state <= DONE;
 divide_counter <= 4'b0000;
 end
 end
 end
 end

 assign result = result_reg;
 assign done = done_reg;

 endmodule