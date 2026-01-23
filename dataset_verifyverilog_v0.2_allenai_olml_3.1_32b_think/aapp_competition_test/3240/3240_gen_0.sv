module binary_town_voting (
   input clk,
   input rst_n, // active low
   input start,
   input [3:0] voter_id,
   input voter_valid,
   input [15:0] voter_prob,
   output reg [3:0] optimal_b_self,
   output reg done
);

reg [2:0] state;
reg [3:0] voter_count;
reg [31:0] PDT_reg [0:15];
reg [3:0] current_ballot;
reg [31:0] current_prob;
reg [3:0] update_counter;
reg [3:0] eval_self;
reg [3:0] best_self;
reg [31:0] max_expected;
reg [3:0] bit_pos;
reg [3:0] s;
reg [31:0] current_expected;
reg [31:0] term1;

localparam IDLE = 3'd0;
localparam READ_VOTER = 3'd1;
localparam UPDATE_PDT = 3'd2;
localparam EVAL_LOOP = 3'd3;
localparam DONE = 3'd4;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      voter_count <=4'd0;
      PDT_reg[0] <= 32'd10000; // 0x10000 is 1.0 in Q16.16
      PDT_reg[1] <=32'd0;
      PDT_reg[2] <=32'd0;
      PDT_reg[3] <=32'd0;
      PDT_reg[4] <=32'd0;
      PDT_reg[5] <=32'd0;
      PDT_reg[6] <=32'd0;
      PDT_reg[7] <=32'd0;
      PDT_reg[8] <=32'd0;
      PDT_reg[9] <=32'd0;
      PDT_reg[10] <=32'd0;
      PDT_reg[11] <=32'd0;
      PDT_reg[12] <=32'd0;
      PDT_reg[13] <=32'd0;
      PDT_reg[14] <=32'd0;
      PDT_reg[15] <=32'd0;
      current_ballot <=4'd0;
      current_prob <=32'd0;
      update_counter <=4'd0;
      eval_self <=4'd0;
      best_self <=4'd0;
      max_expected <=32'd0;
      bit_pos <=4'd0;
      s <=4'd0;
      current_expected <=32'd0;
      term1 <=32'd0;
      optimal_b_self <=4'd0;
      done <=1'b0;
   end
end

always @(posedge clk) begin
   if (!rst_n) begin
      // Handled above
   end else begin
      case (state)
         IDLE:
            if (start) begin
               state <= READ_VOTER;
            end else begin
               state <= IDLE;
            end
         READ_VOTER:
            if (voter_valid) begin
               current_ballot <= voter_ballot;
               current_prob <= {16'd0, voter_prob};
               voter_count <= voter_count +1;
               if (voter_count <=9) begin
                  state <= UPDATE_PDT;
                  update_counter <=15;
               end else begin
                  state <= EVAL_LOOP;
               end
            end else begin
               state <= READ_VOTER;
            end
         UPDATE_PDT:
            if (update_counter ==0) begin
               if (voter_count <9) begin
                  state <= READ_VOTER;
               end else begin
                  state <= EVAL_LOOP;
               end
            end else begin
               term1 = ( (1<<16) - current_prob ) * PDT_reg[update_counter];
               if (update_counter >= current_ballot) begin
                  term1 = term1 + PDT_reg[update_counter - current_ballot] * current_prob;
               end
               PDT_reg[update_counter] <= term1;
               update_counter <= update_counter -1;
            end
         EVAL_LOOP:
            best_self <=4'd0;
            max_expected <=32'd0;
            state <= DONE;
            optimal_b_self <= best_self;
            done <=1'b1;
         DONE:
            state <= DONE;
            done <=1'b1;
            optimal_b_self <= best_self;
      endcase
   end
end
endmodule