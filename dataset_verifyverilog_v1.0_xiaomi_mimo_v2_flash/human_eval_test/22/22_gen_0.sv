module filter_integers(
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg [3:0] count
);
    integer i;
    integer out_idx;
    always @(*) begin
        // Initialize output arrays
        for (i = 0; i < 8; i = i + 1) begin
            result[i] = 8'd0;
        end
        count = 4'd0;
        out_idx = 0;
        
        // Iterate through input array and filter integers
        for (i = 0; i < 8; i = i + 1) begin
            // Check if value is in valid integer range [0, 255]
            // Since input is 8-bit, all values are automatically 0-255
            // This makes all 8 elements valid integers
            result[out_idx] = arr[i];
            out_idx = out_idx + 1;
            count = count + 4'd1;
        end
    end
endmodule