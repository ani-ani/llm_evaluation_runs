module tuple_length_checker (
input [3:0] valid_tuples_count,
input [3:0] tuple_lengths [0:3],
output reg equal
);
always @(*) begin
if (valid_tuples_count <= 1) begin
equal = 1'b1;
end else begin
equal = 1'b1;
if (tuple_lengths[1] != tuple_lengths[0]) begin
equal = 1'b0;
end
if (valid_tuples_count > 2) begin
if (tuple_lengths[2] != tuple_lengths[0]) begin
equal = 1'b0;
end
end
if (valid_tuples_count > 3) begin
if (tuple_lengths[3] != tuple_lengths[0]) begin
equal = 1'b0;
end
end
end
end
endmodule