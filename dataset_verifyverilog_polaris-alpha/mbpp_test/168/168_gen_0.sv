module frequency_counter(
  input  [7:0] x,
  input  [7:0] list_array [7:0],
  output [3:0] count
);

  wire [7:0] match;

  assign match[0] = (list_array[0] == x);
  assign match[1] = (list_array[1] == x);
  assign match[2] = (list_array[2] == x);
  assign match[3] = (list_array[3] == x);
  assign match[4] = (list_array[4] == x);
  assign match[5] = (list_array[5] == x);
  assign match[6] = (list_array[6] == x);
  assign match[7] = (list_array[7] == x);

  assign count = match[0] + match[1] + match[2] + match[3]
               + match[4] + match[5] + match[6] + match[7];

endmodule