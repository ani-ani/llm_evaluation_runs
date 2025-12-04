module string_length_filter(
  input  [7:0]   str_length,
  input  [127:0] str0,
  input  [127:0] str1,
  input  [127:0] str2,
  input  [127:0] str3,
  input  [127:0] str4,
  input  [127:0] str5,
  input  [127:0] str6,
  input  [127:0] str7,
  output [7:0]   valid_mask,
  output [127:0] filtered0,
  output [127:0] filtered1,
  output [127:0] filtered2,
  output [127:0] filtered3,
  output [127:0] filtered4,
  output [127:0] filtered5,
  output [127:0] filtered6,
  output [127:0] filtered7
);

  function automatic [7:0] count_nonzero_bytes(input [127:0] s);
    integer i;
    reg [7:0] cnt;
    begin
      cnt = 8'd0;
      for (i = 0; i < 16; i = i + 1) begin
        if (s[i*8 +: 8] != 8'd0)
          cnt = cnt + 8'd1;
      end
      count_nonzero_bytes = cnt;
    end
  endfunction

  wire [7:0] len0 = count_nonzero_bytes(str0);
  wire [7:0] len1 = count_nonzero_bytes(str1);
  wire [7:0] len2 = count_nonzero_bytes(str2);
  wire [7:0] len3 = count_nonzero_bytes(str3);
  wire [7:0] len4 = count_nonzero_bytes(str4);
  wire [7:0] len5 = count_nonzero_bytes(str5);
  wire [7:0] len6 = count_nonzero_bytes(str6);
  wire [7:0] len7 = count_nonzero_bytes(str7);

  assign valid_mask[0] = (len0 == str_length);
  assign valid_mask[1] = (len1 == str_length);
  assign valid_mask[2] = (len2 == str_length);
  assign valid_mask[3] = (len3 == str_length);
  assign valid_mask[4] = (len4 == str_length);
  assign valid_mask[5] = (len5 == str_length);
  assign valid_mask[6] = (len6 == str_length);
  assign valid_mask[7] = (len7 == str_length);

  assign filtered0 = valid_mask[0] ? str0 : 128'd0;
  assign filtered1 = valid_mask[1] ? str1 : 128'd0;
  assign filtered2 = valid_mask[2] ? str2 : 128'd0;
  assign filtered3 = valid_mask[3] ? str3 : 128'd0;
  assign filtered4 = valid_mask[4] ? str4 : 128'd0;
  assign filtered5 = valid_mask[5] ? str5 : 128'd0;
  assign filtered6 = valid_mask[6] ? str6 : 128'd0;
  assign filtered7 = valid_mask[7] ? str7 : 128'd0;

endmodule