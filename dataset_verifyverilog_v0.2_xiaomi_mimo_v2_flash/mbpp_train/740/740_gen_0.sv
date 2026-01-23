module tuple_to_dict (
    input [7:0] tuple_data [0:7],
    input [2:0] valid_count,
    output reg [7:0] key_0,
    output reg [7:0] key_1,
    output reg [7:0] key_2,
    output reg [7:0] key_3,
    output reg [7:0] val_0,
    output reg [7:0] val_1,
    output reg [7:0] val_2,
    output reg [7:0] val_3,
    output reg [2:0] pair_count
);

    always @(*) begin
        // Calculate pair count
        pair_count = valid_count >> 1;

        // Default values for pair 0
        key_0 = 8'b0;
        val_0 = 8'b0;
        // Default values for pair 1
        key_1 = 8'b0;
        val_1 = 8'b0;
        // Default values for pair 2
        key_2 = 8'b0;
        val_2 = 8'b0;
        // Default values for pair 3
        key_3 = 8'b0;
        val_3 = 8'b0;

        // Pair 0 processing
        if (pair_count > 3'd0) begin
            key_0 = tuple_data[0];
            val_0 = tuple_data[1];
        end

        // Pair 1 processing
        if (pair_count > 3'd1) begin
            key_1 = tuple_data[2];
            val_1 = tuple_data[3];
        end

        // Pair 2 processing
        if (pair_count > 3'd2) begin
            key_2 = tuple_data[4];
            val_2 = tuple_data[5];
        end

        // Pair 3 processing
        if (pair_count > 3'd3) begin
            key_3 = tuple_data[6];
            val_3 = tuple_data[7];
        end
    end

endmodule
