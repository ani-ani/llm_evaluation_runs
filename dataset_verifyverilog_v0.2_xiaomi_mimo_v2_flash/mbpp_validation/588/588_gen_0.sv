module big_diff(
    input [7:0] nums [0:7],
    output reg [7:0] diff
);

    integer i;
    reg [7:0] max_val;
    reg [7:0] min_val;

    always @(*) begin
        max_val = nums[0];
        min_val = nums[0];
        
        for (i = 1; i < 8; i = i + 1) begin
            if (nums[i] > max_val) begin
                max_val = nums[i];
            end
            if (nums[i] < min_val) begin
                min_val = nums[i];
            end
        end
        
        diff = max_val - min_val;
    end

endmodule