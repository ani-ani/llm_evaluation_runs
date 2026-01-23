module drop_empty(
    input [7:0] key_0, key_1, key_2, key_3, key_4, key_5, key_6, key_7,
    input [7:0] val_0, val_1, val_2, val_3, val_4, val_5, val_6, val_7,
    output reg [7:0] out_key_0, out_key_1, out_key_2, out_key_3,
    output reg [7:0] out_val_0, out_val_1, out_val_2, out_val_3,
    output reg [2:0] count
);

    integer i;
    integer write_idx;

    // Pack inputs into arrays for easier iteration
    wire [7:0] keys [0:7];
    wire [7:0] vals [0:7];

    assign keys[0] = key_0;
    assign keys[1] = key_1;
    assign keys[2] = key_2;
    assign keys[3] = key_3;
    assign keys[4] = key_4;
    assign keys[5] = key_5;
    assign keys[6] = key_6;
    assign keys[7] = key_7;

    assign vals[0] = val_0;
    assign vals[1] = val_1;
    assign vals[2] = val_2;
    assign vals[3] = val_3;
    assign vals[4] = val_4;
    assign vals[5] = val_5;
    assign vals[6] = val_6;
    assign vals[7] = val_7;

    always @(*) begin
        // Initialize outputs to zero to handle cases with fewer than 4 pairs
        out_key_0 = 8'h00;
        out_key_1 = 8'h00;
        out_key_2 = 8'h00;
        out_key_3 = 8'h00;
        out_val_0 = 8'h00;
        out_val_1 = 8'h00;
        out_val_2 = 8'h00;
        out_val_3 = 8'h00;
        count = 3'b000;
        write_idx = 0;

        for (i = 0; i < 8; i = i + 1) begin
            // Check if value is not 0xFF (None)
            if (vals[i] != 8'hFF) begin
                count = count + 1;
                
                // Only update the first 4 output slots as per requirements
                if (write_idx == 0) begin
                    out_key_0 = keys[i];
                    out_val_0 = vals[i];
                end
                else if (write_idx == 1) begin
                    out_key_1 = keys[i];
                    out_val_1 = vals[i];
                end
                else if (write_idx == 2) begin
                    out_key_2 = keys[i];
                    out_val_2 = vals[i];
                end
                else if (write_idx == 3) begin
                    out_key_3 = keys[i];
                    out_val_3 = vals[i];
                end
                
                write_idx = write_idx + 1;
            end
        end
    end

endmodule