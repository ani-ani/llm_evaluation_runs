module list_even_exchange (
    input [7:0] lst1 [0:3],
    input [7:0] lst2 [0:3],
    output reg result
);
    
    integer i;
    integer odd1_count;
    integer even2_count;
    
    always @(*) begin
        odd1_count = 0;
        even2_count = 0;
        
        // Count odd elements in lst1
        for (i = 0; i < 4; i = i + 1) begin
            if (lst1[i][0] == 1'b1) // Check if LSB is 1 (odd)
                odd1_count = odd1_count + 1;
        end
        
        // Count even elements in lst2
        for (i = 0; i < 4; i = i + 1) begin
            if (lst2[i][0] == 1'b0) // Check if LSB is 0 (even)
                even2_count = even2_count + 1;
        end
        
        // Set result based on comparison
        if (odd1_count <= even2_count)
            result = 1'b1;
        else
            result = 1'b0;
    end
endmodule