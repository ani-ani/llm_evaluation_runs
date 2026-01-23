module eat_carrots(
  input [7:0] number,
  input [7:0] need,
  input [7:0] remaining,
  output [7:0] total_eaten,
  output [7:0] left_over
);

  assign total_eaten = (need <= remaining) ? (number + need) : (number + remaining);
  assign left_over = (need <= remaining) ? (remaining - need) : 0;

endmodule