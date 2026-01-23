module string_encrypt (
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    input [2:0] length,
    output reg [7:0] enc_0, enc_1, enc_2, enc_3, enc_4, enc_5, enc_6, enc_7
);

    // Helper to encrypt a single character
    function [7:0] encrypt_char;
        input [7:0] c;
        reg [7:0] temp;
        begin
            if (c >= 8'h61 && c <= 8'h7A) begin
                temp = c + 8'h04;
                if (temp > 8'h7A)
                    encrypt_char = temp - 8'h1A;
                else
                    encrypt_char = temp;
            end else begin
                encrypt_char = c;
            end
        end
    endfunction

    always @(*) begin
        // Default all outputs to 0 (for positions >= length)
        enc_0 = 8'h00;
        enc_1 = 8'h00;
        enc_2 = 8'h00;
        enc_3 = 8'h00;
        enc_4 = 8'h00;
        enc_5 = 8'h00;
        enc_6 = 8'h00;
        enc_7 = 8'h00;

        // Encrypt based on length
        if (length > 0) enc_0 = encrypt_char(char_0);
        if (length > 1) enc_1 = encrypt_char(char_1);
        if (length > 2) enc_2 = encrypt_char(char_2);
        if (length > 3) enc_3 = encrypt_char(char_3);
        if (length > 4) enc_4 = encrypt_char(char_4);
        if (length > 5) enc_5 = encrypt_char(char_5);
        if (length > 6) enc_6 = encrypt_char(char_6);
        if (length > 7) enc_7 = encrypt_char(char_7);
    end

endmodule