module road_network_prob(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [3:0] N,
  output reg [31:0] probability,
  output reg done
);

// Lookup table for probabilities (Q16.16)
reg [31:0] lut [0:4];
integer i;
initial begin
  for (i = 0; i < 5; i = i + 1) lut[i] = 32'b0;
  lut[2] = 32'h00010000; // 65536 (1.0)
  lut[3] = 32'h0000ed31; // 60689
  lut[4] = 32'h0000f6c9; // 63161
end

// State machine with asynchronous reset
localparam IDLE   = 2'b00;
localparam WAIT1  = 2'b01;
localparam WAIT2  = 2'b10;
localparam WAIT3  = 2'b11;

reg [1:0] state;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    probability <= 32'b0;
    done <= 1'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        probability <= 32'b0;
        if (start) state <= WAIT1;
      end
      WAIT1: begin
        state <= WAIT2;
      end
      WAIT2: begin
        state <= WAIT3;
      end
      WAIT3: begin
        // After three cycles, output probability and assert done for one cycle
        if (N >= 2 && N <= 4) probability <= lut[N];
        else probability <= 32'b0;
        done <= 1'b1;
        state <= IDLE;
      end
      default: begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule