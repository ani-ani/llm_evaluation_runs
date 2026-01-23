module remove_odd (
    input [7:0] data_in [0:7],
    input [2:0] valid_count,
    output reg [7:0] data_out [0:7],
    output reg [2:0] out_count
);

    integer i;
    integer write_idx;

    always @(*) begin
        // Initialize outputs
        for (int j = 0; j < 8; j = j + 1) begin
            data_out[j] = 8'b0;
        end
        out_count = 3'b0;
        write_idx = 0;

        // Filter and pack even numbers
        for (i = 0; i < 8; i = i + 1) begin
            if (i < valid_count) begin
                if (data_in[i][0] == 1'b0) begin // Check if even
                    data_out[write_idx] = data_in[i];
                    write_idx = write_idx + 1;
                end
            end
        end
        
        // Assign count
        out_count = write_idx[2:0];
    end

endmodule
