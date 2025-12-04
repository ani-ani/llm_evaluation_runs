module frequency_counter(input [7:0] x, input [7:0] list_array [7:0], output [3:0] count);
  wire [7:0] matches;
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_compare
      assign matches[i] = (list_array[i] == x);
    end
  endgenerate
  assign count = matches[0] + matches[1] + matches[2] + matches[3] + matches[4] + matches[5] + matches[6] + matches[7];
endmodule