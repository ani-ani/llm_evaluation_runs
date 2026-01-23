module min_cost_calculator (
   input clk,
   input rst_n,
   input start,
   input [5:0] num_factors,
   input [7:0] prime_factors [0:7],
   output reg [63:0] min_cost,
   output reg done
);

reg [63:0] min_cost_reg;
reg [31:0] current_subset;
reg [7:0] processed_count;
reg [7:0] num_factors_reg;
reg [7:0] prime_factors_reg [0:7];
reg [7:0] threshold;
reg [2:0] state_reg;

localparam IDLE = 2'd0;
localparam CAPTURE = 2'd1;
localparam COMPUTING = 2'd2;
localparam DONE = 2'd3;

always @(*) begin
   min_cost_reg = {64'd1};
end

always @(*) begin
   case (num_factors_reg)
      0: threshold = 1;
      1: threshold = 2;
      2: threshold = 4;
      3: threshold = 8;
      4: threshold = 16;
      5: threshold = 32;
      6: threshold = 64;
      7: threshold = 128;
      8: threshold = 256;
      default: threshold = 256;
   endcase
end

always @(posedge clk) begin
   if (!rst_n) begin
      state_reg <= IDLE;
      num_factors_reg <= 0;
      prime_factors_reg <= 8'b0;
      current_subset <= 0;
      processed_count <= 0;
      min_cost_reg <= {64'd1};
   end else begin
      if (state_reg == IDLE) begin
         if (start) begin
            state_reg <= CAPTURE;
         end
         else begin
            state_reg <= IDLE;
         end
      end else if (state_reg == CAPTURE) begin
         num_factors_reg <= num_factors;
         prime_factors_reg[0] <= prime_factors[0];
         prime_factors_reg[1] <= prime_factors[1];
         prime_factors_reg[2] <= prime_factors[2];
         prime_factors_reg[3] <= prime_factors[3];
         prime_factors_reg[4] <= prime_factors[4];
         prime_factors_reg[5] <= prime_factors[5];
         prime_factors_reg[6] <= prime_factors[6];
         prime_factors_reg[7] <= prime_factors[7];
         min_cost_reg <= {64'd1};
         state_reg <= COMPUTING;
      end else if (state_reg == COMPUTING) begin
         if (current_subset < 256) begin
            if (current_subset < threshold) begin
               if (0 < min_cost_reg) begin
                  min_cost_reg <= 0;
               end
               processed_count <= processed_count + 1;
            end
            current_subset <= current_subset + 1;
         end else begin
            if (processed_count == threshold) begin
               done <= 1;
               state_reg <= DONE;
            end else begin
               state_reg <= DONE;
            end
         end
      end else if (state_reg == DONE) begin
         state_reg <= DONE;
      end
   end
end

assign min_cost = min_cost_reg;
assign done = (state_reg == DONE);

endmodule