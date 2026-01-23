module dance_complexity (
   input clk,
   input rst_n, // Active-low reset
   input start,
   input [7:0] x_mask,
   input [2:0] n,
   output reg [31:0] result,
   output reg done
);

   localparam MOD = 1000000007;
   reg [31:0] accumulated_result;
   reg [2:0] bit_idx;
   reg [2:0] wait_count;
   reg [2:0] state;
   reg [2:0] captured_n; // Capture n at start

   parameter IDLE = 3'd0,
                   COMPUTING = 3'd1,
                   WAITING = 3'd2,
                   DONE = 3'd3;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         accumulated_result <= 32'd0;
         bit_idx <= 3'd0;
         wait_count <= 3'd0;
         state <= IDLE;
         captured_n <= 3'd0;
         done <= 1'b0;
      end else begin
         case(state)
            IDLE: begin
               if (start) begin
                  captured_n <= n;
                  accumulated_result <= 32'd0;
                  bit_idx <= 3'd0;
                  state <= COMPUTING;
               end else begin
                  state <= IDLE;
               end
            end
            COMPUTING: begin
               if (bit_idx < captured_n) begin
                  // Compute mask for current bit
                  reg [7:0] mask;
                  case(bit_idx)
                     0: mask = 8'h80;
                     1: mask = 8'h40;
                     2: mask = 8'h20;
                     3: mask = 8'h10;
                     4: mask = 8'h08;
                     5: mask = 8'h04;
                     6: mask = 8'h02;
                     7: mask = 8'h01;
                     default: mask = 8'h00;
                  endcase

                  reg [7:0] x_bit_val = x_mask & mask;
                  if (x_bit_val != 0) begin
                     reg [2:0] m;
                     m = captured_n - bit_idx - 1;
                     // Calculate 2^k
                     reg [31:0] pow2_k;
                     case(bit_idx)
                        0: pow2_k = 1;
                        1: pow2_k = 2;
                        2: pow2_k = 4;
                        3: pow2_k = 8;
                        4: pow2_k = 16;
                        5: pow2_k = 32;
                        6: pow2_k = 64;
                        7: pow2_k = 128;
                        default: pow2_k = 1;
                     endcase

                     // Calculate 4^m
                     reg [31:0] pow4_m;
                     case(m)
                        0: pow4_m = 1;
                        1: pow4_m = 4;
                        2: pow4_m = 16;
                        3: pow4_m = 64;
                        4: pow4_m = 256;
                        5: pow4_m = 1024;
                        6: pow4_m = 4096;
                        7: pow4_m = 16384;
                        default: pow4_m = 1;
                     endcase

                     // Calculate term and update result
                     reg [31:0] term;
                     term = (pow2_k * pow4_m) % MOD;
                     accumulated_result <= (accumulated_result + term) % MOD;
                  end
                  // Move to next bit
                  bit_idx <= bit_idx + 1;
                  state <= COMPUTING;
               end else begin
                  // Move to WAITING state
                  if (wait_count == 0) begin
                     wait_count <= 10 - captured_n;
                  end
                  state <= WAITING;
               end
            end
            WAITING: begin
               wait_count <= wait_count - 1;
               if (wait_count == 0) begin
                  state <= DONE;
               end else begin
                  state <= WAITING;
               end
            end
            DONE: begin
               state <= DONE;
            end
         endcase
      end
   end

   // Assign outputs
   assign result = accumulated_result;
   assign done = (state == DONE);

endmodule