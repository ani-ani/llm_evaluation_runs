module char_replacer (
  input [3:0] str_len,
  input [15:0][7:0] in_str,
  output logic [15:0][7:0] out_str
);
  always_comb begin
    for (int i=0; i<16; i++) begin
      if (i < str_len) begin
        case (in_str[i])
          8'h20, 8'h2C, 8'h2E: out_str[i] = 8'h3A;
          default: out_str[i] = in_str[i];
        endcase
      end else begin
        out_str[i] = 8'h00;
      end
    end
  end
endmodule