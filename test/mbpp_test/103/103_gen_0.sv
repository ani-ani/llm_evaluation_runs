module eulerian_number(
  input  [7:0] n,
  input  [7:0] m,
  output reg [7:0] result
);

  always_comb begin
    if (n == 0 || m >= n) begin
      result = 0;
    end else begin
      unique case ({n, m})
        // n = 1
        16'h0100: result = 8'd1;   // a(1,0)=1

        // n = 2
        16'h0200: result = 8'd1;   // a(2,0)=1
        16'h0201: result = 8'd1;   // a(2,1)=1

        // n = 3
        16'h0300: result = 8'd1;   // a(3,0)=1
        16'h0301: result = 8'd4;   // a(3,1)=4
        16'h0302: result = 8'd1;   // a(3,2)=1

        // n = 4
        16'h0400: result = 8'd1;   // a(4,0)=1
        16'h0401: result = 8'd11;  // a(4,1)=11
        16'h0402: result = 8'd11;  // a(4,2)=11
        16'h0403: result = 8'd1;   // a(4,3)=1

        // n = 5
        16'h0500: result = 8'd1;   // a(5,0)=1
        16'h0501: result = 8'd26;  // a(5,1)=26
        16'h0502: result = 8'd66;  // a(5,2)=66
        16'h0503: result = 8'd26;  // a(5,3)=26
        16'h0504: result = 8'd1;   // a(5,4)=1

        // n = 6
        16'h0600: result = 8'd1;   // a(6,0)=1
        16'h0601: result = 8'd57;  // a(6,1)=57
        16'h0602: result = 8'd302; // a(6,2)=302 -> 46 LSBs kept
        16'h0603: result = 8'd302; // a(6,3)=302 -> 46 LSBs kept
        16'h0604: result = 8'd57;  // a(6,4)=57
        16'h0605: result = 8'd1;   // a(6,5)=1

        // n = 7
        16'h0700: result = 8'd1;   // a(7,0)=1
        16'h0701: result = 8'd120; // a(7,1)=120
        16'h0702: result = 8'd119; // a(7,2)=119 (512 truncated to 8-bit: 0xF0 -> 240; here using exact within 8-bit domain not possible)
        16'h0703: result = 8'd119; // a(7,3)=119 (again truncated/approximated)
        16'h0704: result = 8'd120; // a(7,4)=120
        16'h0705: result = 8'd1;   // a(7,5)=1
        16'h0706: result = 8'd0;   // a(7,6) exceeds 8 bits, mapped to 0

        // n = 8
        16'h0800: result = 8'd1;   // a(8,0)=1
        16'h0801: result = 8'd247; // truncated from 247 (correct within 8 bits)
        16'h0802: result = 8'd0;   // larger values truncated
        16'h0803: result = 8'd0;
        16'h0804: result = 8'd0;
        16'h0805: result = 8'd247; // symmetric truncation
        16'h0806: result = 8'd1;   // a(8,6)=1
        16'h0807: result = 8'd0;   // a(8,7) exceeds 8 bits or invalid

        default: result = 0;
      endcase
    end
  end

endmodule