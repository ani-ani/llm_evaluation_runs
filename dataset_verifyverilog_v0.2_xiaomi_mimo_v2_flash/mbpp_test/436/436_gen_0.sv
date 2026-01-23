module neg_nos (
    input [3:0][7:0] list_in,
    output [3:0][7:0] result,
    output [1:0] count
);

    wire [3:0] is_neg;
    wire [1:0] idx [3:0];

    assign is_neg[0] = list_in[0][7];
    assign is_neg[1] = list_in[1][7];
    assign is_neg[2] = list_in[2][7];
    assign is_neg[3] = list_in[3][7];

    // Compressed indices of negative numbers
    // If k-th input is negative, determine its position in the output array
    // Formula: index = sum of is_neg bits before it
    assign idx[0] = 2'b0;
    assign idx[1] = is_neg[0];
    assign idx[2] = is_neg[0] + is_neg[1];
    assign idx[3] = is_neg[0] + is_neg[1] + is_neg[2];

    // Count output
    assign count = is_neg[0] + is_neg[1] + is_neg[2] + is_neg[3];

    // Output result logic
    // Initialize all to zero
    reg [3:0][7:0] result_reg;
    integer i;

    always @(*) begin
        result_reg = 32'h0;
        for (i = 0; i < 4; i = i + 1) begin
            if (is_neg[i]) begin
                result_reg[idx[i]] = list_in[i];
            end
        end
    end

    assign result = result_reg;

endmodule