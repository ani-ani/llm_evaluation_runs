module string_encrypt (
  input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
  input [2:0] length,
  output reg [7:0] enc_0, enc_1, enc_2, enc_3, enc_4, enc_5, enc_6, enc_7
);

  always @* begin
    // Default all outputs to 0
    enc_0 = 8'h00;
    enc_1 = 8'h00;
    enc_2 = 8'h00;
    enc_3 = 8'h00;
    enc_4 = 8'h00;
    enc_5 = 8'h00;
    enc_6 = 8'h00;
    enc_7 = 8'h00;

    // Process each character based on length
    if (length >= 1) begin
      enc_0 = process_char(char_0);
    end
    if (length >= 2) begin
      enc_1 = process_char(char_1);
    end
    if (length >= 3) begin
      enc_2 = process_char(char_2);
    end
    if (length >= 4) begin
      enc_3 = process_char(char_3);
    end
    if (length >= 5) begin
      enc_4 = process_char(char_4);
    end
    if (length >= 6) begin
      enc_5 = process_char(char_5);
    end
    if (length >= 7) begin
      enc_6 = process_char(char_6);
    end
    if (length >= 8) begin
      enc_7 = process_char(char_7);
    end
  end

  // Function to process a single character
  function [7:0] process_char;
    input [7:0] c;
    begin
      if (c >= 8'h61 && c <= 8'h7A) begin
        process_char = c + 4;
        if (process_char > 8'h7A) begin
          process_char = process_char - 26;
        end
      end
      else begin
        process_char = c;
      end
    end
  endfunction

endmodule