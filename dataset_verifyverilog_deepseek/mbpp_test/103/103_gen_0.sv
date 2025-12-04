module eulerian_number(
  input [7:0] n,
  input [7:0] m,
  output reg [7:0] result
);

  always_comb begin
    if (n == 8'd0 || m >= n) begin
      result = 8'd0;
    end
    else begin
      case ({n, m})
        16'h0100: result = 8'd1;  // n=1, m=0
        16'h0200: result = 8'd1;  // n=2, m=0
        16'h0201: result = 8'd1;  // n=2, m=1
        16'h0300: result = 8'd1;  // n=3, m=0
        16'h0301: result = 8'd4;  // n=3, m=1
        16'h0302: result = 8'd1;  // n=3, m=2
        16'h0400: result = 8'd1;  // n=4, m=0
        16'h0401: result = 8'd11; // n=4, m=1
        16'h0402: result = 8'd11; // n=4, m=2
        16'h0403: result = 8'd1;  // n=4, m=3
        16'h0500: result = 8'd1;  // n=5, m=0
        16'h0501: result = 8'd26; // n=5, m=1
        16'h0502: result = 8'd66; // n=5, m=2
        16'h0503: result = 8'd26; // n=5, m=3
        16'h0504: result = 8'd1;  // n=5, m=4
        16'h0600: result = 8'd1;  // n=6, m=0
        16'h0601: result = 8'd57; // n=6, m=1
        16'h0605: result = 8'd1;  // n=6, m=5
        16'h0700: result = 8'd1;  // n=7, m=0
        16'h0701: result = 8'd120; // n=7, m=1
        16'h0706: result = 8'd1;  // n=7, m=6
        16'h0800: result = 8'd1;  // n=8, m=0
        16'h0801: result = 8'd247; // n=8, m=1
        16'h0807: result = 8'd1;  // n=8, m=7
        default:    result = 8'd0;
      endcase
    end
  end

endmodule