module ball_selection(input [5:0] num_balls, input [63:0] ball_presence, output reg result);
wire [61:0] has_triplet;
genvar i;
generate
for (i=0; i<62; i++) begin
has_triplet[i] = ball_presence[i] & ball_presence[i+1] & ball_presence[i+2];
end
endgenerate
assign result = |has_triplet;
endmodule