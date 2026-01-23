module basin_city_drones (
input [7:0] k,
input [7:0] n,
input [7:0] adj_0, adj_1, adj_2, adj_3, adj_4, adj_5, adj_6, adj_7,
output reg possible
);

reg [7:0] mask_n;
always @(*) begin
   case (n)
      1: mask_n = 1;
      2: mask_n = 3;
      3: mask_n = 7;
      4: mask_n = 15;
      5: mask_n = 31;
      6: mask_n = 63;
      7: mask_n = 127;
      8: mask_n = 255;
      default: mask_n = 0;
   endcase
end

function automatic integer popcount;
   input [7:0] x;
   popcount = x[0] + x[1] + x[2] + x[3] + x[4] + x[5] + x[6] + x[7];
endfunction

always @(*) begin
   possible = 0;
   for (integer P=0; P<256; P=P+1) begin
      wire [7:0] p_n = P & mask_n;
      integer count = popcount(p_n);
      if (count != k) begin
      end else begin
         integer valid = 1;
         for (integer i=0; i<n; i=i+1) begin
            if (P[i]) begin
               case (i)
                  0: if ( (P & adj_0) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
                  1: if ( (P & adj_1) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
                  2: if ( (P & adj_2) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
                  3: if ( (P & adj_3) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
                  4: if ( (P & adj_4) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
                  5: if ( (P & adj_5) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
                  6: if ( (P & adj_6) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
                  7: if ( (P & adj_7) & mask_n !=0 ) begin
                        valid =0;
                        break;
                      end
               endcase
            end
         end
         if (valid) begin
            possible = 1;
         end
      end
   end
end

endmodule