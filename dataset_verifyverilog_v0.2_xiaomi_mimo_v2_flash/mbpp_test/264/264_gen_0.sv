module dog_age_calculator(
    input [7:0] human_age,
    output reg [31:0] dog_age
);

    // Constants in Q16.16 format
    localparam REAL_10_5 = 32'h000A8000; // 10.5 * 65536
    localparam REAL_21 = 32'h00150000;   // 21 * 65536
    localparam REAL_4 = 32'h00040000;     // 4 * 65536

    // Intermediate results to avoid long combinatorial paths
    wire [31:0] result_le_2;
    wire [31:0] result_gt_2;
    wire [31:0] diff;

    // Calculate: human_age * 10.5
    // human_age is 8-bit unsigned. Extend to 32-bit for multiplication.
    // human_age is treated as a real number (implicit Q0.0), so result is Q0.0 * Q16.16 = Q16.16.
    assign result_le_2 = human_age * REAL_10_5;

    // Calculate: 21 + (human_age - 2) * 4
    assign diff = human_age - 8'd2;
    assign result_gt_2 = REAL_21 + (diff * REAL_4);

    // Mux logic
    always @(*) begin
        if (human_age <= 8'd2) begin
            dog_age = result_le_2;
        end else begin
            dog_age = result_gt_2;
        end
    end

endmodule
