module statue_rotator(
  input [7:0][2:0] a,
  input [7:0][2:0] b,
  output reg possible
);
  
  wire [2:0] a_zero_pos, b_zero_pos;
  wire [6:0][2:0] a_nz, b_nz;
  wire found;
  wire [2:0] pos_in_a;
  
  // Find zero positions
  assign a_zero_pos = (a[0]==0) ? 0 :
                     (a[1]==0) ? 1 :
                     (a[2]==0) ? 2 :
                     (a[3]==0) ? 3 :
                     (a[4]==0) ? 4 :
                     (a[5]==0) ? 5 :
                     (a[6]==0) ? 6 : 7;
  assign b_zero_pos = (b[0]==0) ? 0 :
                     (b[1]==0) ? 1 :
                     (b[2]==0) ? 2 :
                     (b[3]==0) ? 3 :
                     (b[4]==0) ? 4 :
                     (b[5]==0) ? 5 :
                     (b[6]==0) ? 6 : 7;
  
  // Generate a_nz and b_nz arrays (7 elements without zero)
  genvar j;
  generate
    for(j=0; j<7; j=j+1) begin : gen_nz
      assign a_nz[j] = a[(a_zero_pos + 3'd1 + j[2:0]) % 3'd8];
      assign b_nz[j] = b[(b_zero_pos + 3'd1 + j[2:0]) % 3'd8];
    end
  endgenerate
  
  // Find position of b_nz[0] in a_nz
  integer i;
  always_comb begin
    found = 0;
    pos_in_a = 0;
    for(i=0; i<7; i=i+1) begin
      if(a_nz[i] == b_nz[0]) begin
        found = 1;
        pos_in_a = i[2:0];
      end
    end
  end
  
  // Create rotated version of a_nz
  wire [6:0][2:0] rotated_a_nz;
  genvar k;
  generate
    for(k=0; k<7; k=k+1) begin : rotate
      wire [3:0] sum = pos_in_a + k[2:0];
      assign rotated_a_nz[k] = a_nz[sum[2:0] - (sum >= 7 ? 4'd7 : 4'd0)];
    end
  endgenerate
  
  // Check equality and set output
  integer m;
  reg equal;
  always_comb begin
    equal = 1;
    for(m=0; m<7; m=m+1) begin
      if(rotated_a_nz[m] != b_nz[m]) begin
        equal = 0;
      end
    end
    possible = found && equal;
  end
endmodule