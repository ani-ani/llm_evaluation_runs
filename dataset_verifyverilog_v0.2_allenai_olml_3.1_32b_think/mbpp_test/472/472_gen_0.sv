module check_consecutive(input [7:0] data [0:7], output reg result);
always @(*) begin
    reg [7:0] min_val, max_val;
    integer i, j;
    reg dup_found;

    min_val = data[0];
    for (i=1; i<8; i=i+1) begin
        if (data[i] < min_val)
            min_val = data[i];
    end

    max_val = data[0];
    for (i=1; i<8; i=i+1) begin
        if (data[i] > max_val)
            max_val = data[i];
    end

    if (max_val != min_val + 7) begin
        result = 1'b0;
    end else begin
        dup_found = 1'b0;
        for (i=0; i<8; i=i+1) begin
            for (j=i+1; j<8; j=j+1) begin
                if (data[i] == data[j]) begin
                    dup_found = 1'b1;
                end
            end
        end
        if (dup_found) begin
            result = 1'b0;
        end else begin
            result = 1'b1;
        end
    end
end
endmodule