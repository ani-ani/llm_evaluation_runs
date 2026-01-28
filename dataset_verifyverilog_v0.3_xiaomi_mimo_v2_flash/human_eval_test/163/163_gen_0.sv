module generate_integers (
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] result [0:4],
    output reg [2:0] count
);
    // Intermediate signals
    reg [7:0] min_val;
    reg [7:0] max_val;
    
    // Even digits to check
    localparam [7:0] EVEN_DIGITS [0:4] = '{8'd0, 8'd2, 8'd4, 8'd6, 8'd8};
    
    // Combinational logic
    always @(*) begin
        // Determine min and max
        if (a < b) begin
            min_val = a;
            max_val = b;
        end else begin
            min_val = b;
            max_val = a;
        end
        
        // Initialize outputs
        result[0] = 8'd0;
        result[1] = 8'd0;
        result[2] = 8'd0;
        result[3] = 8'd0;
        result[4] = 8'd0;
        count = 3'd0;
        
        // Check each even digit and populate result array
        // Check digit 0
        if (8'd0 >= min_val && 8'd0 <= max_val) begin
            result[count] = 8'd0;
            count = count + 3'd1;
        end
        
        // Check digit 2
        if (8'd2 >= min_val && 8'd2 <= max_val) begin
            result[count] = 8'd2;
            count = count + 3'd1;
        end
        
        // Check digit 4
        if (8'd4 >= min_val && 8'd4 <= max_val) begin
            result[count] = 8'd4;
            count = count + 3'd1;
        end
        
        // Check digit 6
        if (8'd6 >= min_val && 8'd6 <= max_val) begin
            result[count] = 8'd6;
            count = count + 3'd1;
        end
        
        // Check digit 8
        if (8'd8 >= min_val && 8'd8 <= max_val) begin
            result[count] = 8'd8;
            count = count + 3'd1;
        end
    end
endmodule