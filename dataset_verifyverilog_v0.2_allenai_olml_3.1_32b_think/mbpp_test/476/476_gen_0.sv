module big_sum (
    input [2:0] array_size,
    input [7:0] signed nums [0:7],
    output reg [7:0] result
);

reg [7:0] min_val, max_val, sum;

always @(*) begin
    if (array_size == 0) begin
        result = 8'b0;
    end else begin
        min_val = nums[0];
        if (array_size >=2) min_val = min(min_val, nums[1]);
        if (array_size >=3) min_val = min(min_val, nums[2]);
        if (array_size >=4) min_val = min(min_val, nums[3]);
        if (array_size >=5) min_val = min(min_val, nums[4]);
        if (array_size >=6) min_val = min(min_val, nums[5]);
        if (array_size >=7) min_val = min(min_val, nums[6]);
        if (array_size ==8) min_val = min(min_val, nums[7]);
        max_val = nums[0];
        if (array_size >=2) max_val = max(max_val, nums[1]);
        if (array_size >=3) max_val = max(max_val, nums[2]);
        if (array_size >=4) max_val = max(max_val, nums[3]);
        if (array_size >=5) max_val = max(max_val, nums[4]);
        if (array_size >=6) max_val = max(max_val, nums[5]);
        if (array_size >=7) max_val = max(max_val, nums[6]);
        if (array_size ==8) max_val = max(max_val, nums[7]);
        sum = min_val + max_val;
        result = sum;
    end
end
endmodule