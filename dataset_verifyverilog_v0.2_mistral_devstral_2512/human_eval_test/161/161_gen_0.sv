module string_transform (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  output [7:0] out_0,
  output [7:0] out_1,
  output [7:0] out_2,
  output [7:0] out_3,
  output [7:0] out_4,
  output [7:0] out_5,
  output [7:0] out_6,
  output [7:0] out_7
);

  wire has_letter = 
    (char_0 >= 8'h41 && char_0 <= 8'h5A) || (char_0 >= 8'h61 && char_0 <= 8'h7A) ||
    (char_1 >= 8'h41 && char_1 <= 8'h5A) || (char_1 >= 8'h61 && char_1 <= 8'h7A) ||
    (char_2 >= 8'h41 && char_2 <= 8'h5A) || (char_2 >= 8'h61 && char_2 <= 8'h7A) ||
    (char_3 >= 8'h41 && char_3 <= 8'h5A) || (char_3 >= 8'h61 && char_3 <= 8'h7A) ||
    (char_4 >= 8'h41 && char_4 <= 8'h5A) || (char_4 >= 8'h61 && char_4 <= 8'h7A) ||
    (char_5 >= 8'h41 && char_5 <= 8'h5A) || (char_5 >= 8'h61 && char_5 <= 8'h7A) ||
    (char_6 >= 8'h41 && char_6 <= 8'h5A) || (char_6 >= 8'h61 && char_6 <= 8'h7A) ||
    (char_7 >= 8'h41 && char_7 <= 8'h5A) || (char_7 >= 8'h61 && char_7 <= 8'h7A);

  assign out_0 = has_letter ? 
    ((char_0 >= 8'h41 && char_0 <= 8'h5A) ? (char_0 + 8'h20) : 
     (char_0 >= 8'h61 && char_0 <= 8'h7A) ? (char_0 - 8'h20) : char_0) : char_7;
  assign out_1 = has_letter ? 
    ((char_1 >= 8'h41 && char_1 <= 8'h5A) ? (char_1 + 8'h20) : 
     (char_1 >= 8'h61 && char_1 <= 8'h7A) ? (char_1 - 8'h20) : char_1) : char_6;
  assign out_2 = has_letter ? 
    ((char_2 >= 8'h41 && char_2 <= 8'h5A) ? (char_2 + 8'h20) : 
     (char_2 >= 8'h61 && char_2 <= 8'h7A) ? (char_2 - 8'h20) : char_2) : char_5;
  assign out_3 = has_letter ? 
    ((char_3 >= 8'h41 && char_3 <= 8'h5A) ? (char_3 + 8'h20) : 
     (char_3 >= 8'h61 && char_3 <= 8'h7A) ? (char_3 - 8'h20) : char_3) : char_4;
  assign out_4 = has_letter ? 
    ((char_4 >= 8'h41 && char_4 <= 8'h5A) ? (char_4 + 8'h20) : 
     (char_4 >= 8'h61 && char_4 <= 8'h7A) ? (char_4 - 8'h20) : char_4) : char_3;
  assign out_5 = has_letter ? 
    ((char_5 >= 8'h41 && char_5 <= 8'h5A) ? (char_5 + 8'h20) : 
     (char_5 >= 8'h61 && char_5 <= 8'h7A) ? (char_5 - 8'h20) : char_5) : char_2;
  assign out_6 = has_letter ? 
    ((char_6 >= 8'h41 && char_6 <= 8'h5A) ? (char_6 + 8'h20) : 
     (char_6 >= 8'h61 && char_6 <= 8'h7A) ? (char_6 - 8'h20) : char_6) : char_1;
  assign out_7 = has_letter ? 
    ((char_7 >= 8'h41 && char_7 <= 8'h5A) ? (char_7 + 8'h20) : 
     (char_7 >= 8'h61 && char_7 <= 8'h7A) ? (char_7 - 8'h20) : char_7) : char_0;

endmodule