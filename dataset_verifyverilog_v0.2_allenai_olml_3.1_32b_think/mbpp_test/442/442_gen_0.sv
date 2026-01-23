module positive_ratio (
    input [7:0] data_in,
    input [2:0] index,
    input valid,
    output reg [31:0] result,
    output reg result_valid
);

reg [7:0] count;

always @(valid or data_in or index) begin
    if (valid) begin
        if (data_in > 0) begin
            count <= count + 1;
        end
    end
end

assign result = (count << 13);

reg result_valid_reg;
always @(index or valid) begin
    if (index == 3'd7 && valid) begin
        result_valid_reg <= 1'b1;
    end else begin
        result_valid_reg <= 1'b0;
    end
end
assign result_valid = result_valid_reg;

endmodule