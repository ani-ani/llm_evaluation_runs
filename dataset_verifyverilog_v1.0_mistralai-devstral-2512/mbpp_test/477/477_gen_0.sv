module ascii_to_lowercase(
    input [7:0] string_in [0:7],
    output [7:0] string_out [0:7]
);

    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            if (string_in[i] >= 8'd65 && string_in[i] <= 8'd90) begin
                string_out[i] = string_in[i] | 8'd32;
            end else begin
                string_out[i] = string_in[i];
            end
        end
    end

endmodule