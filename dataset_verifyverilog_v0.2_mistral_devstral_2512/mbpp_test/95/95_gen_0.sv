module Find_Min_Length(
    input [3:0][7:0][7:0] data,
    input [3:0] valid_mask,
    output reg [3:0] min_length
);

parameter MAX_SUBARRAYS = 4;
parameter MAX_SUBARRAY_SIZE = 8;

reg [3:0] lengths [0:3];
integer i, j;

always @(*) begin
    for (i = 0; i < MAX_SUBARRAYS; i = i + 1) begin
        if (valid_mask[i]) begin
            lengths[i] = 0;
            for (j = 0; j < MAX_SUBARRAY_SIZE; j = j + 1) begin
                if (data[i][j] != 8'h00) begin
                    lengths[i] = lengths[i] + 1;
                end
            end
        end else begin
            lengths[i] = 4'hF;
        end
    end
    
    min_length = 4'hF;
    for (i = 0; i < MAX_SUBARRAYS; i = i + 1) begin
        if (valid_mask[i] && lengths[i] < min_length) begin
            min_length = lengths[i];
        end
    end
end

endmodule