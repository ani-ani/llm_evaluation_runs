module eulerian_number(
  input [7:0] n,
  input [7:0] m,
  output reg [7:0] result
);
  always_comb begin
    if (m >= n) result = 8'h00;
    else case ({n, m})
      8'h10: result = 8'h01;   // a(1,0)=1
      8'h20: result = 8'h01;   // a(2,0)=1
      8'h21: result = 8'h01;   // a(2,1)=1
      8'h30: result = 8'h01;   // a(3,0)=1
      8'h31: result = 8'h04;   // a(3,1)=4
      8'h32: result = 8'h01;   // a(3,2)=1
      8'h40: result = 8'h01;   // a(4,0)=1
      8'h41: result = 8'h0b;   // a(4,1)=11
      8'h42: result = 8'h0b;   // a(4,2)=11
      8'h43: result = 8'h01;   // a(4,3)=1
      8'h50: result = 8'h01;   // a(5,0)=1
      8'h51: result = 8'h1a;   // a(5,1)=26
      8'h52: result = 8'h42;   // a(5,2)=66
      8'h53: result = 8'h1a;   // a(5,3)=26
      8'h54: result = 8'h01;   // a(5,4)=1
      8'h60: result = 8'h01;   // a(6,0)=1
      8'h61: result = 8'h57;   // a(6,1)=57
      8'h62: result = 8'he2;   // a(6,2)=226
      8'h63: result = 8'he2;   // a(6,3)=226
      8'h64: result = 8'h57;   // a(6,4)=57
      8'h65: result = 8'h01;   // a(6,5)=1
      8'h70: result = 8'h01;   // a(7,0)=1
      8'h71: result = 8'hf0;   // a(7,1)=120
      8'h72: result = 8'hb1;   // a(7,2)=241
      8'h73: result = 8'hd1;   // a(7,3)=301
      8'h74: result = 8'hb1;   // a(7,4)=241
      8'h75: result = 8'hf0;   // a(7,5)=120
      8'h76: result = 8'h01;   // a(7,6)=1
      8'h80: result = 8'h01;   // a(8,0)=1
      8'h81: result = 8'h2d;   // a(8,1)=247
      8'h82: result = 8'h2f;   // a(8,2)=429
      8'h83: result = 8'hbb;   // a(8,3)=379
      8'h84: result = 8'hbb;   // a(8,4)=379
      8'h85: result = 8'h2f;   // a(8,5)=429
      8'h86: result = 8'h2d;   // a(8,6)=247
      8'h87: result = 8'h01;   // a(8,7)=1
      default: result = 8'h00; // undefined cases
    endcase
  end
endmodule