module flip_case(
  input  [127:0] string_in,
  output [127:0] string_out
);

  function automatic [7:0] flip_byte_case(input [7:0] c);
    begin
      if ((c >= 8'h61) && (c <= 8'h7A)) begin
        flip_byte_case = c ^ 8'h20; // lowercase to uppercase
      end else if ((c >= 8'h41) && (c <= 8'h5A)) begin
        flip_byte_case = c ^ 8'h20; // uppercase to lowercase
      end else begin
        flip_byte_case = c;         // non-alphabet unchanged
      end
    end
  endfunction

  assign string_out[7:0]     = flip_byte_case(string_in[7:0]);
  assign string_out[15:8]    = flip_byte_case(string_in[15:8]);
  assign string_out[23:16]   = flip_byte_case(string_in[23:16]);
  assign string_out[31:24]   = flip_byte_case(string_in[31:24]);
  assign string_out[39:32]   = flip_byte_case(string_in[39:32]);
  assign string_out[47:40]   = flip_byte_case(string_in[47:40]);
  assign string_out[55:48]   = flip_byte_case(string_in[55:48]);
  assign string_out[63:56]   = flip_byte_case(string_in[63:56]);
  assign string_out[71:64]   = flip_byte_case(string_in[71:64]);
  assign string_out[79:72]   = flip_byte_case(string_in[79:72]);
  assign string_out[87:80]   = flip_byte_case(string_in[87:80]);
  assign string_out[95:88]   = flip_byte_case(string_in[95:88]);
  assign string_out[103:96]  = flip_byte_case(string_in[103:96]);
  assign string_out[111:104] = flip_byte_case(string_in[111:104]);
  assign string_out[119:112] = flip_byte_case(string_in[119:112]);
  assign string_out[127:120] = flip_byte_case(string_in[127:120]);

endmodule