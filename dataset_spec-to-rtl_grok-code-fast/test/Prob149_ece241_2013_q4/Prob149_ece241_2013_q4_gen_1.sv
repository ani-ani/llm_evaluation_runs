module TopModule (
input clk,
input reset,
input [2:0] s,
output reg fr2,
output reg fr1,
output reg fr0,
output reg dfr
);
reg [2:0] prev_s;
integer prev_level, curr_level;
always @(posedge clk) begin
if (reset) begin
prev_s <= 3'b000;
fr2 <= 1'b1;
fr1 <= 1'b1;
fr0 <= 1'b1;
dfr <= 1'b0;
end else begin
// Set nominal flow rates based on current s
case (s)
3'b111: begin
fr2 <= 1'b0;
fr1 <= 1'b0;
fr0 <= 1'b0;
end
3'b011: begin
fr2 <= 1'b0;
fr1 <= 1'b0;
fr0 <= 1'b1;
end
3'b001: begin
fr2 <= 1'b0;
fr1 <= 1'b1;
fr0 <= 1'b1;
end
3'b000: begin
fr2 <= 1'b1;
fr1 <= 1'b1;
fr0 <= 1'b1;
end
default: begin
fr2 <= 1'b0;
fr1 <= 1'b0;
fr0 <= 1'b0;
end
endcase
// Determine current and previous levels
curr_level = (s == 3'b111) ? 4 : (s == 3'b011) ? 3 : (s == 3'b001) ? 2 : 1;
prev_level = (prev_s == 3'b111) ? 4 : (prev_s == 3'b011) ? 3 : (prev_s == 3'b001) ? 2 : 1;
// Set dfr if between sensors and rising
dfr <= ((curr_level > 1) && (curr_level < 4) && (curr_level > prev_level));
// Update prev_s
prev_s <= s;
end
end
endmodule