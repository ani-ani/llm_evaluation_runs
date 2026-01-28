module exchange_check(
    input [7:0] lst1 [0:7],
    input [7:0] lst2 [0:7],
    output result
);
    
    reg [3:0] odd1_count;
    reg [3:0] even2_count;
    integer i;
    
    always @(*) begin
        odd1_count = 4'd0;
        even2_count = 4'd0;
        
        for (i = 0; i < 8; i = i + 1) begin
            if (lst1[i][0] == 1'b1) begin
                odd1_count = odd1_count + 4'd1;
            end
        end
        
        for (i = 0; i < 8; i = i + 1) begin
            if (lst2[i][0] == 1'b0) begin
                even2_count = even2_count + 4'd1;
            end
        end
        
        if (odd1_count <= even2_count) begin
            result = 1'b1;
        end else begin
            result = 1'b0;
        end
    end
endmodule