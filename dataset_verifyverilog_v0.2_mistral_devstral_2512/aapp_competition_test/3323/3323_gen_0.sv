module drink_satisfaction (
    input [7:0][15:0] req_A,
    input [7:0][15:0] req_B,
    input [7:0][15:0] req_C,
    input [2:0] num_people,
    output [3:0] max_satisfied
);

    wire [7:0] valid_subset [0:255];
    wire [3:0] subset_count [0:255];
    wire [3:0] max_count = 4'b0;

    genvar i, j;

    // Generate all 256 subsets
    generate
        for (i = 0; i < 256; i = i + 1) begin : subset_gen
            wire [18:0] sum_A = 19'b0;
            wire [18:0] sum_B = 19'b0;
            wire [18:0] sum_C = 19'b0;
            wire [3:0] count = 4'b0;

            // Sum requirements for this subset
            for (j = 0; j < 8; j = j + 1) begin : person_loop
                if (i[j]) begin
                    assign sum_A = sum_A + req_A[j];
                    assign sum_B = sum_B + req_B[j];
                    assign sum_C = sum_C + req_C[j];
                    assign count = count + 1'b1;
                end
            end

            // Check if sum <= 1.0 (0x00010000)
            assign valid_subset[i] = (sum_A + sum_B + sum_C) <= 19'h00010000;
            assign subset_count[i] = count;
        end
    endgenerate

    // Find maximum count among valid subsets
    always @(*) begin
        max_count = 4'b0;
        for (i = 0; i < 256; i = i + 1) begin
            if (valid_subset[i] && (subset_count[i] > max_count) && (subset_count[i] <= num_people)) begin
                max_count = subset_count[i];
            end
        end
    end

    assign max_satisfied = max_count;

endmodule