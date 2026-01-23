module exchange_check(
    input [7:0] lst1 [0:7],
    input [7:0] lst2 [0:7],
    output reg result
);
    // Counters for odd numbers in lst1 and even numbers in lst2
    reg [3:0] odd1_count;
    reg [3:0] even2_count;
    
    // Combinational logic for counting
    always @(*) begin
        // Initialize counters to zero
        odd1_count = 4'd0;
        even2_count = 4'd0;
        
        // Count odd numbers in lst1
        // Check LSB for odd/even: element[0] == 1 means odd
        if (lst1[0][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        if (lst1[1][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        if (lst1[2][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        if (lst1[3][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        if (lst1[4][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        if (lst1[5][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        if (lst1[6][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        if (lst1[7][0] == 1'b1) odd1_count = odd1_count + 4'd1;
        
        // Count even numbers in lst2
        // Check LSB for even: element[0] == 0 means even
        if (lst2[0][0] == 1'b0) even2_count = even2_count + 4'd1;
        if (lst2[1][0] == 1'b0) even2_count = even2_count + 4'd1;
        if (lst2[2][0] == 1'b0) even2_count = even2_count + 4'd1;
        if (lst2[3][0] == 1'b0) even2_count = even2_count + 4'd1;
        if (lst2[4][0] == 1'b0) even2_count = even2_count + 4'd1;
        if (lst2[5][0] == 1'b0) even2_count = even2_count + 4'd1;
        if (lst2[6][0] == 1'b0) even2_count = even2_count + 4'd1;
        if (lst2[7][0] == 1'b0) even2_count = even2_count + 4'd1;
        
        // Determine if exchange is possible
        // If odd1_count <= even2_count, result = 1, else 0
        if (odd1_count <= even2_count) begin
            result = 1'b1;
        end else begin
            result = 1'b0;
        end
    end
endmodule