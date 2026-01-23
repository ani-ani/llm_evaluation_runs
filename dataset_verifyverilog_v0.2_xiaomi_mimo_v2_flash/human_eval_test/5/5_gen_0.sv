module intersperse (
    input [3:0] in_valid,
    input [3:0][7:0] in_data,
    input [7:0] delimiter,
    output reg [3:0] out_valid,
    output reg [7:0] out_data [7:0]
);

    integer i;

    always @(*) begin
        // Default initialization to avoid latches
        for (int j = 0; j < 8; j++) begin
            out_data[j] = 8'hxx;
        end
        out_valid = 4'b0;

        // Logic 1: If in_valid is 0, out_valid is 0.
        if (in_valid == 4'd0) begin
            out_valid = 4'd0;
        end 
        // Logic 2 & 3: If in_valid is N (1 to 4), place elements and delimiters
        else begin
            out_valid = (in_valid * 2) - 1;
            
            // Place input[0] at out_data[0]
            out_data[0] = in_data[0];
            
            // Iterate through remaining valid elements
            // Using i for input index, iterating from 1 to N-1
            for (i = 1; i < in_valid; i++) begin
                // Place delimiter at out_data[2*i - 1]
                out_data[(2 * i) - 1] = delimiter;
                // Place input[i] at out_data[2*i]
                out_data[2 * i] = in_data[i];
            end
        end
    end

endmodule
