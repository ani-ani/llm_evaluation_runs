module string_extractor (
    input [7:0][7:0] strings,
    input [2:0] target_len,
    input [4:0] valid_mask,
    output [7:0][7:0] result,
    output [4:0] result_mask
);
always @(*) begin
    reg [7:0][7:0] temp_result [5];
    reg [4:0] count = 0;
    reg [7:0][7:0] result_temp = 0;
    for (integer i=0; i<5; i=i+1) begin
        if (valid_mask[i] == 1) begin
            integer length;
            length = 0;
            for (integer j=7; j>=0; j=j-1) begin
                if (strings[i][j] == 1) begin
                    length = length + 1;
                end else begin
                    break;
                end
            end
            if (length == target_len) begin
                temp_result[count] = strings[i];
                count = count + 1;
            end
        end
    end
    for (integer k=0; k<count; k=k+1) begin
        result_temp[k] = temp_result[k];
    end
    result = result_temp;
    result_mask = (1 << count) - 1;
end
endmodule