module happy_string (
    input [3:0] str_len,
    input [63:0] str_data,
    output reg happy
);

    // Extract individual characters from the packed string data
    wire [7:0] char0 = str_data[0*8+:8];
    wire [7:0] char1 = str_data[1*8+:8];
    wire [7:0] char2 = str_data[2*8+:8];
    wire [7:0] char3 = str_data[3*8+:8];
    wire [7:0] char4 = str_data[4*8+:8];
    wire [7:0] char5 = str_data[5*8+:8];
    wire [7:0] char6 = str_data[6*8+:8];
    wire [7:0] char7 = str_data[7*8+:8];

    // Define signals for triplet validity (0-5 for maximum 6 triplets in 8-char string)
    wire triplet0_valid;
    wire triplet1_valid;
    wire triplet2_valid;
    wire triplet3_valid;
    wire triplet4_valid;
    wire triplet5_valid;

    // Check triplet0 (positions 0,1,2) - requires at least 3 characters
    assign triplet0_valid = (str_len >= 3) ? 
        ((char0 != char1) && (char0 != char2) && (char1 != char2)) : 1'b1;
    
    // Check triplet1 (positions 1,2,3) - requires at least 4 characters
    assign triplet1_valid = (str_len >= 4) ? 
        ((char1 != char2) && (char1 != char3) && (char2 != char3)) : 1'b1;
    
    // Check triplet2 (positions 2,3,4) - requires at least 5 characters
    assign triplet2_valid = (str_len >= 5) ? 
        ((char2 != char3) && (char2 != char4) && (char3 != char4)) : 1'b1;
    
    // Check triplet3 (positions 3,4,5) - requires at least 6 characters
    assign triplet3_valid = (str_len >= 6) ? 
        ((char3 != char4) && (char3 != char5) && (char4 != char5)) : 1'b1;
    
    // Check triplet4 (positions 4,5,6) - requires at least 7 characters
    assign triplet4_valid = (str_len >= 7) ? 
        ((char4 != char5) && (char4 != char6) && (char5 != char6)) : 1'b1;
    
    // Check triplet5 (positions 5,6,7) - requires all 8 characters
    assign triplet5_valid = (str_len >= 8) ? 
        ((char5 != char6) && (char5 != char7) && (char6 != char7)) : 1'b1;

    // Determine happy output: 0 if too short, otherwise all triplets must be valid
    always @(*) begin
        if (str_len < 3) begin
            happy = 1'b0;  // Too short to be happy
        end else begin
            // All required triplets must be valid
            happy = triplet0_valid & triplet1_valid & triplet2_valid & 
                    triplet3_valid & triplet4_valid & triplet5_valid;
        end
    end

endmodule