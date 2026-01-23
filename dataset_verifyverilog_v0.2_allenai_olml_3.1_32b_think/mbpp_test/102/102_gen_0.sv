module snake_to_camel (
input clk,
input rst_n,
input start,
input [7:0] char_in,
input valid_in,
output reg ready,
output reg [7:0] char_out,
output reg valid_out,
output reg done
);

reg [1:0] state;
reg [1:0] no_valid_count;
reg capitalize_next;
reg [7:0] char_out;

localparam IDLE = 2'd0,
PROCESSING = 2'd1,
DONE = 2'd2;

initial begin
state <= IDLE;
o_valid_count <= 2'd0;
capitalize_next <= 1'b0;
done <= 1'b0;
char_out <= 8'h00;
valid_out <= 1'b0;
end

assign ready = (state == PROCESSING) && (no_valid_count < 2);

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
o_valid_count <= 2'd0;
capitalize_next <= 1'b0;
done <= 1'b0;
char_out <= 8'h00;
valid_out <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start == 1'b1) begin
state <= PROCESSING;
capitalize_next <= 1'b1;
o_valid_count <= 2'd0;
done <= 1'b0;
end
end
PROCESSING: begin
if (valid_in == 1'b0) begin
no_valid_count <= no_valid_count + 2'd1;
end else begin
no_valid_count <= 2'd0;
end

if (no_valid_count == 2) begin
state <= DONE;
done <= 1'b1;
end else begin
if (valid_in) begin
if (char_in == 8'h5F) begin
valid_out <= 1'b0;
char_out <= 8'h00;
capitalize_next <= 1'b1;
end else begin
valid_out <= 1'b1;
char_out <= char_in;

if (capitalize_next) begin
if (char_in >= 8'h61 && char_in <= 8'h7a) begin
char_out <= char_in - 8'h20;
capitalize_next <= 1'b0;
end else begin
capitalize_next <= capitalize_next;
end
end else begin
capitalize_next <= capitalize_next;
end
end
end
end
end
DONE: begin
end
endcase
end
end

endmodule