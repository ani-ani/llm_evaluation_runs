module extract_even(
    input [3:0] level1_0,
    input [3:0] level1_1,
    input [3:0] level1_2,
    input [3:0] level1_3,
    input [3:0] level2_0,
    input [3:0] level2_1,
    input [3:0] level2_2,
    input [3:0] level2_3,
    output reg [3:0] result_0,
    output reg [3:0] result_1,
    output reg [3:0] result_2,
    output reg [3:0] result_3,
    output reg [2:0] valid_count
);

    // Internal signals for even check (1 = even, 0 = odd)
    wire even_l1_0 = ~level1_0[0];
    wire even_l1_1 = ~level1_1[0];
    wire even_l1_2 = ~level1_2[0];
    wire even_l1_3 = ~level1_3[0];
    wire even_l2_0 = ~level2_0[0];
    wire even_l2_1 = ~level2_1[0];
    wire even_l2_2 = ~level2_2[0];
    wire even_l2_3 = ~level2_3[0];

    // Level 1 packed array for processing
    wire [3:0] l1_vals [0:3];
    assign l1_vals[0] = level1_0;
    assign l1_vals[1] = level1_1;
    assign l1_vals[2] = level1_2;
    assign l1_vals[3] = level1_3;
    wire [3:0] l1_evens;
    assign l1_evens[0] = even_l1_0;
    assign l1_evens[1] = even_l1_1;
    assign l1_evens[2] = even_l1_2;
    assign l1_evens[3] = even_l1_3;

    // Level 2 packed array for processing
    wire [3:0] l2_vals [0:3];
    assign l2_vals[0] = level2_0;
    assign l2_vals[1] = level2_1;
    assign l2_vals[2] = level2_2;
    assign l2_vals[3] = level2_3;
    wire [3:0] l2_evens;
    assign l2_evens[0] = even_l2_0;
    assign l2_evens[1] = even_l2_1;
    assign l2_evens[2] = even_l2_2;
    assign l2_evens[3] = even_l2_3;

    // Combinational logic block
    always @(*) begin
        // Local arrays to hold candidates before assignment to outputs
        // We need to fill these sequentially
        reg [3:0] temp_vals [0:7];
        integer i;
        integer j;
        integer k;
        integer count;

        // Initialize temp array and count
        for (i = 0; i < 8; i = i + 1) begin
            temp_vals[i] = 4'h0;
        end
        count = 0;

        // Process Level 1 (in order 0..3)
        for (j = 0; j < 4; j = j + 1) begin
            if (l1_evens[j]) begin
                temp_vals[count] = l1_vals[j];
                count = count + 1;
            end
        end

        // Process Level 2 (in order 0..3)
        for (k = 0; k < 4; k = k + 1) begin
            if (l2_evens[k]) begin
                temp_vals[count] = l2_vals[k];
                count = count + 1;
            end
        end

        // Assign to outputs
        result_0 = temp_vals[0];
        result_1 = temp_vals[1];
        result_2 = temp_vals[2];
        result_3 = temp_vals[3];
        valid_count = count;
    end

endmodule
