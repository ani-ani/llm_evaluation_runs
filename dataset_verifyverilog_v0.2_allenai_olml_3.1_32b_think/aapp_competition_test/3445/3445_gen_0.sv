module courier_partition (
input clk,
input rst_n,
input start,
input [2:0] num_customers,
input [9:0] customer_x [0:7],
input [9:0] customer_y [0:7],
output reg [9:0] min_max_diameter,
output reg done
);

reg [2:0] state_reg;
reg [7:0] current_partition;
reg [9:0] min_max_diameter_reg;
reg [2:0] i_counter;
reg [2:0] j_counter;
reg [10:0] max_diam1;
reg [10:0] max_diam2;
reg [2:0] group1_count;
reg [2:0] group2_count;
reg [2:0] state_next;

parameter IDLE = 3'd0;
parameter INIT_PARTITION = 3'd1;
parameter COMPUTE_DIAMETER_1 = 3'd2;
parameter COMPUTE_DIAMETER_2 = 3'd3;
parameter UPDATE_MIN = 3'd4;
parameter NEXT_PARTITION = 3'd5;
parameter DONE = 3'd6;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state_reg <= IDLE;
current_partition <= 0;
min_max_diameter_reg <= 2048;
i_counter <= 0;
j_counter <= 0;
max_diam1 <= 0;
max_diam2 <= 0;
group1_count <= 0;
group2_count <= 0;
state_next <= IDLE;
end else begin
state_reg <= state_next;
case (state_reg)
IDLE: begin
if (start) state_next = INIT_PARTITION; 
else state_next = IDLE;
end
INIT_PARTITION: begin
localparam total_partitions = 256; // assuming num_customers=8
current_partition <= 0;
state_next = NEXT_PARTITION;
end
NEXT_PARTITION: begin
if (current_partition >= total_partitions) begin
state_next = DONE;
done <= 1'b1;
end else begin
group1_count <= 0;
if (num_customers > 0 && (current_partition & 1)) group1_count++;
if (num_customers > 1 && (current_partition & 2)) group1_count++;
if (num_customers > 2 && (current_partition & 4)) group1_count++;
if (num_customers > 3 && (current_partition & 8)) group1_count++;
if (num_customers > 4 && (current_partition & 16)) group1_count++;
if (num_customers > 5 && (current_partition & 32)) group1_count++;
if (num_customers > 6 && (current_partition & 64)) group1_count++;
if (num_customers > 7 && (current_partition & 128)) group1_count++;
group2_count <= num_customers - group1_count;
if (group1_count >= 2 || group2_count >= 2) begin
state_next = COMPUTE_DIAMETER_1;
i_counter <= 0;
j_counter <= 0;
max_diam1 <= 0;
end else begin
state_next = UPDATE_MIN;
end
end
end
COMPUTE_DIAMETER_1: begin
if (i_counter < num_customers) begin
i_counter <= i_counter + 1;
state_next = COMPUTE_DIAMETER_1;
end else begin
state_next = COMPUTE_DIAMETER_2;
end
end
COMPUTE_DIAMETER_2: state_next = UPDATE_MIN;
UPDATE_MIN: begin
state_next = NEXT_PARTITION;
end
default: state_next = IDLE;
endcase
end
end

assign min_max_diameter = min_max_diameter_reg[9:0];
assign done = (state_reg == DONE);

endmodule