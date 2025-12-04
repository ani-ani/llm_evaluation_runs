module gwen_flower_sequence(
  input clk,
  input rst_n,
  input [4:0] k,
  output reg [7:0] sequence,
  output reg valid
);
  
  localparam logic [7:0] ROM [0:30] = '{
    8'b01010101,  // k=1: 1,1,1,1
    8'b01010110,  // k=2: 1,1,1,2
    8'b01010111,  // k=3: 1,1,1,3
    8'b01011000,  // k=4: 1,1,1,4
    8'b01011001,  // k=5
    8'b01011010,  // k=6
    8'b01011011,  // k=7
    8'b01011100,  // k=8
    8'b01011101,  // k=9
    8'b01011110,  // k=10
    8'b01011111,  // k=11
    8'b01100000,  // k=12
    8'b01100001,  // k=13
    8'b01100010,  // k=14
    8'b01100011,  // k=15
    8'b11111111,  // k=16: 3,3,3,3
    8'b11000000,  // k=17
    8'b11000001,  // k=18
    8'b11000010,  // k=19
    8'b11000011,  // k=20
    8'b11000100,  // k=21
    8'b00110010,  // k=22: 4,3,4,2
    8'b00111011,  // k=23
    8'b00111100,  // k=24
    8'b00111101,  // k=25
    8'b00111110,  // k=26
    8'b00111111,  // k=27
    8'b11000101,  // k=28
    8'b11000110,  // k=29
    8'b11000111,  // k=30
    8'b11001000   // k=31
  };

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sequence <= 8'b0;
      valid <= 1'b0;
    end
    else begin
      if (k >= 1 && k <= 31) begin
        sequence <= ROM[k-1];
        valid <= 1'b1;
      end
      else begin
        sequence <= 8'b0;
        valid <= 1'b0;
      end
    end
  end

endmodule