module max_triples(input [3:0] n, output reg [15:0] count);
parameter integer a[1:8] = {1,3,7,13,21,31,43,57};
always @(*) begin
   int cnt, i, j, k;
   cnt = 0;
   for (i = 1; i <= n; i++) begin
      for (j = i + 1; j <= n; j++) begin
         for (k = j + 1; k <= n; k++) begin
            if ((a[i] + a[j] + a[k]) % 3 == 0)
               cnt = cnt + 1;
         end
      end
   end
   count = cnt;
end
endmodule