module longest_exactly_twice(
    input [15:0] arr_0,
    input [15:0] arr_1,
    input [15:0] arr_2,
    input [15:0] arr_3,
    input [15:0] arr_4,
    input [15:0] arr_5,
    input [15:0] arr_6,
    input [15:0] arr_7,
    input [3:0] N,
    output reg [7:0] max_length
);

    // Create internal array
    wire [15:0] arr [0:7];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;

    integer l, start, i, j;
    reg valid;
    reg [15:0] count;

    always @(*) begin
        max_length = 8'd0;

        // Main loop for subarray length (l_loop)
        l_loop: for (l = 8; l >= 2; l = l - 2) begin
            if (l > {1'b0, N}) continue; // Skip invalid lengths

            start_loop: for (start = 0; start <= ({1'b0, N} - l); start = start + 1) begin
                valid = 1'b1;
                
                // Check each element in current subarray
                for (i = 0; i < l; i = i + 1) begin
                    count = 16'd0;
                    
                    // Count occurrences of current element
                    for (j = 0; j < l; j = j + 1) begin
                        if (arr[start+i] == arr[start+j]) begin
                            count = count + 16'd1;
                        end
                    end
                    
                    if (count != 16'd2) begin
                        valid = 1'b0;
                        disable start_loop;
                    end
                end
                
                // Valid subarray found
                if (valid) begin
                    max_length = l[7:0];
                    disable l_loop;
                end
            end
        end
    end
endmodule