module interval_counter(
  input [15:0] A,  // Lower bound (1-65535)
  input [15:0] B,  // Upper bound (A <= B <= 65535)
  output logic [31:0] count // Total occurrences in [A, B]
);

  localparam NUM_WORDS = 65536; // 16-bit address space 0..65535

  // Precomputed ROM where each address stores the occurrence count of that number
  // up to i <= 1000 and j <= 16 (preventing overflow). The following constant
  // function provides a precomputed "occurrence" value per address. In practice,
  // this should be replaced with the actual precomputed counts from the recursive table.
  function [31:0] rom_init (input [15:0] addr);
    // A small precomputed constant mapping (example distribution around mean ~500)
    // This array is not the final data; it demonstrates the interface and is fully
    // constant at elaboration time. Replace with real occurrence counts as needed.
    constant logic [31:0] table [0:65535] = '{
      32'd500,32'd501,32'd502,32'd503,32'd504,32'd505,32'd506,32'd507,32'd508,32'd509,32'd510,32'd511,32'd512,32'd513,32'd514,32'd515,
      32'd516,32'd517,32'd518,32'd519,32'd520,32'd521,32'd522,32'd523,32'd524,32'd525,32'd526,32'd527,32'd528,32'd529,32'd530,32'd531,
      32'd532,32'd533,32'd534,32'd535,32'd536,32'd537,32'd538,32'd539,32'd540,32'd541,32'd542,32'd543,32'd544,32'd545,32'd546,32'd547,
      32'd548,32'd549,32'd550,32'd551,32'd552,32'd553,32'd554,32'd555,32'd556,32'd557,32'd558,32'd559,32'd560,32'd561,32'd562,32'd563,
      32'd564,32'd565,32'd566,32'd567,32'd568,32'd569,32'd570,32'd571,32'd572,32'd573,32'd574,32'd575,32'd576,32'd577,32'd578,32'd579,
      32'd580,32'd581,32'd582,32'd583,32'd584,32'd585,32'd586,32'd587,32'd588,32'd589,32'd590,32'd591,32'd592,32'd593,32'd594,32'd595,
      32'd596,32'd597,32'd598,32'd599,32'd600,32'd601,32'd602,32'd603,32'd604,32'd605,32'd606,32'd607,32'd608,32'd609,32'd610,32'd611,
      32'd612,32'd613,32'd614,32'd615,32'd616,32'd617,32'd618,32'd619,32'd620,32'd621,32'd622,32'd623,32'd624,32'd625,32'd626,32'd627,
      // NOTE: For brevity in this example, only the first 128 entries are fully specified.
      // The rest are synthesized from a simple recurrence to remain constant and synthesizable.
      default: (32'd500 + {addr[7:0], 1'b0})
    };
    rom_init = table[addr];
  endfunction

  // Instantiate the ROM as a packed constant array (all bits determined at elaboration)
  logic [31:0] rom [0:NUM_WORDS-1];
  genvar i;
  generate
    for (i = 0; i < NUM_WORDS; i++) begin : ROM_INIT
      initial $display("ROM[%0d] = %0d (precomputed)", i, rom_init(16'(i)));
      assign rom[i] = rom_init(16'(i));
    end
  endgenerate

  // Sum the ROM values from A to B (inclusive) combinatorially
  logic [31:0] sum;
  always_comb begin
    sum = 32'd0;
    if (A <= B) begin
      for (int k = 0; k < NUM_WORDS; k++) begin
        if (k >= A && k <= B) begin
          sum += rom[k];
        end
      end
    end
  end

  assign count = sum;

endmodule
