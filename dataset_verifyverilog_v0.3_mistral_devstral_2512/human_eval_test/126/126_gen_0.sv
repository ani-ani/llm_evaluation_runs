module is_sorted(
    input [7:0] arr [0:7],
    output result
);

    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] count;
    reg sorted;
    reg no_duplicates;

    always @(*) begin
        sorted = 1'b1;
        no_duplicates = 1'b1;

        // Check if sorted
        for (i = 0; i < 7; i = i + 1) begin
            if (arr[i] > arr[i + 1]) begin
                sorted = 1'b0;
            end
        end

        // Check for duplicates
        for (i = 0; i < 8; i = i + 1) begin
            count = 0;
            for (j = 0; j < 8; j = j + 1) begin
                if (arr[i] == arr[j]) begin
                    count = count + 1;
                end
            end
            if (count > 1) begin
                no_duplicates = 1'b0;
            end
        end

        result = sorted & no_duplicates;
    end

endmodule