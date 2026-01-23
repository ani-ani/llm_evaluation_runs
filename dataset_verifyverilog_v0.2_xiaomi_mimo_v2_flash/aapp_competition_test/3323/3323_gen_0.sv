module drink_satisfaction (
    input logic [7:0][15:0] req_A,
    input logic [7:0][15:0] req_B,
    input logic [7:0][15:0] req_C,
    input logic [2:0] num_people,
    output logic [3:0] max_satisfied
);

    localparam TOTAL_FIXED = 24'h10000; // 1.0 in Q16.16
    localparam NUM_PEOPLE_MAX = 8;

    logic [23:0] sum_A [0:7];
    logic [23:0] sum_B [0:7];
    logic [23:0] sum_C [0:7];
    logic [23:0] total_sum [0:7];
    logic valid [0:7];

    logic [7:0] mask;
    logic [23:0] psum_A, psum_B, psum_C;
    logic [23:0] valid_sum;

    logic [23:0] next_psum_A;
    logic [23:0] next_psum_B;
    logic [23:0] next_psum_C;
    logic [23:0] next_valid_sum;
    logic next_valid;

    logic [3:0] count;

    // Initialize partial sums for count 0
    always_comb begin
        sum_A[0] = 24'd0;
        sum_B[0] = 24'd0;
        sum_C[0] = 24'd0;
        total_sum[0] = 24'd0;
        valid[0] = 1'b0;
    end

    // Sequential logic for prefix sums by count
    integer i;
    always_comb begin
        for (int k = 0; k < 8; k++) begin
            sum_A[k] = 24'd0;
            sum_B[k] = 24'd0;
            sum_C[k] = 24'd0;
            total_sum[k] = 24'd0;
            valid[k] = 1'b0;
        end

        // Initialize for count 0
        sum_A[0] = 24'd0;
        sum_B[0] = 24'd0;
        sum_C[0] = 24'd0;
        total_sum[0] = 24'd0;
        valid[0] = 1'b0;

        // Loop through counts 1 to 7, using all 8 partial sums from previous step
        for (int c = 1; c <= 7; c++) begin
            // Default assignment to avoid latches, overwritten below
            sum_A[c] = sum_A[c-1];
            sum_B[c] = sum_B[c-1];
            sum_C[c] = sum_C[c-1];
            total_sum[c] = total_sum[c-1];
            valid[c] = valid[c-1];

            // The update adds req[c-1] to the sums from index c-1
            sum_A[c] = sum_A[c-1] + req_A[c-1];
            sum_B[c] = sum_B[c-1] + req_B[c-1];
            sum_C[c] = sum_C[c-1] + req_C[c-1];
            total_sum[c] = total_sum[c-1] + req_A[c-1] + req_B[c-1] + req_C[c-1];
            
            // Constraint check
            if (total_sum[c] <= TOTAL_FIXED && c <= num_people) valid[c] = 1'b1;
            else valid[c] = 1'b0;
        end
    end

    // Priority Encoder for max_satisfied
    always_comb begin
        max_satisfied = 4'd0;
        if (valid[7]) max_satisfied = 4'd7;
        else if (valid[6]) max_satisfied = 4'd6;
        else if (valid[5]) max_satisfied = 4'd5;
        else if (valid[4]) max_satisfied = 4'd4;
        else if (valid[3]) max_satisfied = 4'd3;
        else if (valid[2]) max_satisfied = 4'd2;
        else if (valid[1]) max_satisfied = 4'd1;
        else max_satisfied = 4'd0;
    end

endmodule
