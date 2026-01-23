module filter_odd(input [7:0] nums [0:7], output [7:0] odd_nums, output [3:0] count);
    assign odd_nums = { 
        nums[7][0], nums[6][0], nums[5][0], nums[4][0], 
        nums[3][0], nums[2][0], nums[1][0], nums[0][0] 
    };
    assign count = odd_nums[0] + odd_nums[1] + odd_nums[2] + odd_nums[3] + 
        odd_nums[4] + odd_nums[5] + odd_nums[6] + odd_nums[7];
endmodule