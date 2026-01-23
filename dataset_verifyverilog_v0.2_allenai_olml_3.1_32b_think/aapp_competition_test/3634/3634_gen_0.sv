module sensor_placement (
    input [5:0] a [0:7],
    input [5:0] b [0:7],
    input [2:0] n,
    output [31:0] ways
);

generate 
   for (int i=0; i<8; i++) begin
      assign active_i##i = (n > i);
   end
endgenerate

generate 
   for (int x=0; x<64; x++) begin: x_loop
      generate
         for (int i=0; i<8; i++) begin
            assign term_i##i##x = active_i##i & (a[i] <= x) & (x <= b[i]);
         end
      endgenerate
      assign level_x##x = term_i0##x + term_i1##x + term_i2##x + term_i3##x + term_i4##x + term_i5##x + term_i6##x + term_i7##x;
   end
endgenerate

generate 
   for (int l=0; l<=8; l++) begin: level_loop
      assign count_level##l = 0;
      generate
         for (int x=0; x<64; x++) begin
            assign temp##l##x = (level_x##x == l) ? 1'b1 : 1'b0;
         end
      endgenerate
      assign count_level##l = temp##l0 + temp##l1 + temp##l2 + temp##l3 + temp##l4 + temp##l5 + temp##l6 + temp##l7 + 
                           temp##l8 + temp##l9 + temp##l10 + temp##l11 + temp##l12 + temp##l13 + temp##l14 + temp##l15 + 
                           temp##l16 + temp##l17 + temp##l18 + temp##l19 + temp##l20 + temp##l21 + temp##l22 + temp##l23 + 
                           temp##l24 + temp##l25 + temp##l26 + temp##l27 + temp##l28 + temp##l29 + temp##l30 + temp##l31 + 
                           temp##l32 + temp##l33 + temp##l34 + temp##l35 + temp##l36 + temp##l37 + temp##l38 + temp##l39 + 
                           temp##l40 + temp##l41 + temp##l42 + temp##l43 + temp##l44 + temp##l45 + temp##l46 + temp##l47 + 
                           temp##l48 + temp##l49 + temp##l50 + temp##l51 + temp##l52 + temp##l53 + temp##l54 + temp##l55 + 
                           temp##l56 + temp##l57 + temp##l58 + temp##l59 + temp##l60 + temp##l61 + temp##l62 + temp##l63;
   end
endgenerate

assign ways = 
   (count_level0 * count_level1 * count_level2) + 
   (count_level0 * count_level1 * count_level3) + 
   (count_level0 * count_level1 * count_level4) + 
   (count_level0 * count_level1 * count_level5) + 
   (count_level0 * count_level1 * count_level6) + 
   (count_level0 * count_level1 * count_level7) + 
   (count_level0 * count_level1 * count_level8) + 
   (count_level0 * count_level2 * count_level3) + 
   (count_level0 * count_level2 * count_level4) + 
   (count_level0 * count_level2 * count_level5) + 
   (count_level0 * count_level2 * count_level6) + 
   (count_level0 * count_level2 * count_level7) + 
   (count_level0 * count_level2 * count_level8) + 
   (count_level0 * count_level3 * count_level4) + 
   (count_level0 * count_level3 * count_level5) + 
   (count_level0 * count_level3 * count_level6) + 
   (count_level0 * count_level3 * count_level7) + 
   (count_level0 * count_level3 * count_level8) + 
   (count_level0 * count_level4 * count_level5) + 
   (count_level0 * count_level4 * count_level6) + 
   (count_level0 * count_level4 * count_level7) + 
   (count_level0 * count_level4 * count_level8) + 
   (count_level0 * count_level5 * count_level6) + 
   (count_level0 * count_level5 * count_level7) + 
   (count_level0 * count_level5 * count_level8) + 
   (count_level0 * count_level6 * count_level7) + 
   (count_level0 * count_level6 * count_level8) + 
   (count_level0 * count_level7 * count_level8) + 
   (count_level1 * count_level2 * count_level3) + 
   (count_level1 * count_level2 * count_level4) + 
   (count_level1 * count_level2 * count_level5) + 
   (count_level1 * count_level2 * count_level6) + 
   (count_level1 * count_level2 * count_level7) + 
   (count_level1 * count_level2 * count_level8) + 
   (count_level1 * count_level3 * count_level4) + 
   (count_level1 * count_level3 * count_level5) + 
   (count_level1 * count_level3 * count_level6) + 
   (count_level1 * count_level3 * count_level7) + 
   (count_level1 * count_level3 * count_level8) + 
   (count_level1 * count_level4 * count_level5) + 
   (count_level1 * count_level4 * count_level6) + 
   (count_level1 * count_level4 * count_level7) + 
   (count_level1 * count_level4 * count_level8) + 
   (count_level1 * count_level5 * count_level6) + 
   (count_level1 * count_level5 * count_level7) + 
   (count_level1 * count_level5 * count_level8) + 
   (count_level1 * count_level6 * count_level7) + 
   (count_level1 * count_level6 * count_level8) + 
   (count_level1 * count_level7 * count_level8) + 
   (count_level2 * count_level3 * count_level4) + 
   (count_level2 * count_level3 * count_level5) + 
   (count_level2 * count_level3 * count_level6) + 
   (count_level2 * count_level3 * count_level7) + 
   (count_level2 * count_level3 * count_level8) + 
   (count_level2 * count_level4 * count_level5) + 
   (count_level2 * count_level4 * count_level6) + 
   (count_level2 * count_level4 * count_level7) + 
   (count_level2 * count_level4 * count_level8) + 
   (count_level2 * count_level5 * count_level6) + 
   (count_level2 * count_level5 * count_level7) + 
   (count_level2 * count_level5 * count_level8) + 
   (count_level2 * count_level6 * count_level7) + 
   (count_level2 * count_level6 * count_level8) + 
   (count_level2 * count_level7 * count_level8) + 
   (count_level3 * count_level4 * count_level5) + 
   (count_level3 * count_level4 * count_level6) + 
   (count_level3 * count_level4 * count_level7) + 
   (count_level3 * count_level4 * count_level8) + 
   (count_level3 * count_level5 * count_level6) + 
   (count_level3 * count_level5 * count_level7) + 
   (count_level3 * count_level5 * count_level8) + 
   (count_level3 * count_level6 * count_level7) + 
   (count_level3 * count_level6 * count_level8) + 
   (count_level3 * count_level7 * count_level8) + 
   (count_level4 * count_level5 * count_level6) + 
   (count_level4 * count_level5 * count_level7) + 
   (count_level4 * count_level5 * count_level8) + 
   (count_level4 * count_level6 * count_level7) + 
   (count_level4 * count_level6 * count_level8) + 
   (count_level4 * count_level7 * count_level8) + 
   (count_level5 * count_level6 * count_level7) + 
   (count_level5 * count_level6 * count_level8) + 
   (count_level5 * count_level7 * count_level8) + 
   (count_level6 * count_level7 * count_level8);
endmodule