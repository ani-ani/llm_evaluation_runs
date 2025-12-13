module remove_kth_element(
  input  [79:0] array_in,
  input  [4:0]  k,
  output [79:0] array_out
);

  wire [4:0] e [15:0];
  wire [4:0] o [15:0];

  // Unpack input into 16 elements of 5 bits
  assign e[0]  = array_in[79:75];
  assign e[1]  = array_in[74:70];
  assign e[2]  = array_in[69:65];
  assign e[3]  = array_in[64:60];
  assign e[4]  = array_in[59:55];
  assign e[5]  = array_in[54:50];
  assign e[6]  = array_in[49:45];
  assign e[7]  = array_in[44:40];
  assign e[8]  = array_in[39:35];
  assign e[9]  = array_in[34:30];
  assign e[10] = array_in[29:25];
  assign e[11] = array_in[24:20];
  assign e[12] = array_in[19:15];
  assign e[13] = array_in[14:10];
  assign e[14] = array_in[9:5];
  assign e[15] = array_in[4:0];

  // If k in [1..16], remove k-th element (1-based) by shifting left
  // o[i] = e[i] for i < k-1, o[i] = e[i+1] for i >= k-1, with last element duplicated from e[15]
  // If k > 16 (or 0), pass-through original array

  // Element 0
  assign o[0]  = (k >= 5'd1  && k <= 5'd16) ? e[0]  : e[0];
  // Element 1
  assign o[1]  = (k == 5'd1)                  ? e[2]  :
                 (k > 5'd1  && k <= 5'd16)    ? e[1]  :
                                              e[1];
  // Element 2
  assign o[2]  = (k == 5'd1)                  ? e[3]  :
                 (k == 5'd2)                  ? e[3]  :
                 (k > 5'd2  && k <= 5'd16)    ? e[2]  :
                                              e[2];
  // Element 3
  assign o[3]  = (k == 5'd1)                  ? e[4]  :
                 (k == 5'd2)                  ? e[4]  :
                 (k == 5'd3)                  ? e[4]  :
                 (k > 5'd3  && k <= 5'd16)    ? e[3]  :
                                              e[3];
  // Element 4
  assign o[4]  = (k == 5'd1)                  ? e[5]  :
                 (k == 5'd2)                  ? e[5]  :
                 (k == 5'd3)                  ? e[5]  :
                 (k == 5'd4)                  ? e[5]  :
                 (k > 5'd4  && k <= 5'd16)    ? e[4]  :
                                              e[4];
  // Element 5
  assign o[5]  = (k == 5'd1)                  ? e[6]  :
                 (k == 5'd2)                  ? e[6]  :
                 (k == 5'd3)                  ? e[6]  :
                 (k == 5'd4)                  ? e[6]  :
                 (k == 5'd5)                  ? e[6]  :
                 (k > 5'd5  && k <= 5'd16)    ? e[5]  :
                                              e[5];
  // Element 6
  assign o[6]  = (k == 5'd1)                  ? e[7]  :
                 (k == 5'd2)                  ? e[7]  :
                 (k == 5'd3)                  ? e[7]  :
                 (k == 5'd4)                  ? e[7]  :
                 (k == 5'd5)                  ? e[7]  :
                 (k == 5'd6)                  ? e[7]  :
                 (k > 5'd6  && k <= 5'd16)    ? e[6]  :
                                              e[6];
  // Element 7
  assign o[7]  = (k == 5'd1)                  ? e[8]  :
                 (k == 5'd2)                  ? e[8]  :
                 (k == 5'd3)                  ? e[8]  :
                 (k == 5'd4)                  ? e[8]  :
                 (k == 5'd5)                  ? e[8]  :
                 (k == 5'd6)                  ? e[8]  :
                 (k == 5'd7)                  ? e[8]  :
                 (k > 5'd7  && k <= 5'd16)    ? e[7]  :
                                              e[7];
  // Element 8
  assign o[8]  = (k == 5'd1)                  ? e[9]  :
                 (k == 5'd2)                  ? e[9]  :
                 (k == 5'd3)                  ? e[9]  :
                 (k == 5'd4)                  ? e[9]  :
                 (k == 5'd5)                  ? e[9]  :
                 (k == 5'd6)                  ? e[9]  :
                 (k == 5'd7)                  ? e[9]  :
                 (k == 5'd8)                  ? e[9]  :
                 (k > 5'd8  && k <= 5'd16)    ? e[8]  :
                                              e[8];
  // Element 9
  assign o[9]  = (k == 5'd1)                  ? e[10] :
                 (k == 5'd2)                  ? e[10] :
                 (k == 5'd3)                  ? e[10] :
                 (k == 5'd4)                  ? e[10] :
                 (k == 5'd5)                  ? e[10] :
                 (k == 5'd6)                  ? e[10] :
                 (k == 5'd7)                  ? e[10] :
                 (k == 5'd8)                  ? e[10] :
                 (k == 5'd9)                  ? e[10] :
                 (k > 5'd9  && k <= 5'd16)    ? e[9]  :
                                              e[9];
  // Element 10
  assign o[10] = (k == 5'd1)                  ? e[11] :
                 (k == 5'd2)                  ? e[11] :
                 (k == 5'd3)                  ? e[11] :
                 (k == 5'd4)                  ? e[11] :
                 (k == 5'd5)                  ? e[11] :
                 (k == 5'd6)                  ? e[11] :
                 (k == 5'd7)                  ? e[11] :
                 (k == 5'd8)                  ? e[11] :
                 (k == 5'd9)                  ? e[11] :
                 (k == 5'd10)                 ? e[11] :
                 (k > 5'd10 && k <= 5'd16)    ? e[10] :
                                              e[10];
  // Element 11
  assign o[11] = (k == 5'd1)                  ? e[12] :
                 (k == 5'd2)                  ? e[12] :
                 (k == 5'd3)                  ? e[12] :
                 (k == 5'd4)                  ? e[12] :
                 (k == 5'd5)                  ? e[12] :
                 (k == 5'd6)                  ? e[12] :
                 (k == 5'd7)                  ? e[12] :
                 (k == 5'd8)                  ? e[12] :
                 (k == 5'd9)                  ? e[12] :
                 (k == 5'd10)                 ? e[12] :
                 (k == 5'd11)                 ? e[12] :
                 (k > 5'd11 && k <= 5'd16)    ? e[11] :
                                              e[11];
  // Element 12
  assign o[12] = (k == 5'd1)                  ? e[13] :
                 (k == 5'd2)                  ? e[13] :
                 (k == 5'd3)                  ? e[13] :
                 (k == 5'd4)                  ? e[13] :
                 (k == 5'd5)                  ? e[13] :
                 (k == 5'd6)                  ? e[13] :
                 (k == 5'd7)                  ? e[13] :
                 (k == 5'd8)                  ? e[13] :
                 (k == 5'd9)                  ? e[13] :
                 (k == 5'd10)                 ? e[13] :
                 (k == 5'd11)                 ? e[13] :
                 (k == 5'd12)                 ? e[13] :
                 (k > 5'd12 && k <= 5'd16)    ? e[12] :
                                              e[12];
  // Element 13
  assign o[13] = (k == 5'd1)                  ? e[14] :
                 (k == 5'd2)                  ? e[14] :
                 (k == 5'd3)                  ? e[14] :
                 (k == 5'd4)                  ? e[14] :
                 (k == 5'd5)                  ? e[14] :
                 (k == 5'd6)                  ? e[14] :
                 (k == 5'd7)                  ? e[14] :
                 (k == 5'd8)                  ? e[14] :
                 (k == 5'd9)                  ? e[14] :
                 (k == 5'd10)                 ? e[14] :
                 (k == 5'd11)                 ? e[14] :
                 (k == 5'd12)                 ? e[14] :
                 (k == 5'd13)                 ? e[14] :
                 (k > 5'd13 && k <= 5'd16)    ? e[13] :
                                              e[13];
  // Element 14
  assign o[14] = (k == 5'd1)                  ? e[15] :
                 (k == 5'd2)                  ? e[15] :
                 (k == 5'd3)                  ? e[15] :
                 (k == 5'd4)                  ? e[15] :
                 (k == 5'd5)                  ? e[15] :
                 (k == 5'd6)                  ? e[15] :
                 (k == 5'd7)                  ? e[15] :
                 (k == 5'd8)                  ? e[15] :
                 (k == 5'd9)                  ? e[15] :
                 (k == 5'd10)                 ? e[15] :
                 (k == 5'd11)                 ? e[15] :
                 (k == 5'd12)                 ? e[15] :
                 (k == 5'd13)                 ? e[15] :
                 (k == 5'd14)                 ? e[15] :
                 (k > 5'd14 && k <= 5'd16)    ? e[14] :
                                              e[14];
  // Element 15 (last): if removed index <=15, duplicate e[15]; if k==16, o[15]=e[15-1];
  assign o[15] = (k == 5'd1)                  ? e[15] :
                 (k == 5'd2)                  ? e[15] :
                 (k == 5'd3)                  ? e[15] :
                 (k == 5'd4)                  ? e[15] :
                 (k == 5'd5)                  ? e[15] :
                 (k == 5'd6)                  ? e[15] :
                 (k == 5'd7)                  ? e[15] :
                 (k == 5'd8)                  ? e[15] :
                 (k == 5'd9)                  ? e[15] :
                 (k == 5'd10)                 ? e[15] :
                 (k == 5'd11)                 ? e[15] :
                 (k == 5'd12)                 ? e[15] :
                 (k == 5'd13)                 ? e[15] :
                 (k == 5'd14)                 ? e[15] :
                 (k == 5'd15)                 ? e[15] :
                 (k == 5'd16)                 ? e[15] :
                                              e[15];

  // For k > 16 or k == 0, we want pass-through. Above logic already defaults to e[i].

  // Repack output
  assign array_out = { o[0], o[1], o[2], o[3], o[4], o[5], o[6], o[7],
                       o[8], o[9], o[10], o[11], o[12], o[13], o[14], o[15] };

endmodule