module fruit_distribution (
    input [7:0] apples_str,
    input [7:0] oranges_str,
    input [7:0] total_fruits,
    output reg [7:0] mangoes
);

    // Internal signals for subtraction results
    wire [8:0] sub1; // 9-bit to detect overflow/underflow
    wire [7:0] sub1_sat;
    wire [8:0] sub2;
    wire [7:0] final_result;

    // Step 1: total_fruits - apples_str
    // Using 9-bit arithmetic to extend the operands and detect negative results
    assign sub1 = {1'b0, total_fruits} - {1'b0, apples_str};

    // Saturate to 0 if negative
    // If sub1[8] is 1, result is negative, so keep 0. Else take sub1[7:0].
    assign sub1_sat = sub1[8] ? 8'd0 : sub1[7:0];

    // Step 2: (total_fruits - apples_str) - oranges_str
    assign sub2 = {1'b0, sub1_sat} - {1'b0, oranges_str};

    // Saturate final result to 0 if negative
    assign final_result = sub2[8] ? 8'd0 : sub2[7:0];

    // Output assignment
    always @(*) begin
        mangoes = final_result;
    end

endmodule
