module filter_odds(input [7:0] data [0:7], output [7:0] result [0:7], output [7:0] valid_mask);
  wire [7:0] odd_bits;
  wire [3:0] count [0:8];
  wire [3:0] total_odds;

  assign count[0] = 4'd0;
  generate
    for (genvar i = 0; i < 8; i++) begin
      assign odd_bits[i] = data[i][0];
      assign count[i+1] = count[i] + {3'b0, odd_bits[i]};
    end
  endgenerate

  assign total_odds = count[8];
  assign valid_mask = (8'b1 << total_odds) - 8'b1;

  generate
    for (genvar j = 0; j < 8; j++) begin
      wire [7:0] temp [0:8];
      for (genvar i = 0; i < 8; i++) begin
        assign temp[i] = ({4{count[i] == j}} & {8{odd_bits[i]}}) ? data[i] : 8'b0;
      end
      assign result[j] = temp[0] | temp[1] | temp[2] | temp[3] | temp[4] | temp[5] | temp[6] | temp[7];
    end
  endgenerate
endmodule