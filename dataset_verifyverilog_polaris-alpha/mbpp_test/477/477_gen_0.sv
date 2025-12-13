module string_to_lower(
  input  [63:0] string_in,
  output [63:0] string_out
);

  wire [7:0] c0 = string_in[63:56];
  wire [7:0] c1 = string_in[55:48];
  wire [7:0] c2 = string_in[47:40];
  wire [7:0] c3 = string_in[39:32];
  wire [7:0] c4 = string_in[31:24];
  wire [7:0] c5 = string_in[23:16];
  wire [7:0] c6 = string_in[15:8];
  wire [7:0] c7 = string_in[7:0];

  function automatic [7:0] to_lower(input [7:0] ch);
    begin
      if (ch >= 8'd65 && ch <= 8'd90)
        to_lower = ch + 8'd32;
      else
        to_lower = ch;
    end
  endfunction

  assign string_out[63:56] = to_lower(c0);
  assign string_out[55:48] = to_lower(c1);
  assign string_out[47:40] = to_lower(c2);
  assign string_out[39:32] = to_lower(c3);
  assign string_out[31:24] = to_lower(c4);
  assign string_out[23:16] = to_lower(c5);
  assign string_out[15:8]  = to_lower(c6);
  assign string_out[7:0]   = to_lower(c7);

endmodule