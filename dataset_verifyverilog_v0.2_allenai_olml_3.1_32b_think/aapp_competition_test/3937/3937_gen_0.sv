module gcd_sequence_checker (
    input clk,
    input rst_n,
    input start,
    input [2:0] k_in,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [7:0] x_in,
    input [7:0] m_limit,
    output reg found,
    output reg [7:0] j_out,
    output reg valid
);

reg [7:0] x_reg;
reg [2:0] k_reg;
reg [7:0] m_limit_reg;
reg [7:0] a_reg [8];
reg [7:0] current_j;
reg [7:0] current_l;
reg [7:0] found_reg;
reg [7:0] j_out_reg;
reg valid_reg;

typedef enum {IDLE, PROCESSING, DONE} state_t;
state_t state;

function [7:0] gcd;
   input [7:0] a, b;
   if (b == 0) return a;
   return gcd(b, a % b);
endfunction

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      x_reg <= 8'b0;
      k_reg <= 3'b0;
      m_limit_reg <= 8'b0;
      current_j <= 8'b0;
      current_l <= 8'b0;
      found_reg <= 8'b0;
      j_out_reg <= 8'b0;
      valid_reg <= 1'b0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            x_reg <= x_in;
            k_reg <= k_in;
            m_limit_reg <= m_limit;
            a_reg[0] <= a_0;
            a_reg[1] <= a_1;
            a_reg[2] <= a_2;
            a_reg[3] <= a_3;
            a_reg[4] <= a_4;
            a_reg[5] <= a_5;
            a_reg[6] <= a_6;
            a_reg[7] <= a_7;
            if (m_limit_reg < k_reg) begin
               state <= DONE;
               found_reg <= 8'b0;
               j_out_reg <= 8'b0;
               valid_reg <= 1'b1;
            end else begin
               current_j <= 8'b0;
               current_l <= 8'b0;
               state <= PROCESSING;
            end
         end
      end else if (state == PROCESSING) begin
         localparam j_max = m_limit_reg - k_reg;
         if (current_j > j_max) begin
            state <= DONE;
            found_reg <= 8'b0;
            j_out_reg <= 8'b0;
            valid_reg <= 1'b1;
         end else begin
            if (current_l < k_reg) begin
               wire [7:0] target = current_j + current_l;
               wire [7:0] gcd_val = gcd(x_reg, target);
               if (gcd_val != a_reg[current_l]) begin
                  current_j <= current_j + 1;
                  current_l <= 8'b0;
               end else begin
                  current_l <= current_l + 1;
               end
            end else begin
               found_reg <= 8'b1;
               j_out_reg <= current_j;
               state <= DONE;
               valid_reg <= 1'b1;
            end
         end
      end else if (state == DONE) begin
         if (start) begin
            state <= IDLE;
            found_reg <= 8'b0;
            j_out_reg <= 8'b0;
            valid_reg <= 1'b0;
         end
      end
   end
end

assign found = found_reg;
assign j_out = j_out_reg;
assign valid = valid_reg;