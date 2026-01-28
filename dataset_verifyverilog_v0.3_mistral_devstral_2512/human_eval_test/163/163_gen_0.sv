module generate_integers(
    input [7:0] a,
    input [7:0] b,
    output [7:0] result [0:4],
    output [2:0] count
);

    reg [7:0] min_val;
    reg [7:0] max_val;
    reg [7:0] even_digits [0:4];
    reg [2:0] valid_count;
    integer i;

    assign min_val = (a < b) ? a : b;
    assign max_val = (a > b) ? a : b;

    always @(*) begin
        valid_count = 3'd0;
        
        // Initialize all result elements to 0
        for (i = 0; i < 5; i = i + 1) begin
            result[i] = 8'd0;
        end
        
        // Check each even digit
        if (0 >= min_val && 0 <= max_val) begin
            result[0] = 8'd0;
            valid_count = valid_count + 3'd1;
        end
        
        if (2 >= min_val && 2 <= max_val) begin
            result[1] = 8'd2;
            valid_count = valid_count + 3'd1;
        end
        
        if (4 >= min_val && 4 <= max_val) begin
            result[2] = 8'd4;
            valid_count = valid_count + 3'd1;
        end
        
        if (6 >= min_val && 6 <= max_val) begin
            result[3] = 8'd6;
            valid_count = valid_count + 3'd1;
        end
        
        if (8 >= min_val && 8 <= max_val) begin
            result[4] = 8'd8;
            valid_count = valid_count + 3'd1;
        end
        
        count = valid_count;
    end

endmodule