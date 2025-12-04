module string_length_filter (
    input reg [7:0] str_length,
    input reg [127:0] str0, str1, str2, str3, str4, str5, str6, str7,
    output reg [7:0] valid_mask,
    output reg [127:0] filtered0, filtered1, filtered2, filtered3, filtered4, filtered5, filtered6, filtered7
);

reg [127:0] strings [0:7];
assign strings[0] = str0;
assign strings[1] = str1;
assign strings[2] = str2;
assign strings[3] = str3;
assign strings[4] = str4;
assign strings[5] = str5;
assign strings[6] = str6;
assign strings[7] = str7;

reg [127:0] filtered [0:7];
assign filtered0 = filtered[0];
assign filtered1 = filtered[1];
assign filtered2 = filtered[2];
assign filtered3 = filtered[3];
assign filtered4 = filtered[4];
assign filtered5 = filtered[5];
assign filtered6 = filtered[6];
assign filtered7 = filtered[7];

always_comb begin
    valid_mask = 0;
    for (int j = 0; j < 8; j++) begin
        filtered[j] = 0;
    end

    for (int j = 0; j < 8; j++) begin
        int len = 0;
        for (int i = 0; i < 16; i++) begin
            if (strings[j][8*i +: 8] == 0) break;
            len++;
        end
        if (len == str_length) begin
            valid_mask[j] = 1;
            filtered[j] = strings[j];
        end
    end
end

endmodule