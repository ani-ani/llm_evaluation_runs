module polite_number(
  input  [7:0] n,
  output [8:0] result
);

  // Step 1: x = n + 1
  wire [8:0] x = n + 9'd1;

  // Step 2: log1 = floor(log2(x)) = position of highest set bit in x
  reg [3:0] log1;
  always @* begin
    casex (x)
      9'b1xxxxxxxx: log1 = 4'd8;
      9'b01xxxxxxx: log1 = 4'd7;
      9'b001xxxxxx: log1 = 4'd6;
      9'b0001xxxxx: log1 = 4'd5;
      9'b00001xxxx: log1 = 4'd4;
      9'b000001xxx: log1 = 4'd3;
      9'b0000001xx: log1 = 4'd2;
      9'b00000001x: log1 = 4'd1;
      9'b000000001: log1 = 4'd0;
      default:      log1 = 4'd0;
    endcase
  end

  // Step 3: sum1 = x + log1
  wire [8:0] sum1 = x + {5'd0, log1};

  // Step 4: log2_val = floor(log2(sum1))
  reg [3:0] log2_val;
  always @* begin
    casex (sum1)
      9'b1xxxxxxxx: log2_val = 4'd8;
      9'b01xxxxxxx: log2_val = 4'd7;
      9'b001xxxxxx: log2_val = 4'd6;
      9'b0001xxxxx: log2_val = 4'd5;
      9'b00001xxxx: log2_val = 4'd4;
      9'b000001xxx: log2_val = 4'd3;
      9'b0000001xx: log2_val = 4'd2;
      9'b00000001x: log2_val = 4'd1;
      9'b000000001: log2_val = 4'd0;
      default:      log2_val = 4'd0;
    endcase
  end

  // Step 5: result = x + log2_val
  assign result = x + {5'd0, log2_val};

endmodule