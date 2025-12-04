module extract_rear (
  input  [63:0] str0, str1, str2, str3,
  input  [2:0]  len0, len1, len2, len3,
  output logic [7:0] rear0, rear1, rear2, rear3
);

  always_comb begin
    case (len0)
      3'd0: rear0 = 8'd0;
      3'd1: rear0 = str0[63:56];
      3'd2: rear0 = str0[55:48];
      3'd3: rear0 = str0[47:40];
      3'd4: rear0 = str0[39:32];
      3'd5: rear0 = str0[31:24];
      3'd6: rear0 = str0[23:16];
      3'd7: rear0 = str0[15:8];
      default: rear0 = 8'd0;
    endcase

    case (len1)
      3'd0: rear1 = 8'd0;
      3'd1: rear1 = str1[63:56];
      3'd2: rear1 = str1[55:48];
      3'd3: rear1 = str1[47:40];
      3'd4: rear1 = str1[39:32];
      3'd5: rear1 = str1[31:24];
      3'd6: rear1 = str1[23:16];
      3'd7: rear1 = str1[15:8];
      default: rear1 = 8'd0;
    endcase

    case (len2)
      3'd0: rear2 = 8'd0;
      3'd1: rear2 = str2[63:56];
      3'd2: rear2 = str2[55:48];
      3'd3: rear2 = str2[47:40];
      3'd4: rear2 = str2[39:32];
      3'd5: rear2 = str2[31:24];
      3'd6: rear2 = str2[23:16];
      3'd7: rear2 = str2[15:8];
      default: rear2 = 8'd0;
    endcase

    case (len3)
      3'd0: rear3 = 8'd0;
      3'd1: rear3 = str3[63:56];
      3'd2: rear3 = str3[55:48];
      3'd3: rear3 = str3[47:40];
      3'd4: rear3 = str3[39:32];
      3'd5: rear3 = str3[31:24];
      3'd6: rear3 = str3[23:16];
      3'd7: rear3 = str3[15:8];
      default: rear3 = 8'd0;
    endcase
  end
endmodule