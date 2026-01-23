module event_duration_solver (
input clk,
input rst_n, // active-low reset
input start,
input [8:0] start_day,
input [8:0] end_day,
input [7:0] F [0:3], // 4 elements of 8 bits each
output reg [8:0] duration [0:3],
output reg done,
output reg valid
);
parameter MAX_SEARCH = 1000;
parameter MAX_COUNT = MAX_SEARCH -1;
localparam IDLE = 3'd0,
SOLVE = 3'd1,
OUTPUT = 3'd2;
reg [31:0] counter;
reg [8:0] obs_window;
reg [8:0] stored_duration [0:3];
reg [2:0] state;
reg [8:0] temp_duration [0:3]; // temporary storage for candidate
always_ff @(posedge clk) begin
if (!rst_n) begin
counter <= 0;
obs_window <= 0;
stored_duration <= 0;
state <= IDLE;
done <=0;
valid <=0;
duration <=0;
end else begin
case(state)
IDLE: begin
if (start) begin
// Calculate observation window
if (end_day >= start_day)
obs_window <= end_day - start_day;
else
obs_window <= end_day + 365 - start_day;
counter <=0;
state <= SOLVE;
end
end
SOLVE: begin
if (counter <= MAX_COUNT) begin
// Generate candidate durations
temp_duration[0] = (counter % 365) + 1;
temp_duration[1] = 1;
temp_duration[2] = 1;
temp_duration[3] = 1;
// Check sum
bit [17:0] total;
total = F[0]*temp_duration[0] + F[1]*temp_duration[1] + F[2]*temp_duration[2] + F[3]*temp_duration[3];
if (total == (bit [17:0]) obs_window) begin
stored_duration <= temp_duration;
valid <=1;
done <=1;
state <= OUTPUT;
end
counter <= counter +1;
end else begin
// Timeout, no solution
valid <=0;
done <=1;
state <= OUTPUT;
counter <=0;
end
end
OUTPUT: begin
duration <= stored_duration;
end
endcase
end
end