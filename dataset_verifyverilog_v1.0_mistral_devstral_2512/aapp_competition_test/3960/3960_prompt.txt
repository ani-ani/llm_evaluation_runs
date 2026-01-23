module max_f #(parameter N=8) (
    input [63:0] a [0:N-1],
    output reg [63:0] max_value
);
    // Compute differences
    wire [63:0] diff [0:N-2];
    generate
        for (genvar i = 0; i < N-1; i = i+1) begin : diff_gen
            assign diff[i] = (a[i] > a[i+1]) ? (a[i] - a[i+1]) : (a[i+1] - a[i]);
        end
    endgenerate

    // Compute signed sequences b1 and b2
    wire signed [63:0] b1 [0:N-2];
    wire signed [63:0] b2 [0:N-2];
    generate
        for (genvar i = 0; i < N-1; i = i+1) begin : b_gen
            assign b1[i] = (i[0] == 0) ? diff[i] : -diff[i];
            assign b2[i] = -b1[i];
        end
    endgenerate

    // Kadane's algorithm for b1
    wire signed [63:0] max_b1;
    kadane #(.LEN(N-1)) kadane_b1 (.arr(b1), .max_sum(max_b1));

    // Kadane's algorithm for b2
    wire signed [63:0] max_b2;
    kadane #(.LEN(N-1)) kadane_b2 (.arr(b2), .max_sum(max_b2));

    // Final maximum
    always @(*) begin
        max_value = (max_b1 > max_b2) ? max_b1 : max_b2;
    end

endmodule

module kadane #(parameter LEN=7) (
    input signed [63:0] arr [0:LEN-1],
    output reg signed [63:0] max_sum
);

    integer i;
    reg signed [63:0] max_ending_here;
    reg signed [63:0] max_so_far;

    always @(*) begin
        max_ending_here = arr[0];
        max_so_far = arr[0];
        for (i = 1; i < LEN; i = i + 1) begin
            if (max_ending_here + arr[i] > arr[i])
                max_ending_here = max_ending_here + arr[i];
            else
                max_ending_here = arr[i];
            if (max_ending_here > max_so_far)
                max_so_far = max_ending_here;
        end
        max_sum = max_so_far;
    end

endmodule