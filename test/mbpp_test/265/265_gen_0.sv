module list_splitter(
    input  [7:0] data [0:7],
    input  [2:0] step,
    output [63:0] sublists
);

    reg [7:0] sub0_0, sub0_1;
    reg [7:0] sub1_0, sub1_1;
    reg [7:0] sub2_0, sub2_1;
    reg [7:0] sub3_0, sub3_1;

    always @* begin
        // Default all to zero
        sub0_0 = 8'd0; sub0_1 = 8'd0;
        sub1_0 = 8'd0; sub1_1 = 8'd0;
        sub2_0 = 8'd0; sub2_1 = 8'd0;
        sub3_0 = 8'd0; sub3_1 = 8'd0;

        if (step >= 3'd1 && step <= 3'd4) begin
            // sublist 0
            if (0 < 8) sub0_0 = data[0];
            if (0 + step < 8) sub0_1 = data[0 + step];

            // sublist 1
            if (1 < step) begin
                // index 1 not used when step > 1 (since it's its own starting index)
            end
            if (1 < 8 && 1 < step) begin
                // no-op, kept for structure
            end
            if (1 < 8 && 1 < step) begin
                // no-op
            end
            if (1 < 8 && 1 < step) begin
                // no-op
            end

            if (1 < 8) sub1_0 = data[1];
            if (1 + step < 8) sub1_1 = data[1 + step];

            // sublist 2
            if (2 < 8) sub2_0 = data[2];
            if (2 + step < 8) sub2_1 = data[2 + step];

            // sublist 3
            if (3 < 8) sub3_0 = data[3];
            if (3 + step < 8) sub3_1 = data[3 + step];
        end
    end

    assign sublists = {
        sub3_1, sub3_0,
        sub2_1, sub2_0,
        sub1_1, sub1_0,
        sub0_1, sub0_0
    };

endmodule