module road_network_prob(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  output reg [31:0] probability,
  output reg done
);

  reg [1:0] cycle_cnt;
  reg [3:0] N_latched;
  reg busy;

  // Asynchronous active-low reset, synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      probability <= 32'd0;
      done        <= 1'b0;
      cycle_cnt   <= 2'd0;
      N_latched   <= 4'd0;
      busy        <= 1'b0;
    end else begin
      done <= 1'b0; // default

      if (start && !busy) begin
        // Latch N and start 3-cycle delay
        N_latched <= N;
        cycle_cnt <= 2'd0;
        busy      <= 1'b1;
      end else if (busy) begin
        if (cycle_cnt == 2'd2) begin
          // After 3 cycles (0,1,2), provide output
          case (N_latched)
            4'd2: probability <= 32'd65536; // 1.0 Q16.16
            4'd3: probability <= 32'd60689; // ~0.926 Q16.16
            4'd4: probability <= 32'd63161; // ~0.963 Q16.16
            default: probability <= 32'd0;  // invalid N
          endcase
          done      <= 1'b1;  // assert for 1 cycle
          busy      <= 1'b0;  // ready for next start
        end
        cycle_cnt <= cycle_cnt + 2'd1;
      end
    end
  end

endmodule