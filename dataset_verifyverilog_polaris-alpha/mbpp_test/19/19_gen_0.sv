module duplicate_checker(
  input  [7:0] array [0:7],
  output       has_duplicate
);

  assign has_duplicate =
    (array[0] == array[1]) || (array[0] == array[2]) || (array[0] == array[3]) || (array[0] == array[4]) || (array[0] == array[5]) || (array[0] == array[6]) || (array[0] == array[7]) ||
    (array[1] == array[2]) || (array[1] == array[3]) || (array[1] == array[4]) || (array[1] == array[5]) || (array[1] == array[6]) || (array[1] == array[7]) ||
    (array[2] == array[3]) || (array[2] == array[4]) || (array[2] == array[5]) || (array[2] == array[6]) || (array[2] == array[7]) ||
    (array[3] == array[4]) || (array[3] == array[5]) || (array[3] == array[6]) || (array[3] == array[7]) ||
    (array[4] == array[5]) || (array[4] == array[6]) || (array[4] == array[7]) ||
    (array[5] == array[6]) || (array[5] == array[7]) ||
    (array[6] == array[7]);

endmodule