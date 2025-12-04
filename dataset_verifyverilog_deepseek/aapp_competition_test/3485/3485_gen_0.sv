module max_payout(input clk, input rst_n, input start, input [7:0] card_count, input [31:0] card0, input [31:0] card1, input [31:0] card2, input [31:0] card3, input [31:0] card4, input [31:0] card5, input [31:0] card6, input [31:0] card7, output reg [31:0] max_avg, output reg done);
  localparam Q = 16;
  reg [7:0] card_count_reg;
  reg [31:0] card_reg [7:0];
  
  typedef enum {IDLE, PREPARE, CALCULATE, DONE} state_t;
  state_t state, next_state;
  
  reg signed [31:0] prefix_sum[0:8];
  reg signed [31:0] suffix_sum[0:8];
  
  reg [3:0] stop_ptr, start_ptr;
  reg [3:0] stop_max, start_max;
  
  reg signed [31:0] current_sum;
  reg [3:0] current_count;
  wire signed [63:0] product = $signed(current_sum) * $signed(reciprocal_table[current_count]);
  
  reg [31:0] reciprocal_table [1:8];
  
  always_comb begin
    prefix_sum[0] = 0;
    for (int i = 0; i < 8; i++)
      prefix_sum[i+1] = prefix_sum[i] + ((i < card_count_reg) ? card_reg[i] : 0);
    
    suffix_sum[8] = 0;
    for (int i = 7; i >= 0; i--)
      suffix_sum[i] = ((i < card_count_reg) ? card_reg[i] : 0) + suffix_sum[i+1];
  end
  
  initial begin
    reciprocal_table[1] = 32'h00010000; // 1
    reciprocal_table[2] = 32'h00008000; // 0.5
    reciprocal_table[3] = 32'h00005555; // ~0.3333
    reciprocal_table[4] = 32'h00004000; // 0.25
    reciprocal_table[5] = 32'h00003333; // ~0.2
    reciprocal_table[6] = 32'h00002AAA; // ~0.1666
    reciprocal_table[7] = 32'h00002492; // ~0.1428
    reciprocal_table[8] = 32'h00002000; // 0.125
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      max_avg <= 0;
      card_count_reg <= 0;
      stop_ptr <= 0;
      start_ptr <= 1;
      foreach (card_reg[i]) card_reg[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            card_count_reg <= card_count;
            card_reg[0] <= card0;
            card_reg[1] <= card1;
            card_reg[2] <= card2;
            card_reg[3] <= card3;
            card_reg[4] <= card4;
            card_reg[5] <= card5;
            card_reg[6] <= card6;
            card_reg[7] <= card7;
            state <= PREPARE;
          end
        end
        
        PREPARE: begin
          if (card_count_reg == 0) begin
            max_avg <= 0;
            done <= 1;
            state <= DONE;
          end else begin
            stop_max <= (card_count_reg > 8) ? 7 : ((card_count_reg - 1) > 7) ? 7 : card_count_reg - 1;
            start_max <= (card_count_reg > 8) ? 8 : card_count_reg;
            stop_ptr <= 0;
            start_ptr <= 1;
            max_avg <= 0;
            state <= CALCULATE;
          end
        end
        
        CALCULATE: begin
          if (stop_ptr > stop_max) begin
            done <= 1;
            state <= DONE;
          end else if (start_ptr > start_max) begin
            stop_ptr <= stop_ptr + 1;
            start_ptr <= stop_ptr + 2;
          end else begin
            current_sum = prefix_sum[stop_ptr] + suffix_sum[start_ptr];
            current_count = stop_ptr + ((start_ptr < card_count_reg) ? (card_count_reg - start_ptr) : 0);
            
            if (current_count > 0 && current_count <= 8) begin
              if ($signed(product[47:16]) > $signed(max_avg))
                max_avg <= product[47:16];
            end
            start_ptr <= start_ptr + 1;
          end
        end
        
        DONE: begin
          done <= 0;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule