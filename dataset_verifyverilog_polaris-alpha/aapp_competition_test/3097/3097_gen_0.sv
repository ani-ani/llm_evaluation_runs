module interval_counter(
  input  [15:0] A,  // Lower bound (1-65535)
  input  [15:0] B,  // Upper bound (A <= B <= 65535)
  output [31:0] count // Total occurrences in [A, B]
);

  // --------------------------------------------------------------------------
  // Precomputed ROM of occurrence counts for values 0..65535
  // Note: Address 0 is defined as 0 occurrences (unused range start).
  // The ROM is modeled combinationally via a function for synthesis compatibility.
  // In a real implementation, contents must be filled with correct precomputed data.
  // --------------------------------------------------------------------------

  function automatic [15:0] rom_value(input [15:0] addr);
    begin
      unique case (addr)
        // Example placeholder entries; in practice, fill with full precomputed table.
        16'd0:     rom_value = 16'd0;
        16'd1:     rom_value = 16'd1;
        16'd2:     rom_value = 16'd3;
        16'd3:     rom_value = 16'd2;
        16'd4:     rom_value = 16'd5;
        // ... (all addresses from 5 to 65534 with correct precomputed values)
        16'd65535: rom_value = 16'd0;
        default:   rom_value = 16'd0;
      endcase
    end
  endfunction

  // --------------------------------------------------------------------------
  // Combinational prefix-sum implementation
  // count = sum_{k=A}^{B} rom[k]
  // Implemented directly as a loop-based combinational accumulation.
  // Synthesis tools will unroll this due to fixed bounds.
  // --------------------------------------------------------------------------

  reg [31:0] sum;
  integer i;

  always @* begin
    sum = 32'd0;
    for (i = A; i <= B; i = i + 1) begin
      sum = sum + rom_value(i[15:0]);
    end
  end

  assign count = sum;

endmodule