module filter_even(
    input [7:0] data_in [0:7],
    output reg [7:0] data_out [0:7],
    output reg [2:0] count
);

    integer i;
    integer j;

    always @(*) begin
        // Initialize count and output array
        count = 0;
        for (j = 0; j < 8; j = j + 1) begin
            data_out[j] = 8'b0;
        end

        // Iterate through input array
        for (i = 0; i < 8; i = i + 1) begin
            // Check if number is even (LSB is 0)
            if (data_in[i][0] == 1'b0) begin
                data_out[count] = data_in[i];
                count = count + 1;
            end
        end
    end

endmodule