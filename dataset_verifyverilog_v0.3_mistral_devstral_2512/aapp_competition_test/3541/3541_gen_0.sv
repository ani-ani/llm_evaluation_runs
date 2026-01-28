module CandySplitter #(
    parameter N = 4,
    parameter VAL_BITS = 3
)(
    input wire signed [VAL_BITS-1:0] a_0, a_1, a_2, a_3,
    input wire signed [VAL_BITS-1:0] b_0, b_1, b_2, b_3,
    output wire [N-1:0] assignment
);

    reg [N-1:0] best_assignment;
    reg [VAL_BITS:0] min_diff;
    integer i;

    always @(*) begin
        min_diff = {1'b1, {(VAL_BITS){1'b1}}};
        best_assignment = {N{1'b0}};

        for (i = 0; i < 16; i = i + 1) begin
            reg [VAL_BITS:0] sum_a;
            reg [VAL_BITS:0] sum_b;
            reg [VAL_BITS:0] current_diff;
            reg [N-1:0] current_assignment;

            current_assignment = i;

            sum_a = 0;
            sum_b = 0;

            if (current_assignment[0]) sum_a = sum_a + a_0; else sum_b = sum_b + b_0;
            if (current_assignment[1]) sum_a = sum_a + a_1; else sum_b = sum_b + b_1;
            if (current_assignment[2]) sum_a = sum_a + a_2; else sum_b = sum_b + b_2;
            if (current_assignment[3]) sum_a = sum_a + a_3; else sum_b = sum_b + b_3;

            current_diff = (sum_a > sum_b) ? (sum_a - sum_b) : (sum_b - sum_a);

            if (current_diff < min_diff || (current_diff == min_diff && current_assignment > best_assignment)) begin
                min_diff = current_diff;
                best_assignment = current_assignment;
            end
        end

        assignment = best_assignment;
    end

endmodule