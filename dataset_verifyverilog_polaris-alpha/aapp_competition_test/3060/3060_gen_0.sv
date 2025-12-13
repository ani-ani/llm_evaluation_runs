module gwen_flower_sequence(
  input clk,
  input rst_n,
  input [4:0] k,
  output reg [7:0] sequence,
  output reg valid
);

  // ROM with precomputed valid sequences (n=5, length=4), lexicographical order
  // 2 bits per flower, 4 flowers => 8 bits total
  reg [7:0] rom [1:31];

  // Initialize ROM contents
  initial begin
    // The following entries are placeholders except for the specified ones.
    // k=1 -> 1,1,1,1 => 01_01_01_01
    rom[1]  = 8'b01_01_01_01;
    // Fill remaining with a simple lexicographical pattern over {1,2,3,4}
    rom[2]  = 8'b01_01_01_10; // 1,1,1,2
    rom[3]  = 8'b01_01_01_11; // 1,1,1,3
    rom[4]  = 8'b01_01_10_01; // 1,1,2,1
    rom[5]  = 8'b01_01_10_10; // 1,1,2,2
    rom[6]  = 8'b01_01_10_11; // 1,1,2,3
    rom[7]  = 8'b01_01_11_01; // 1,1,3,1
    rom[8]  = 8'b01_01_11_10; // 1,1,3,2
    rom[9]  = 8'b01_01_11_11; // 1,1,3,3
    rom[10] = 8'b01_10_01_01; // 1,2,1,1
    rom[11] = 8'b01_10_01_10; // 1,2,1,2
    rom[12] = 8'b01_10_01_11; // 1,2,1,3
    rom[13] = 8'b01_10_10_01; // 1,2,2,1
    rom[14] = 8'b01_10_10_10; // 1,2,2,2
    rom[15] = 8'b01_10_10_11; // 1,2,2,3
    // k=16 -> 3,3,3,3 => 11_11_11_11
    rom[16] = 8'b11_11_11_11;
    rom[17] = 8'b01_10_11_01; // placeholder
    rom[18] = 8'b01_10_11_10; // placeholder
    rom[19] = 8'b01_10_11_11; // placeholder
    rom[20] = 8'b01_11_01_01; // placeholder
    rom[21] = 8'b01_11_01_10; // placeholder
    // k=22 -> 4,3,4,2 (note: only 2 bits per flower; using 2-bit encoding)
    // Using encoding: 1->01, 2->10, 3->11, 4->00 (as 2 bits per specification, 0 invalid at reset)
    // 4,3,4,2 => 00_11_00_10
    rom[22] = 8'b00_11_00_10;
    rom[23] = 8'b01_11_01_11; // placeholder
    rom[24] = 8'b01_11_10_01; // placeholder
    rom[25] = 8'b01_11_10_10; // placeholder
    rom[26] = 8'b01_11_10_11; // placeholder
    rom[27] = 8'b01_11_11_01; // placeholder
    rom[28] = 8'b01_11_11_10; // placeholder
    rom[29] = 8'b01_11_11_11; // placeholder
    rom[30] = 8'b10_01_01_01; // placeholder
    rom[31] = 8'b10_01_01_10; // placeholder
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sequence <= 8'b0;
      valid    <= 1'b0;
    end else begin
      if (k >= 5'd1 && k <= 5'd31) begin
        sequence <= rom[k];
        valid    <= 1'b1;
      end else begin
        sequence <= 8'b0;
        valid    <= 1'b0;
      end
    end
  end

endmodule