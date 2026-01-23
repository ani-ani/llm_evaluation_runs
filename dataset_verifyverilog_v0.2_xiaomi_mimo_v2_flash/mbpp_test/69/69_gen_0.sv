module sublist_checker(
    input [7:0] main_list [0:7],
    input [7:0] sub_list [0:3],
    input [2:0] sub_len,
    output reg is_sublist
);

    integer i, j;
    reg match;
    reg [7:0] window [0:3];

    always @(*) begin
        // Default output for no match or edge cases
        is_sublist = 1'b0;

        // Handle edge cases
        if (sub_len == 3'd0) begin
            // Empty sublist always matches
            is_sublist = 1'b1;
        end else if (sub_len > 3'd4) begin
            // Invalid length or exceeds sub_list width (though width is 4)
            // Requirement says if sub_len > 8 return false, but sub_len is 3 bits (0-7)
            // Let's strictly follow: if sub_len > 8, return false. 
            // Since max is 7, it will always be <= 7, but we check bounds.
            // Also checking if sub_len > 4 would be logical error protection.
            is_sublist = 1'b0;
        end else begin
            // Iterate through all possible start positions in main_list
            for (i = 0; i < 8; i = i + 1) begin
                // Check if window starting at i fits in main_list (i + sub_len <= 8)
                if ((i + sub_len) <= 8) begin
                    match = 1'b1;
                    // Check elements of sublist against main_list window
                    for (j = 0; j < 4; j = j + 1) begin
                        if (j < sub_len) begin
                            if (sub_list[j] != main_list[i + j]) begin
                                match = 1'b0;
                            end
                        end
                    end
                    
                    // If a match is found, set output and stop checking
                    if (match) begin
                        is_sublist = 1'b1;
                    end
                end
            end
        end
    end

endmodule
