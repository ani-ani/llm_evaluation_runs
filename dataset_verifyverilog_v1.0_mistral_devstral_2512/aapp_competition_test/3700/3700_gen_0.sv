module ways_to_choose(
    input [63:0] n,
    input [63:0] k,
    output reg [63:0] result
);

    // Internal variables
    reg [63:0] lower_bound;
    reg [63:0] upper_bound;
    reg [63:0] temp;

    always @(*) begin
        // Compute lower_bound = max(1, k - n)
        if (k > n)
            lower_bound = k - n;
        else
            lower_bound = 64'd1;

        // Compute upper_bound = min(n, (k-1)//2)
        temp = (k - 64'd1) >> 1;
        if (temp < n)
            upper_bound = temp;
        else
            upper_bound = n;

        // Compute result = max(0, upper_bound - lower_bound + 1)
        if (lower_bound <= upper_bound)
            result = upper_bound - lower_bound + 64'd1;
        else
            result = 64'd0;
    end

endmodule