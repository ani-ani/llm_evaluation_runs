module big_diff(input [7:0] nums [0:7], output [7:0] diff);
assign max0_1 = nums[0] > nums[1] ? nums[0] : nums[1];
assign max2_3 = nums[2] > nums[3] ? nums[2] : nums[3];
assign max4_5 = nums[4] > nums[5] ? nums[4] : nums[5];
assign max6_7 = nums[6] > nums[7] ? nums[6] : nums[7];
assign max04 = max0_1 > max2_3 ? max0_1 : max2_3;
assign max56 = max4_5 > max6_7 ? max4_5 : max6_7;
assign final_max = max04 > max56 ? max04 : max56;
assign min0_1 = nums[0] < nums[1] ? nums[0] : nums[1];
assign min2_3 = nums[2] < nums[3] ? nums[2] : nums[3];
assign min4_5 = nums[4] < nums[5] ? nums[4] : nums[5];
assign min6_7 = nums[6] < nums[7] ? nums[6] : nums[7];
assign min04 = min0_1 < min2_3 ? min0_1 : min2_3;
assign min56 = min4_5 < min6_7 ? min4_5 : min6_7;
assign final_min = min04 < min56 ? min04 : min56;
assign diff = final_max - final_min;
endmodule