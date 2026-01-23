module move_one_ball(
    input [7:0] arr [0:7],
    output result
);

    reg [2:0] drops;
    reg boundary_violation;
    integer i;

    always @(*) begin
        drops = 3'd0;
        boundary_violation = 1'b0;
        
        for (i = 0; i < 7; i = i + 1) begin
            if (arr[i] > arr[i + 1]) begin
                drops = drops + 3'd1;
            end
        end
        
        if (arr[7] > arr[0]) begin
            boundary_violation = 1'b1;
        end
        
        result = (drops == 3'd0) || (drops == 3'd1 && boundary_violation == 1'b0);
    end

endmodule