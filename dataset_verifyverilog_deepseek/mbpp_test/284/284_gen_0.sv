module element_checker (
  input [7:0] elem,
  input [7:0] item0,
  input [7:0] item1,
  input [7:0] item2,
  input [7:0] item3,
  output wire all_match
);
  assign all_match = (item0 == elem) && 
                    (item1 == elem) && 
                    (item2 == elem) && 
                    (item3 == elem);
endmodule