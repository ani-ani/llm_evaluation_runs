module widget_profit_maximizer (
   input clk,
   input rst_n, // active-low
   input start,
   input [2:0] num_producers,
   input [2:0] num_consumers,
   input [7:0] producer_prices [0:7],
   input [7:0] producer_dates [0:7],
   input [7:0] consumer_prices [0:7],
   input [7:0] consumer_dates [0:7],
   output reg [15:0] max_profit,
   output reg done
);

// Internal registers
reg [2:0] captured_num_producers;
reg [2:0] captured_num_consumers;
reg [7:0] captured_producer_prices [0:7];
reg [7:0] captured_producer_dates [0:7];
reg [7:0] captured_consumer_prices [0:7];
reg [7:0] captured_consumer_dates [0:7];
reg [15:0] max_profit_reg;
reg [6:0] current_pair;
reg [1:0] state_reg;

// State definitions
parameter IDLE = 2'b00;
parameter PROCESSING = 2'b01;
parameter DONE_STATE = 2'b10;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      // Reset all registers
      captured_num_producers <= 3'b000;
      captured_num_consumers <= 3'b000;
      // Initialize captured arrays to 0
      captured_producer_prices[0] <= 8'b00000000;
      captured_producer_prices[1] <= 8'b00000000;
      captured_producer_prices[2] <= 8'b00000000;
      captured_producer_prices[3] <= 8'b00000000;
      captured_producer_prices[4] <= 8'b00000000;
      captured_producer_prices[5] <= 8'b00000000;
      captured_producer_prices[6] <= 8'b00000000;
      captured_producer_prices[7] <= 8'b00000000;
      captured_producer_dates[0] <= 8'b00000000;
      captured_producer_dates[1] <= 8'b00000000;
      captured_producer_dates[2] <= 8'b00000000;
      captured_producer_dates[3] <= 8'b00000000;
      captured_producer_dates[4] <= 8'b00000000;
      captured_producer_dates[5] <= 8'b00000000;
      captured_producer_dates[6] <= 8'b00000000;
      captured_producer_dates[7] <= 8'b00000000;
      captured_consumer_prices[0] <= 8'b00000000;
      captured_consumer_prices[1] <= 8'b00000000;
      captured_consumer_prices[2] <= 8'b00000000;
      captured_consumer_prices[3] <= 8'b00000000;
      captured_consumer_prices[4] <= 8'b00000000;
      captured_consumer_prices[5] <= 8'b00000000;
      captured_consumer_prices[6] <= 8'b00000000;
      captured_consumer_prices[7] <= 8'b00000000;
      captured_consumer_dates[0] <= 8'b00000000;
      captured_consumer_dates[1] <= 8'b00000000;
      captured_consumer_dates[2] <= 8'b00000000;
      captured_consumer_dates[3] <= 8'b00000000;
      captured_consumer_dates[4] <= 8'b00000000;
      captured_consumer_dates[5] <= 8'b00000000;
      captured_consumer_dates[6] <= 8'b00000000;
      captured_consumer_dates[7] <= 8'b00000000;
      max_profit_reg <= 16'b0000000000000000;
      current_pair <= 7'b0000000;
      state_reg <= IDLE;
      done_reg <= 1'b0;
   end else begin
      if (state_reg == IDLE) begin
         if (start) begin
            // Capture input values
            captured_num_producers <= num_producers;
            captured_num_consumers <= num_consumers;
            // Assign producer prices
            captured_producer_prices[0] <= producer_prices[0];
            captured_producer_prices[1] <= producer_prices[1];
            captured_producer_prices[2] <= producer_prices[2];
            captured_producer_prices[3] <= producer_prices[3];
            captured_producer_prices[4] <= producer_prices[4];
            captured_producer_prices[5] <= producer_prices[5];
            captured_producer_prices[6] <= producer_prices[6];
            captured_producer_prices[7] <= producer_prices[7];
            // Assign producer dates
            captured_producer_dates[0] <= producer_dates[0];
            captured_producer_dates[1] <= producer_dates[1];
            captured_producer_dates[2] <= producer_dates[2];
            captured_producer_dates[3] <= producer_dates[3];
            captured_producer_dates[4] <= producer_dates[4];
            captured_producer_dates[5] <= producer_dates[5];
            captured_producer_dates[6] <= producer_dates[6];
            captured_producer_dates[7] <= producer_dates[7];
            // Assign consumer prices
            captured_consumer_prices[0] <= consumer_prices[0];
            captured_consumer_prices[1] <= consumer_prices[1];
            captured_consumer_prices[2] <= consumer_prices[2];
            captured_consumer_prices[3] <= consumer_prices[3];
            captured_consumer_prices[4] <= consumer_prices[4];
            captured_consumer_prices[5] <= consumer_prices[5];
            captured_consumer_prices[6] <= consumer_prices[6];
            captured_consumer_prices[7] <= consumer_prices[7];
            // Assign consumer dates
            captured_consumer_dates[0] <= consumer_dates[0];
            captured_consumer_dates[1] <= consumer_dates[1];
            captured_consumer_dates[2] <= consumer_dates[2];
            captured_consumer_dates[3] <= consumer_dates[3];
            captured_consumer_dates[4] <= consumer_dates[4];
            captured_consumer_dates[5] <= consumer_dates[5];
            captured_consumer_dates[6] <= consumer_dates[6];
            captured_consumer_dates[7] <= consumer_dates[7];
            state_reg <= PROCESSING;
         end
      end else if (state_reg == PROCESSING) begin
         local integer total_pairs = captured_num_producers * captured_num_consumers;
         if (current_pair < total_pairs) begin
            // Calculate current pair indices
            local integer producer_idx = current_pair / captured_num_consumers;
            local integer consumer_idx = current_pair % captured_num_consumers;
            // Get prices and dates
            local integer producer_price = captured_producer_prices[producer_idx];
            local integer producer_date = captured_producer_dates[producer_idx];
            local integer consumer_price = captured_consumer_prices[consumer_idx];
            local integer consumer_date = captured_consumer_dates[consumer_idx];
            // Compute profit_per_day and days
            local integer profit_per_day = consumer_price - producer_price;
            local integer days = 0;
            local integer total = 0;
            if (profit_per_day > 0) begin
               days = consumer_date - producer_date;
               if (days > 0) begin
                  total = profit_per_day * days;
               end
            end
            // Update max_profit_reg if needed
            if (total > max_profit_reg) begin
               max_profit_reg <= total;
            end
            // Increment current_pair
            current_pair <= current_pair + 1;
         end else begin
            // All pairs processed, move to DONE
            state_reg <= DONE_STATE;
            done_reg <= 1'b1;
         end
      end else if (state_reg == DONE_STATE) begin
         // No action
      end
   end
end

// Output assignments
assign max_profit = max_profit_reg;
assign done = done_reg;

endmodule