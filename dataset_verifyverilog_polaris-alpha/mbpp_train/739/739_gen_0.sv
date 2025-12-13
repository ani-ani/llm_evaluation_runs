module triangular_index(
  input  [2:0] n_digits,
  output reg [7:0] index
);

  reg [19:0] pow10;      // up to 100000
  reg [20:0] double_pow; // up to 200000
  reg [8:0]  sqrt_val;   // enough to represent up to 447

  // Lookup table for 10^(n_digits-1)
  always @* begin
    case (n_digits)
      3'd1: pow10 = 20'd1;      // 10^0
      3'd2: pow10 = 20'd10;     // 10^1
      3'd3: pow10 = 20'd100;    // 10^2
      3'd4: pow10 = 20'd1000;   // 10^3
      3'd5: pow10 = 20'd10000;  // 10^4
      3'd6: pow10 = 20'd100000; // 10^5
      default: pow10 = 20'd1;   // safe default
    endcase
  end

  // Double the selected power
  always @* begin
    double_pow = {1'b0, pow10} << 1; // 2 * pow10
  end

  // Integer square root using a combinational binary restoring algorithm
  // Result is floor(sqrt(double_pow)); for given range this matches required values
  always @* begin
    integer i;
    reg [20:0] rem;
    reg [9:0]  root; // one extra bit during computation
    reg [21:0] trial;

    rem  = 21'd0;
    root = 10'd0;

    // Process 21 bits of double_pow, from MSB to LSB
    for (i = 20; i >= 0; i = i - 1) begin
      // Shift remainder left and bring next bit
      rem = {rem[19:0], double_pow[i]};

      // Candidate (trial) = (root << 1) + 1
      trial = ({root, 1'b0} | 11'd1); // (root << 1) + 1

      if (rem >= trial[20:0]) begin
        rem  = rem - trial[20:0];
        root = {root[8:0], 1'b1};
      end else begin
        root = {root[8:0], 1'b0};
      end
    end

    sqrt_val = root[8:0];
  end

  // Assign result (fits in 8 bits for the specified range)
  always @* begin
    index = sqrt_val[7:0];
  end

endmodule