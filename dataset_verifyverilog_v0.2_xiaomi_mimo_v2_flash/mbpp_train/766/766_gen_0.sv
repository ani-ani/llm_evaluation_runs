module pairwise_consecutive (
    input [7:0][7:0] data_in,
    input [2:0] num_elements,
    output reg [6:0][15:0] pairs_out,
    output reg [2:0] num_pairs
);

    integer i;

    always @(*) begin
        // Default assignments
        num_pairs = 3'b0;
        for (int j = 0; j < 7; j++) begin
            pairs_out[j] = 16'b0;
        end

        if (num_elements > 3'd1) begin
            num_pairs = num_elements - 1;
            for (i = 0; i < 8; i++) begin
                if (i < num_elements - 1) begin
                    pairs_out[i] = {data_in[i], data_in[i+1]};
                end
            end
        end
    end

endmodule