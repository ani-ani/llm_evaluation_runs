module remove_lowercase(
    input [7:0] char0, char1, char2, char3,
    input [7:0] char4, char5, char6, char7,
    input [3:0] length,
    output reg [7:0] out0, out1, out2, out3,
    output reg [7:0] out4, out5, out6, out7,
    output reg [3:0] out_length
);

    // Internal storage for input characters to index easily
    wire [7:0] chars [0:7];
    assign chars[0] = char0;
    assign chars[1] = char1;
    assign chars[2] = char2;
    assign chars[3] = char3;
    assign chars[4] = char4;
    assign chars[5] = char5;
    assign chars[6] = char6;
    assign chars[7] = char7;

    // Step 1: Identify valid characters (not lowercase and within length)
    // A character is valid if its index < length AND it is NOT a lowercase letter (97-122)
    wire [7:0] is_valid;
    wire [7:0] is_lower;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : validity_check
            // Check if lowercase range (a-z is 97-122)
            // Using explicit comparisons for efficiency
            // ASCII 'a' is 8'h61, 'z' is 8'h7A
            assign is_lower[i] = (chars[i] >= 8'h61 && chars[i] <= 8'h7A);
            
            // Valid if within length and not lowercase
            assign is_valid[i] = (i < length) && !is_lower[i];
        end
    endgenerate

    // Step 2: Calculate output length
    // Count the number of valid bits set
    always @(*) begin
        out_length = 0;
        if (is_valid[0]) out_length = out_length + 1;
        if (is_valid[1]) out_length = out_length + 1;
        if (is_valid[2]) out_length = out_length + 1;
        if (is_valid[3]) out_length = out_length + 1;
        if (is_valid[4]) out_length = out_length + 1;
        if (is_valid[5]) out_length = out_length + 1;
        if (is_valid[6]) out_length = out_length + 1;
        if (is_valid[7]) out_length = out_length + 1;
    end

    // Step 3: Compact valid characters to the left
    // We iterate through output positions. For each output position, we find the Nth valid input character.
    // This is effectively a parallel prefix lookup.
    
    always @(*) begin
        // Default outputs to 0
        out0 = 8'h00;
        out1 = 8'h00;
        out2 = 8'h00;
        out3 = 8'h00;
        out4 = 8'h00;
        out5 = 8'h00;
        out6 = 8'h00;
        out7 = 8'h00;

        // Map Output 0 -> Find 1st valid input
        if (is_valid[0]) out0 = chars[0];
        else if (is_valid[1]) out0 = chars[1];
        else if (is_valid[2]) out0 = chars[2];
        else if (is_valid[3]) out0 = chars[3];
        else if (is_valid[4]) out0 = chars[4];
        else if (is_valid[5]) out0 = chars[5];
        else if (is_valid[6]) out0 = chars[6];
        else if (is_valid[7]) out0 = chars[7];

        // Map Output 1 -> Find 2nd valid input
        if (is_valid[1]) out1 = chars[1];
        else if (is_valid[2]) out1 = chars[2];
        else if (is_valid[3]) out1 = chars[3];
        else if (is_valid[4]) out1 = chars[4];
        else if (is_valid[5]) out1 = chars[5];
        else if (is_valid[6]) out1 = chars[6];
        else if (is_valid[7]) out1 = chars[7];

        // Map Output 2 -> Find 3rd valid input
        if (is_valid[2]) out2 = chars[2];
        else if (is_valid[3]) out2 = chars[3];
        else if (is_valid[4]) out2 = chars[4];
        else if (is_valid[5]) out2 = chars[5];
        else if (is_valid[6]) out2 = chars[6];
        else if (is_valid[7]) out2 = chars[7];

        // Map Output 3 -> Find 4th valid input
        if (is_valid[3]) out3 = chars[3];
        else if (is_valid[4]) out3 = chars[4];
        else if (is_valid[5]) out3 = chars[5];
        else if (is_valid[6]) out3 = chars[6];
        else if (is_valid[7]) out3 = chars[7];

        // Map Output 4 -> Find 5th valid input
        if (is_valid[4]) out4 = chars[4];
        else if (is_valid[5]) out4 = chars[5];
        else if (is_valid[6]) out4 = chars[6];
        else if (is_valid[7]) out4 = chars[7];

        // Map Output 5 -> Find 6th valid input
        if (is_valid[5]) out5 = chars[5];
        else if (is_valid[6]) out5 = chars[6];
        else if (is_valid[7]) out5 = chars[7];

        // Map Output 6 -> Find 7th valid input
        if (is_valid[6]) out6 = chars[6];
        else if (is_valid[7]) out6 = chars[7];

        // Map Output 7 -> Find 8th valid input
        if (is_valid[7]) out7 = chars[7];
    end

endmodule