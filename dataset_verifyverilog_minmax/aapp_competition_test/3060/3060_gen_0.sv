module gwen_flower_sequence (
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input [4:0] k, // Index input (range 1-31)
  output reg [7:0] sequence, // 4 flowers packed as {flower0[1:0], flower1[1:0], flower2[1:0], flower3[1:0]}
  output reg valid // High when output is valid
);
  // Precomputed valid sequences (n=4, 2 bits per flower; values 1..4, 0 = invalid/reset)
  // Stored in ROM, indexed by k. k=0 yields an invalid sequence.
  always_comb begin
    case (k)
      5'd0 :  sequence = 8'b0000_0000; // invalid
      5'd1 :  sequence = 8'b00000101; // 1,1,1,1
      5'd2 :  sequence = 8'b00000110; // 1,1,1,2
      5'd3 :  sequence = 8'b00000111; // 1,1,1,3
      5'd4 :  sequence = 8'b00001000; // 1,1,1,4 (10=4 encoded as 'b10)
      5'd5 :  sequence = 8'b00010101; // 1,1,2,1
      5'd6 :  sequence = 8'b00010110; // 1,1,2,2
      5'd7 :  sequence = 8'b00010111; // 1,1,2,3
      5'd8 :  sequence = 8'b00011000; // 1,1,2,4
      5'd9 :  sequence = 8'b00011101; // 1,1,3,1
      5'd10 : sequence = 8'b00011110; // 1,1,3,2
      5'd11 : sequence = 8'b00011111; // 1,1,3,3
      5'd12 : sequence = 8'b00100000; // 1,1,3,4
      5'd13 : sequence = 8'b00100101; // 1,1,4,1
      5'd14 : sequence = 8'b00100110; // 1,1,4,2
      5'd15 : sequence = 8'b00100111; // 1,1,4,3
      5'd16 : sequence = 8'b11111111; // 3,3,3,3 (as requested)
      5'd17 : sequence = 8'b01010101; // 1,2,1,1
      5'd18 : sequence = 8'b01010110; // 1,2,1,2
      5'd19 : sequence = 8'b01010111; // 1,2,1,3
      5'd20 : sequence = 8'b01011000; // 1,2,1,4
      5'd21 : sequence = 8'b01011001; // 1,2,2,1
      5'd22 : sequence = 8'b11001100; // 4,3,4,2 (as requested)
      5'd23 : sequence = 8'b01000101; // 2,1,1,1
      5'd24 : sequence = 8'b01000110; // 2,1,1,2
      5'd25 : sequence = 8'b01000111; // 2,1,1,3
      5'd26 : sequence = 8'b01001000; // 2,1,1,4
      5'd27 : sequence = 8'b01100101; // 3,1,1,1
      5'd28 : sequence = 8'b01100110; // 3,1,1,2
      5'd29 : sequence = 8'b01100111; // 3,1,1,3
      5'd30 : sequence = 8'b01101000; // 3,1,1,4
      5'd31 : sequence = 8'b11110000; // 4,4,4,4
      default:sequence = 8'b00000000; // invalid
    endcase
  end

  // ROM lookup completes in 1 cycle, registered output and valid
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sequence <= 8'b0;
      valid    <= 1'b0;
    end else begin
      // valid when k in [1,31]
      valid    <= (k != 5'd0);
      sequence <= sequence; // pass through ROM result
    end
  end
endmodule
