module lawsuit_assignment (input clk, input rst_n, input start, input [3:0] lawsuit_index, input [2:0] individual_idx, input [2:0] corporation_idx, output reg [2:0] winner_type, output reg [2:0] winner_id, output reg done, output reg [3:0] max_wins);
 reg [2:0] state;
 reg [3:0] individuals_wins [7:0];
 reg [3:0] corporations_wins [7:0];
 reg [3:0] lawsuit_counter;
 wire [2:0] current_winner_type;
 wire [2:0] current_winner_id;
 localparam IDLE = 3'b000;
 localparam PROCESSING = 3'b001;
 localparam UPDATE = 3'b010;
 localparam DONE = 3'b100;
 always @(*) begin
 current_winner_type = 3'b000;
 current_winner_id = 3'b000;
 if (state == PROCESSING) begin
 if (individuals_wins[individual_idx] < corporations_wins[corporation_idx]) begin
 current_winner_type = 3'b000;
 current_winner_id = individual_idx;
 end else if (individuals_wins[individual_idx] > corporations_wins[corporation_idx]) begin
 current_winner_type = 3'b001;
 current_winner_id = corporation_idx;
 end else begin
 current_winner_type = 3'b000;
 current_winner_id = individual_idx;
 end
 end
 end
 always @(posedge clk) begin
 if (!rst_n) begin
 state <= IDLE;
 lawsuit_counter <= 0;
 individuals_wins <= 0;
 corporations_wins <= 0;
 max_wins <= 0;
 end else begin
 case (state)
 IDLE: begin
 if (start == 1) state <= PROCESSING;
 end
 PROCESSING: begin
 state <= UPDATE;
 end
 UPDATE: begin
 if (current_winner_type == 3'b000) begin
 individuals_wins[current_winner_id] <= individuals_wins[current_winner_id] + 1;
 max_wins <= max(max_wins, individuals_wins[current_winner_id]);
 end else begin
 corporations_wins[current_winner_id] <= corporations_wins[current_winner_id] + 1;
 max_wins <= max(max_wins, corporations_wins[current_winner_id]);
 end
 lawsuit_counter <= lawsuit_counter + 1;
 if (lawsuit_counter == 4'd16) state <= DONE;
 else state <= PROCESSING;
 end
 DONE: begin
 if (start == 1) begin
 state <= IDLE;
 lawsuit_counter <= 0;
 individuals_wins <= 0;
 corporations_wins <= 0;
 max_wins <= 0;
 end
 end
 endcase
 end
 end
 assign winner_type = current_winner_type;
 assign winner_id = current_winner_id + 1;
 assign done = (state == DONE);
 assign max_wins = max_wins;
 endmodule