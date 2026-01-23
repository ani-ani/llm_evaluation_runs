module triples_sum_to_zero (
    input [3:0] num0,
    input [3:0] num1,
    input [3:0] num2,
    input [3:0] num3,
    input [3:0] num4,
    input [3:0] num5,
    input [3:0] num6,
    input [3:0] num7,
    input [2:0] count,
    output result
);

    // Define the array of numbers for easier access
    wire signed [3:0] nums [0:7];
    assign nums[0] = num0;
    assign nums[1] = num1;
    assign nums[2] = num2;
    assign nums[3] = num3;
    assign nums[4] = num4;
    assign nums[5] = num5;
    assign nums[6] = num6;
    assign nums[7] = num7;

    // Intermediate signals for each triplet check
    // Using 56 reg/wires for combinations C(8,3) = 56
    wire triplet_found_012, triplet_found_013, triplet_found_014, triplet_found_015, triplet_found_016, triplet_found_017;
    wire triplet_found_023, triplet_found_024, triplet_found_025, triplet_found_026, triplet_found_027;
    wire triplet_found_034, triplet_found_035, triplet_found_036, triplet_found_037;
    wire triplet_found_045, triplet_found_046, triplet_found_047;
    wire triplet_found_056, triplet_found_057;
    wire triplet_found_067;
    
    wire triplet_found_123, triplet_found_124, triplet_found_125, triplet_found_126, triplet_found_127;
    wire triplet_found_134, triplet_found_135, triplet_found_136, triplet_found_137;
    wire triplet_found_145, triplet_found_146, triplet_found_147;
    wire triplet_found_156, triplet_found_157;
    wire triplet_found_167;
    
    wire triplet_found_234, triplet_found_235, triplet_found_236, triplet_found_237;
    wire triplet_found_245, triplet_found_246, triplet_found_247;
    wire triplet_found_256, triplet_found_257;
    wire triplet_found_267;
    
    wire triplet_found_345, triplet_found_346, triplet_found_347;
    wire triplet_found_356, triplet_found_357;
    wire triplet_found_367;
    
    wire triplet_found_456, triplet_found_457;
    wire triplet_found_467;
    
    wire triplet_found_567;

    // Check indices against count
    // Valid if index < count. Since count is 3 bits, valid indices are 0-7.
    // We check validity by comparing index (constant) with count (input).
    // Example: index 0 is valid if count > 0, which is always true for non-zero count.
    // However, if count is 0, no indices are valid. count > 0 implies index 0 valid.
    // count > 1 implies index 1 valid. count > 2 implies index 2 valid.
    // count > 7 implies index 7 valid. 
    // In Verilog (unsigned comparison): i < count.
    // 0 < count is true if count != 0. 
    // Let's use: valid[i] = (count > i).

    // Function to check a triplet
    // It sums them and checks if sum == 0
    // Only valid if all three indices < count
    
    // Group 1: Triplets containing index 0
    assign triplet_found_012 = (count > 2) ? ((nums[0] + nums[1] + nums[2]) == 0) : 0;
    assign triplet_found_013 = (count > 3) ? ((nums[0] + nums[1] + nums[3]) == 0) : 0;
    assign triplet_found_014 = (count > 4) ? ((nums[0] + nums[1] + nums[4]) == 0) : 0;
    assign triplet_found_015 = (count > 5) ? ((nums[0] + nums[1] + nums[5]) == 0) : 0;
    assign triplet_found_016 = (count > 6) ? ((nums[0] + nums[1] + nums[6]) == 0) : 0;
    assign triplet_found_017 = (count > 7) ? ((nums[0] + nums[1] + nums[7]) == 0) : 0;
    assign triplet_found_023 = (count > 3) ? ((nums[0] + nums[2] + nums[3]) == 0) : 0;
    assign triplet_found_024 = (count > 4) ? ((nums[0] + nums[2] + nums[4]) == 0) : 0;
    assign triplet_found_025 = (count > 5) ? ((nums[0] + nums[2] + nums[5]) == 0) : 0;
    assign triplet_found_026 = (count > 6) ? ((nums[0] + nums[2] + nums[6]) == 0) : 0;
    assign triplet_found_027 = (count > 7) ? ((nums[0] + nums[2] + nums[7]) == 0) : 0;
    assign triplet_found_034 = (count > 4) ? ((nums[0] + nums[3] + nums[4]) == 0) : 0;
    assign triplet_found_035 = (count > 5) ? ((nums[0] + nums[3] + nums[5]) == 0) : 0;
    assign triplet_found_036 = (count > 6) ? ((nums[0] + nums[3] + nums[6]) == 0) : 0;
    assign triplet_found_037 = (count > 7) ? ((nums[0] + nums[3] + nums[7]) == 0) : 0;
    assign triplet_found_045 = (count > 5) ? ((nums[0] + nums[4] + nums[5]) == 0) : 0;
    assign triplet_found_046 = (count > 6) ? ((nums[0] + nums[4] + nums[6]) == 0) : 0;
    assign triplet_found_047 = (count > 7) ? ((nums[0] + nums[4] + nums[7]) == 0) : 0;
    assign triplet_found_056 = (count > 6) ? ((nums[0] + nums[5] + nums[6]) == 0) : 0;
    assign triplet_found_057 = (count > 7) ? ((nums[0] + nums[5] + nums[7]) == 0) : 0;
    assign triplet_found_067 = (count > 7) ? ((nums[0] + nums[6] + nums[7]) == 0) : 0;

    // Group 2: Triplets containing index 1 (but not 0)
    // Note: index 1 valid implies count > 1. 
    assign triplet_found_123 = (count > 3) ? ((nums[1] + nums[2] + nums[3]) == 0) : 0;
    assign triplet_found_124 = (count > 4) ? ((nums[1] + nums[2] + nums[4]) == 0) : 0;
    assign triplet_found_125 = (count > 5) ? ((nums[1] + nums[2] + nums[5]) == 0) : 0;
    assign triplet_found_126 = (count > 6) ? ((nums[1] + nums[2] + nums[6]) == 0) : 0;
    assign triplet_found_127 = (count > 7) ? ((nums[1] + nums[2] + nums[7]) == 0) : 0;
    assign triplet_found_134 = (count > 4) ? ((nums[1] + nums[3] + nums[4]) == 0) : 0;
    assign triplet_found_135 = (count > 5) ? ((nums[1] + nums[3] + nums[5]) == 0) : 0;
    assign triplet_found_136 = (count > 6) ? ((nums[1] + nums[3] + nums[6]) == 0) : 0;
    assign triplet_found_137 = (count > 7) ? ((nums[1] + nums[3] + nums[7]) == 0) : 0;
    assign triplet_found_145 = (count > 5) ? ((nums[1] + nums[4] + nums[5]) == 0) : 0;
    assign triplet_found_146 = (count > 6) ? ((nums[1] + nums[4] + nums[6]) == 0) : 0;
    assign triplet_found_147 = (count > 7) ? ((nums[1] + nums[4] + nums[7]) == 0) : 0;
    assign triplet_found_156 = (count > 6) ? ((nums[1] + nums[5] + nums[6]) == 0) : 0;
    assign triplet_found_157 = (count > 7) ? ((nums[1] + nums[5] + nums[7]) == 0) : 0;
    assign triplet_found_167 = (count > 7) ? ((nums[1] + nums[6] + nums[7]) == 0) : 0;

    // Group 3: Triplets containing index 2
    assign triplet_found_234 = (count > 4) ? ((nums[2] + nums[3] + nums[4]) == 0) : 0;
    assign triplet_found_235 = (count > 5) ? ((nums[2] + nums[3] + nums[5]) == 0) : 0;
    assign triplet_found_236 = (count > 6) ? ((nums[2] + nums[3] + nums[6]) == 0) : 0;
    assign triplet_found_237 = (count > 7) ? ((nums[2] + nums[3] + nums[7]) == 0) : 0;
    assign triplet_found_245 = (count > 5) ? ((nums[2] + nums[4] + nums[5]) == 0) : 0;
    assign triplet_found_246 = (count > 6) ? ((nums[2] + nums[4] + nums[6]) == 0) : 0;
    assign triplet_found_247 = (count > 7) ? ((nums[2] + nums[4] + nums[7]) == 0) : 0;
    assign triplet_found_256 = (count > 6) ? ((nums[2] + nums[5] + nums[6]) == 0) : 0;
    assign triplet_found_257 = (count > 7) ? ((nums[2] + nums[5] + nums[7]) == 0) : 0;
    assign triplet_found_267 = (count > 7) ? ((nums[2] + nums[6] + nums[7]) == 0) : 0;

    // Group 4: Triplets containing index 3
    assign triplet_found_345 = (count > 5) ? ((nums[3] + nums[4] + nums[5]) == 0) : 0;
    assign triplet_found_346 = (count > 6) ? ((nums[3] + nums[4] + nums[6]) == 0) : 0;
    assign triplet_found_347 = (count > 7) ? ((nums[3] + nums[4] + nums[7]) == 0) : 0;
    assign triplet_found_356 = (count > 6) ? ((nums[3] + nums[5] + nums[6]) == 0) : 0;
    assign triplet_found_357 = (count > 7) ? ((nums[3] + nums[5] + nums[7]) == 0) : 0;
    assign triplet_found_367 = (count > 7) ? ((nums[3] + nums[6] + nums[7]) == 0) : 0;

    // Group 5: Triplets containing index 4
    assign triplet_found_456 = (count > 6) ? ((nums[4] + nums[5] + nums[6]) == 0) : 0;
    assign triplet_found_457 = (count > 7) ? ((nums[4] + nums[5] + nums[7]) == 0) : 0;
    assign triplet_found_467 = (count > 7) ? ((nums[4] + nums[6] + nums[7]) == 0) : 0;

    // Group 6: Triplets containing index 5
    assign triplet_found_567 = (count > 7) ? ((nums[5] + nums[6] + nums[7]) == 0) : 0;

    // Finally, OR all valid triplet checks together
    // If count < 3, all the conditions (count > x) inside the assignments will be false,
    // resulting in 0 from all assignments. So the OR will be 0.
    assign result = |{
        triplet_found_012, triplet_found_013, triplet_found_014, triplet_found_015, triplet_found_016, triplet_found_017,
        triplet_found_023, triplet_found_024, triplet_found_025, triplet_found_026, triplet_found_027,
        triplet_found_034, triplet_found_035, triplet_found_036, triplet_found_037,
        triplet_found_045, triplet_found_046, triplet_found_047,
        triplet_found_056, triplet_found_057,
        triplet_found_067,
        triplet_found_123, triplet_found_124, triplet_found_125, triplet_found_126, triplet_found_127,
        triplet_found_134, triplet_found_135, triplet_found_136, triplet_found_137,
        triplet_found_145, triplet_found_146, triplet_found_147,
        triplet_found_156, triplet_found_157,
        triplet_found_167,
        triplet_found_234, triplet_found_235, triplet_found_236, triplet_found_237,
        triplet_found_245, triplet_found_246, triplet_found_247,
        triplet_found_256, triplet_found_257,
        triplet_found_267,
        triplet_found_345, triplet_found_346, triplet_found_347,
        triplet_found_356, triplet_found_357,
        triplet_found_367,
        triplet_found_456, triplet_found_457,
        triplet_found_467,
        triplet_found_567
    };

endmodule