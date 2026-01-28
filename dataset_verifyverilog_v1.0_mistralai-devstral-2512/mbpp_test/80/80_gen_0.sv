module tetrahedral_number(
    input [7:0] n,
    output reg signed [15:0] result
);
    reg [31:0] prod;
    reg [31:0] temp;
    
    always @(*) begin
        // Calculate intermediate product: n * (n + 1) * (n + 2)
        prod = (n + 8'd1) * (n + 8'd2);
        prod = n * prod;
        
        // Perform division by 6
        temp = prod / 6;
        
        // Saturate to 16-bit signed range
        if (temp > 16'd32767) begin
            result = 16'd32767;
        end else if (temp < 16'd-32768) begin
            result = 16'd-32768;
        end else begin
            result = temp[15:0];
        end
    end
endmodule