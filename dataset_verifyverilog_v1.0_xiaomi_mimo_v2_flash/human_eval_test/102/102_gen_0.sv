module choose_num (
    input [15:0] x,
    input [15:0] y,
    output reg [15:0] result
);

    // Internal combinational signals
    reg [15:0] largest_even;
    reg [15:0] candidate;

    always @(*) begin
        // Step 1: Check if x > y
        if (x > y) begin
            result = 16'hFFFF;
        end else begin
            // Step 2: Calculate largest even number <= y
            if (y[0] == 1'b0) begin  // y is even
                candidate = y;
            end else begin  // y is odd
                candidate = y - 16'd1;
            end
            
            // Step 3 & 4: Check if candidate >= x
            if (candidate >= x) begin
                result = candidate;
            end else begin
                result = 16'hFFFF;
            end
        end
    end

endmodule