module list_difference (
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    output [7:0] difference [0:15]
);

wire [1:0] candidate1 [0:7];
wire [1:0] present_in_list2 [0:7];
generate
  for (int i=0; i<8; i++) begin: candidate1_gen
    wire x = list1[i];
    assign present_in_list2[i] = 1'b0;
    generate
      for (int j=0; j<8; j++) begin: list2_check
        if (list2[j] != 8'hFF) begin
          if (list2[j] == x) begin
            present_in_list2[i] = 1'b1;
          end
        end
      end
    endgenerate
    assign candidate1[i] = (x != 8'hFF) && !present_in_list2[i];
  end
endgenerate

wire [1:0] candidate2 [0:7];
wire [1:0] present_in_list1 [0:7];
generate
  for (int i=0; i<8; i++) begin: candidate2_gen
    wire x = list2[i];
    assign present_in_list1[i] = 1'b0;
    generate
      for (int j=0; j<8; j++) begin: list1_check
        if (list1[j] != 8'hFF) begin
          if (list1[j] == x) begin
            present_in_list1[i] = 1'b1;
          end
        end
      end
    endgenerate
    assign candidate2[i] = (x != 8'hFF) && !present_in_list1[i];
  end
endgenerate

wire [1:0] include1 [0:7];
assign include1[0] = candidate1[0];
assign include1[1] = candidate1[1] & ! (candidate1[0] & (list1[0] == list1[1]));
assign include1[2] = candidate1[2] & ! ( (candidate1[0] & (list1[0] == list1[2])) | (candidate1[1] & (list1[1] == list1[2])) );
assign include1[3] = candidate1[3] & ! ( (candidate1[0] & (list1[0] == list1[3])) | (candidate1[1] & (list1[1] == list1[3])) | (candidate1[2] & (list1[2] == list1[3])) );
assign include1[4] = candidate1[4] & ! ( (candidate1[0] & (list1[0] == list1[4])) | (candidate1[1] & (list1[1] == list1[4])) | (candidate1[2] & (list1[2] == list1[4])) | (candidate1[3] & (list1[3] == list1[4])) );
assign include1[5] = candidate1[5] & ! ( (candidate1[0] & (list1[0] == list1[5])) | (candidate1[1] & (list1[1] == list1[5])) | (candidate1[2] & (list1[2] == list1[5])) | (candidate1[3] & (list1[3] == list1[5])) | (candidate1[4] & (list1[4] == list1[5])) );
assign include1[6] = candidate1[6] & ! ( (candidate1[0] & (list1[0] == list1[6])) | (candidate1[1] & (list1[1] == list1[6])) | (candidate1[2] & (list1[2] == list1[6])) | (candidate1[3] & (list1[3] == list1[6])) | (candidate1[4] & (list1[4] == list1[6])) | (candidate1[5] & (list1[5] == list1[6])) );
assign include1[7] = candidate1[7] & ! ( (candidate1[0] & (list1[0] == list1[7])) | (candidate1[1] & (list1[1] == list1[7])) | (candidate1[2] & (list1[2] == list1[7])) | (candidate1[3] & (list1[3] == list1[7])) | (candidate1[4] & (list1[4] == list1[7])) | (candidate1[5] & (list1[5] == list1[7])) | (candidate1[6] & (list1[6] == list1[7])) );

wire [1:0] include2 [0:7];
assign include2[0] = candidate2[0];
assign include2[1] = candidate2[1] & ! (candidate2[0] & (list2[0] == list2[1]));
assign include2[2] = candidate2[2] & ! ( (candidate2[0] & (list2[0] == list2[2])) | (candidate2[1] & (list2[1] == list2[2])) );
assign include2[3] = candidate2[3] & ! ( (candidate2[0] & (list2[0] == list2[3])) | (candidate2[1] & (list2[1] == list2[3])) | (candidate2[2] & (list2[2] == list2[3])) );
assign include2[4] = candidate2[4] & ! ( (candidate2[0] & (list2[0] == list2[4])) | (candidate2[1] & (list2[1] == list2[4])) | (candidate2[2] & (list2[2] == list2[4])) | (candidate2[3] & (list2[3] == list2[4])) );
assign include2[5] = candidate2[5] & ! ( (candidate2[0] & (list2[0] == list2[5])) | (candidate2[1] & (list2[1] == list2[5])) | (candidate2[2] & (list2[2] == list2[5])) | (candidate2[3] & (list2[3] == list2[5])) | (candidate2[4] & (list2[4] == list2[5])) );
assign include2[6] = candidate2[6] & ! ( (candidate2[0] & (list2[0] == list2[6])) | (candidate2[1] & (list2[1] == list2[6])) | (candidate2[2] & (list2[2] == list2[6])) | (candidate2[3] & (list2[3] == list2[6])) | (candidate2[4] & (list2[4] == list2[6])) | (candidate2[5] & (list2[5] == list2[6])) );
assign include2[7] = candidate2[7] & ! ( (candidate2[0] & (list2[0] == list2[7])) | (candidate2[1] & (list2[1] == list2[7])) | (candidate2[2] & (list2[2] == list2[7])) | (candidate2[3] & (list2[3] == list2[7])) | (candidate2[4] & (list2[4] == list2[7])) | (candidate2[5] & (list2[5] == list2[7])) | (candidate2[6] & (list2[6] == list2[7])) );

wire [7:0] part1_values [0:7];
wire [7:0] part2_values [0:7];
assign part1_values[0] = include1[0] ? list1[0] : 8'hFF;
assign part1_values[1] = include1[1] ? list1[1] : 8'hFF;
assign part1_values[2] = include1[2] ? list1[2] : 8'hFF;
assign part1_values[3] = include1[3] ? list1[3] : 8'hFF;
assign part1_values[4] = include1[4] ? list1[4] : 8'hFF;
assign part1_values[5] = include1[5] ? list1[5] : 8'hFF;
assign part1_values[6] = include1[6] ? list1[6] : 8'hFF;
assign part1_values[7] = include1[7] ? list1[7] : 8'hFF;

assign part2_values[0] = include2[0] ? list2[0] : 8'hFF;
assign part2_values[1] = include2[1] ? list2[1] : 8'hFF;
assign part2_values[2] = include2[2] ? list2[2] : 8'hFF;
assign part2_values[3] = include2[3] ? list2[3] : 8'hFF;
assign part2_values[4] = include2[4] ? list2[4] : 8'hFF;
assign part2_values[5] = include2[5] ? list2[5] : 8'hFF;
assign part2_values[6] = include2[6] ? list2[6] : 8'hFF;
assign part2_values[7] = include2[7] ? list2[7] : 8'hFF;

assign N1 = include1[0] + include1[1] + include1[2] + include1[3] + include1[4] + include1[5] + include1[6] + include1[7];
assign N2 = include2[0] + include2[1] + include2[2] + include2[3] + include2[4] + include2[5] + include2[6] + include2[7];

assign difference[0] = (0 < N1) ? part1_values[0] : (0 < N1 + N2) ? part2_values[0 - N1] : 8'hFF;
assign difference[1] = (1 < N1) ? part1_values[1] : (1 < N1 + N2) ? part2_values[1 - N1] : 8'hFF;
assign difference[2] = (2 < N1) ? part1_values[2] : (2 < N1 + N2) ? part2_values[2 - N1] : 8'hFF;
assign difference[3] = (3 < N1) ? part1_values[3] : (3 < N1 + N2) ? part2_values[3 - N1] : 8'hFF;
assign difference[4] = (4 < N1) ? part1_values[4] : (4 < N1 + N2) ? part2_values[4 - N1] : 8'hFF;
assign difference[5] = (5 < N1) ? part1_values[5] : (5 < N1 + N2) ? part2_values[5 - N1] : 8'hFF;
assign difference[6] = (6 < N1) ? part1_values[6] : (6 < N1 + N2) ? part2_values[6 - N1] : 8'hFF;
assign difference[7] = (7 < N1) ? part1_values[7] : (7 < N1 + N2) ? part2_values[7 - N1] : 8'hFF;
assign difference[8] = (8 < N1 + N2) ? part2_values[8 - N1] : 8'hFF;
assign difference[9] = (9 < N1 + N2) ? part2_values[9 - N1] : 8'hFF;
assign difference[10] = (10 < N1 + N2) ? part2_values[10 - N1] : 8'hFF;
assign difference[11] = (11 < N1 + N2) ? part2_values[11 - N1] : 8'hFF;
assign difference[12] = (12 < N1 + N2) ? part2_values[12 - N1] : 8'hFF;
assign difference[13] = (13 < N1 + N2) ? part2_values[13 - N1] : 8'hFF;
assign difference[14] = (14 < N1 + N2) ? part2_values[14 - N1] : 8'hFF;
assign difference[15] = (15 < N1 + N2) ? part2_values[15 - N1] : 8'hFF;

endmodule