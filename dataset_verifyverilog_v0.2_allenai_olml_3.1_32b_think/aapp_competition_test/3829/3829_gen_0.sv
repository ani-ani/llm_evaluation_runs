module expected_max_dice (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [15:0] m,
   input [15:0] n,
   output reg [31:0] result,
   output reg done
);

// Internal registers
reg [31:0] accumulator;
reg [31:0] base;
reg [31:0] power;
reg [15:0] i_counter;
reg [15:0] j_counter;
reg [1:0] state;
reg done_flag;
reg [63:0] temp; // for multiplication

// Initialize registers on reset
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      accumulator <= 32'd0;
      base <= 32'd0;
      power <= 32'd0;
      i_counter <= 16'd0;
      j_counter <= 16'd0;
      state <= 2'd0; // IDLE
      done_flag <= 1'b0;
   end
end

// State machine and control logic
always @(posedge clk) begin
   if (!rst_n) begin
      // Synchronous reset already handled, but this is redundant
   end else begin
      case (state)
         2'd0: // IDLE
            if (start) begin
               i_counter <= 16'd1;
               state <= 2'd1; // CALCULATE
            end
         end
         2'd1: // CALCULATE
            if (i_counter > m) begin
               done_flag <= 1'b1;
               state <= 2'd2; // DONE
               result <= accumulator;
            end else begin
               // Process current i
               if (j_counter == 16'd0) begin
                  base <= ( (i_counter - 1) << 16 ) / m;
                  if (n != 16'd0) begin
                     power <= 32'd65536; // Initialize to 1 for exponentiation
                  end
               end
               if (n == 16'd0) begin
                  // n is zero, no computation needed, move to next i
                  i_counter <= i_counter + 1;
                  j_counter <= 16'd0;
               end else begin
                  if (j_counter <= n) begin
                     // Compute power = (power * base) >> 16
                     temp = (reg [63:0]) (power * base);
                     power <= temp >> 16;
                     j_counter <= j_counter + 1;
                  end else begin
                     // Exponent done, compute term and accumulate
                     reg [31:0] term;
                     term = 32'd65536 - power;
                     accumulator <= accumulator + term;
                     i_counter <= i_counter + 1;
                     j_counter <= 16'd0;
                  end
               end
            end
            state <= 2'd1; // Stay in CALCULATE
         end
         2'd2: // DONE
            done_flag <= 1'b1;
            result <= accumulator;
            state <= 2'd2;
         endcase
      endcase
   end
end

// Output assignment
assign done = done_flag;

endmodule