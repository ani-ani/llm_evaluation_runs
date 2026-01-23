module prime_checker (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [31:0] num_in,
   output reg is_prime,
   output reg done
);

// State definitions
parameter IDLE = 3'b000;
parameter INIT = 3'b001;
parameter CHECK = 3'b010;
parameter ITERATE = 3'b011;
parameter DONE = 3'b100;
reg [2:0] state;
reg [31:0] i;
reg is_prime_reg;
reg done_reg;
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      i <= 32'd0;
      is_prime_reg <= 1'b0;
      done_reg <= 1'b0;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               state <= INIT;
            end else begin
               state <= IDLE;
            end
         end
         INIT: begin
            if (num_in < 2) begin
               is_prime_reg <= 1'b0;
               done_reg <= 1'b1;
               state <= DONE;
            end else begin
               i <= 32'h2;
               state <= CHECK;
            end
         end
         CHECK: begin
            // Check if remainder is zero and i < num_in
            if ((num_in % i) == 0 && i < num_in) begin
               is_prime_reg <= 1'b0;
               done_reg <= 1'b1;
               state <= DONE;
            end else begin
               // Check iteration limit
               if (i > 128 || (i * i) > num_in) begin
                  is_prime_reg <= 1'b1;
                  done_reg <= 1'b1;
                  state <= DONE;
               end else begin
                  state <= ITERATE;
               end
            end
         end
         ITERATE: begin
            i <= i + 1;
            if (i > 128 || (i * i) > num_in) begin
               is_prime_reg <= 1'b1;
               done_reg <= 1'b1;
               state <= DONE;
            end else begin
               state <= CHECK;
            end
         end
         DONE: begin
            state <= DONE;
         end
      endcase
   end
end

// Assign outputs
assign is_prime = is_prime_reg;
assign done = done_reg;
endmodule
