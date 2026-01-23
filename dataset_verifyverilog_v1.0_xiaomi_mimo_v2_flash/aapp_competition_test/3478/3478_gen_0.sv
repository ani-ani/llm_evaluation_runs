module graph_partition_4(
    input wire adj13,
    input wire adj14,
    input wire adj23,
    input wire adj24,
    input wire adj34,
    output wire possible,
    output wire [3:0] aryas_set,
    output wire [3:0] sansas_set
);

wire A1_3, A1_4, A2_3, A2_4, A0_3, A0_4;
wire clique_A0, clique_A1, clique_A2;

assign A1_3 = adj13;
assign A1_4 = adj14;
assign A2_3 = adj23 && !adj13;
assign A2_4 = adj24 && !adj14;
assign A0_3 = !adj13 && !adj23;
assign A0_4 = !adj14 && !adj24;

assign clique_A0 = !(A0_3 && A0_4) || adj34;
assign clique_A1 = !(A1_3 && A1_4) || adj34;
assign clique_A2 = !(A2_3 && A2_4) || adj34;

assign possible = clique_A0 && clique_A1 && clique_A2;

assign aryas_set = {A1_4, A1_3, 1'b0, 1'b1};
assign sansas_set = {A2_4, A2_3, 1'b1, 1'b0};

endmodule