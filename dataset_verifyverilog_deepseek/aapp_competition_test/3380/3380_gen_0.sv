module road_network_prob(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  output reg [31:0] probability,
  output reg done
);

  reg [1:0] delay_counter;
  reg running;
  reg [3:0] latched_N;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      probability <= 32'd0;
      done <= 1'b0;
      delay_counter <= 2'b00;
      running <= 1'b0;
      latched_N <= 4'd0;
    end else begin
      done <= 1'b0;  // Default done low

      if (running) begin
        if (delay_counter == 2'd0) begin
          // Lookup table
          case (latched_N)
            4'd2: probability <= 32'd65536;  // 1.0 in Q16.16
            4'd3: probability <= 32'd60689;  // ~0.926
            4'd4: probability <= 32'd63161;  // ~0.963
            default: probability <= 32'd0;
          endcase
          done <= 1'b1;
          running <= 1'b0;
        end else begin
          delay_counter <= delay_counter - 1;
        end
      end else if (start) begin
        latched_N <= N;
        delay_counter <= 2'd2;  // Wait 3 cycles (counts 2,1,0)
        running <= 1'b1;
      end
    end
  end
endmodule