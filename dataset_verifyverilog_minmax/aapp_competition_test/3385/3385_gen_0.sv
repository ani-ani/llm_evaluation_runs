module costume_parity_solver (
  input [2:0] n,
  input [2:0] l_array [0:7],
  input [2:0] r_array [0:7],
  input [7:0] x_array, // x_i is bit i of this vector
  output reg [31:0] result
);

  // All inputs are 'reg' as requested

  function integer mod_wrap(input integer a, input integer m);
    begin
      mod_wrap = a % m;
      if (mod_wrap < 0) mod_wrap = mod_wrap + m;
    end
  endfunction

  function bit parity8(input [7:0] v);
    parity8 = ^v;
  endfunction

  integer i, j, k, a;
  integer seg_count;
  bit [7:0] seg_vals [0:15];
  bit seg_parity;
  integer count;
  bit ok;
  bit [7:0] a_vec; // 8-bit assignment vector (3 bits per child, unused upper bits can be nonzero)

  always_comb begin
    count = 0;
    // Iterate over all 8-bit vectors (0..255). Each 3-bit nibble is one child's costume.
    for (a = 0; a < 256; a = a + 1) begin
      a_vec = a[7:0];
      ok = 1'b1;
      // Verify constraints for first n children
      for (i = 0; i < n; i = i + 1) begin
        // Segment range for child i: (i - l_i) .. (i + r_i) modulo n
        seg_count = l_array[i] + r_array[i] + 1;
        for (j = 0; j < seg_count; j = j + 1) begin
          k = mod_wrap(i - l_array[i] + j, n);
          // Child k uses 3-bit costume value (nibble k)
          seg_vals[j] = a_vec[3*k +: 3];
        end
        // Parity of the sum of segment values
        seg_parity = parity8(seg_vals[0 +: seg_count]);
        // x_i is bit i of x_array
        if (seg_parity !== x_array[i]) begin
          ok = 1'b0;
          disable for; // break out of a-loop once a constraint fails
        end
      end
      if (ok) count = count + 1;
    end
    result = count % 1000000007;
  end

endmodule
