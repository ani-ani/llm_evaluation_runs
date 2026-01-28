module CandySplitter #(
    parameter N = 4,
    parameter VAL_BITS = 3
)(
    input wire signed [VAL_BITS-1:0] a_0, a_1, a_2, a_3,
    input wire signed [VAL_BITS-1:0] b_0, b_1, b_2, b_3,
    output wire [N-1:0] assignment
);
    reg [N-1:0] best_assignment;
    reg [4:0] min_diff;
    integer i;
    reg [3:0] current_assignment;
    reg signed [5:0] alf_sum, beata_sum;
    reg signed [5:0] diff;
    reg [4:0] abs_diff;

    always @(*) begin
        best_assignment = 4'd0;
        min_diff = 5'd31;
        for (i = 0; i < 16; i = i + 1) begin
            current_assignment = i;
            alf_sum = 0;
            beata_sum = 0;

            if (current_assignment[0])
                alf_sum = alf_sum + a_0;
            else
                beata_sum = beata_sum + b_0;

            if (current_assignment[1])
                alf_sum = alf_sum + a_1;
            else
                beata_sum = beata_sum + b_1;

            if (current_assignment[2])
                alf_sum = alf_sum + a_2;
            else
                beata_sum = beata_sum + b_2;

            if (current_assignment[3])
                alf_sum = alf_sum + a_3;
            else
                beata_sum = beata_sum + b_3;

            diff = alf_sum - beata_sum;
            abs_diff = (diff < 0) ? -diff : diff;

            if (abs_diff < min_diff) begin
                min_diff = abs_diff;
                best_assignment = current_assignment;
            end
        end
    end

    assign assignment = best_assignment;
endmodule