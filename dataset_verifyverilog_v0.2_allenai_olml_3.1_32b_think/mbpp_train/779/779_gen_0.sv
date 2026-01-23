module unique_sublists_counter (
  input [7:0] sublists [0:7][0:3],
  input [2:0] valid_count,
  output [31:0] unique_ids [0:7],
  output [3:0] counts [0:7],
  output [2:0] unique_count
);

  assign id_0 = {sublists[0][0], sublists[0][1], sublists[0][2], sublists[0][3]};
  assign id_1 = {sublists[1][0], sublists[1][1], sublists[1][2], sublists[1][3]};
  assign id_2 = {sublists[2][0], sublists[2][1], sublists[2][2], sublists[2][3]};
  assign id_3 = {sublists[3][0], sublists[3][1], sublists[3][2], sublists[3][3]};
  assign id_4 = {sublists[4][0], sublists[4][1], sublists[4][2], sublists[4][3]};
  assign id_5 = {sublists[5][0], sublists[5][1], sublists[5][2], sublists[5][3]};
  assign id_6 = {sublists[6][0], sublists[6][1], sublists[6][2], sublists[6][3]};
  assign id_7 = {sublists[7][0], sublists[7][1], sublists[7][2], sublists[7][3]};

  wire [0:7] is_valid_i;
  assign is_valid_i[0] = valid_count > 0 ? 1'b1 : 1'b0;
  assign is_valid_i[1] = valid_count > 1 ? 1'b1 : 1'b0;
  assign is_valid_i[2] = valid_count > 2 ? 1'b1 : 1'b0;
  assign is_valid_i[3] = valid_count > 3 ? 1'b1 : 1'b0;
  assign is_valid_i[4] = valid_count > 4 ? 1'b1 : 1'b0;
  assign is_valid_i[5] = valid_count > 5 ? 1'b1 : 1'b0;
  assign is_valid_i[6] = valid_count > 6 ? 1'b1 : 1'b0;
  assign is_valid_i[7] = valid_count > 7 ? 1'b1 : 1'b0;

  wire [0:7] is_new_i;
  assign is_new_i[0] = is_valid_i[0];
  assign is_new_i[1] = is_valid_i[1] & ((~is_valid_i[0]) | (id_1 != id_0));
  assign is_new_i[2] = is_valid_i[2] & ((~is_valid_i[0] | id_2 != id_0) & (~is_valid_i[1] | id_2 != id_1));
  assign is_new_i[3] = is_valid_i[3] & ((~is_valid_i[0] | id_3 != id_0) & (~is_valid_i[1] | id_3 != id_1) & (~is_valid_i[2] | id_3 != id_2));
  assign is_new_i[4] = is_valid_i[4] & ((~is_valid_i[0] | id_4 != id_0) & (~is_valid_i[1] | id_4 != id_1) & (~is_valid_i[2] | id_4 != id_2) & (~is_valid_i[3] | id_4 != id_3));
  assign is_new_i[5] = is_valid_i[5] & ((~is_valid_i[0] | id_5 != id_0) & (~is_valid_i[1] | id_5 != id_1) & (~is_valid_i[2] | id_5 != id_2) & (~is_valid_i[3] | id_5 != id_3));
  assign is_new_i[6] = is_valid_i[6] & ((~is_valid_i[0] | id_6 != id_0) & (~is_valid_i[1] | id_6 != id_1) & (~is_valid_i[2] | id_6 != id_2) & (~is_valid_i[3] | id_6 != id_3) & (~is_valid_i[4] | id_6 != id_4));
  assign is_new_i[7] = is_valid_i[7] & ((~is_valid_i[0] | id_7 != id_0) & (~is_valid_i[1] | id_7 != id_1) & (~is_valid_i[2] | id_7 != id_2) & (~is_valid_i[3] | id_7 != id_3) & (~is_valid_i[4] | id_7 != id_4) & (~is_valid_i[5] | id_7 != id_5));

  integer i;
  always @(*) begin
    unique_count = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (is_new_i[i]) begin
        unique_count = unique_count + 1;
        unique_ids[i] = id_i;
        counts[i] = counts[i] + 1;
      end
    end
  end
endmodule