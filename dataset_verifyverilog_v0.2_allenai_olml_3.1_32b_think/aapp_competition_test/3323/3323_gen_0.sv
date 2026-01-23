module drink_satisfaction(input [7:0][15:0] req_A, input [7:0][15:0] req_B, input [7:0][15:0] req_C, input [2:0] num_people, output reg [3:0] max_satisfied);
wire [7:0] active;
assign active[0] = num_people > 0 ? 1'b1 : 1'b0;
assign active[1] = num_people > 1 ? 1'b1 : 1'b0;
assign active[2] = num_people > 2 ? 1'b1 : 1'b0;
assign active[3] = num_people > 3 ? 1'b1 : 1'b0;
assign active[4] = num_people > 4 ? 1'b1 : 1'b0;
assign active[5] = num_people > 5 ? 1'b1 : 1'b0;
assign active[6] = num_people > 6 ? 1'b1 : 1'b0;
assign active[7] = num_people > 7 ? 1'b1 : 1'b0;

assign max_satisfied = 0;

genvar m;
generate
for (m=0; m<256; m++) begin: mask_loop
  wire [3:0] count_m;
  wire [31:0] total_sum_m;
  assign count_m = 0;
  assign total_sum_m = 0;
  int i;
  for (i=0; i<8; i++) begin
    if (active[i] && (m >> i & 1)) begin
      count_m = count_m + 1;
      total_sum_m = total_sum_m + req_A[i] + req_B[i] + req_C[i];
    end
  end

  wire feasible_m = total_sum_m <= 0x00010000;
  wire [3:0] candidate_m = feasible_m ? count_m : 4'd0;
  if (candidate_m > max_satisfied) max_satisfied = candidate_m;
end
endgenerate
endmodule