module odd_filter(
    input [7:0] array_in [0:7],
    input [2:0] count,
    output reg [7:0] array_out [0:7],
    output reg [2:0] out_count
);

    integer i;
    integer j;

    always @(*) begin
        // Initialize output array to zeros and count to zero
        for (i = 0; i < 8; i = i + 1) begin
            array_out[i] = 8'b0;
        end
        out_count = 3'b0;

        // Iterate through valid input elements
        for (j = 0; j < 8; j = j + 1) begin
            // Check if element is within valid range and is odd
            if (j < count && array_in[j][0]) begin
                array_out[out_count] = array_in[j];
                out_count = out_count + 1'b1;
            end
        end
    end

endmodule