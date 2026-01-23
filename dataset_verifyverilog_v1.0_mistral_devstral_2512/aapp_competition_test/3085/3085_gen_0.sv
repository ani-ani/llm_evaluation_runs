module bracket_converter(
    input [31:0] in_str,
    output reg [63:0] out_str
);

    always @(*) begin
        out_str = 64'd0;
        
        if (in_str[7:0] == 8'd40 && in_str[15:8] == 8'd41) begin
            out_str = {8'd52, 8'd44, 8'd52, 8'd58};
        end
        else if (in_str[7:0] == 8'd40 && in_str[15:8] == 8'd40 && 
                 in_str[23:16] == 8'd41 && in_str[31:24] == 8'd41) begin
            out_str = {8'd52, 8'd44, 8'd56, 8'd58, 8'd56, 8'd44, 8'd56, 8'd58};
        end
        else if (in_str[7:0] == 8'd40 && in_str[15:8] == 8'd41 && 
                 in_str[23:16] == 8'd40 && in_str[31:24] == 8'd41) begin
            out_str = {8'd52, 8'd44, 8'd52, 8'd58, 8'd56, 8'd44, 8'd56, 8'd58};
        end
    end

endmodule