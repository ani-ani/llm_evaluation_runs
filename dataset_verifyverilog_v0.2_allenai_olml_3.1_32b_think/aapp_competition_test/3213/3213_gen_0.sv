module spell_optimizer (
    input clk,
    input rst_n, // active low
    input start,
    input [7:0] step_types,
    output reg [2:0] max_power,
    output reg [7:0] best_mask,
    output reg done
);
localparam IDLE = 2'b00;
localparam ITERATING = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [7:0] counter_reg;
reg [2:0] max_power;
reg [7:0] best_mask;
reg done;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      counter_reg <= 8'b0;
      max_power <= 3'b0;
      best_mask <= 8'b0;
      done <= 1'b0;
   end else begin
      if (state == IDLE) begin
          if (start) begin
              state <= ITERATING;
              counter_reg <= 8'b0;
              max_power <= 3'b0;
              best_mask <= 8'b0;
              done <= 1'b0;
          end
      end else if (state == ITERATING) begin
          int local_power;
          local_power = 1;
          if (counter_reg & 1) begin // bit0
              if (step_types[0]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end
          if (counter_reg & 2) begin // bit1
              if (step_types[1]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end
          if (counter_reg & 4) begin // bit2
              if (step_types[2]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end
          if (counter_reg & 8) begin // bit3
              if (step_types[3]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end
          if (counter_reg & 16) begin // bit4
              if (step_types[4]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end
          if (counter_reg & 32) begin // bit5
              if (step_types[5]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end
          if (counter_reg & 64) begin // bit6
              if (step_types[6]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end
          if (counter_reg & 128) begin // bit7
              if (step_types[7]) local_power = (local_power * 2) & 7;
              else local_power = (local_power + 1) & 7;
          end

          if (local_power > max_power) begin
              max_power <= local_power;
              best_mask <= counter_reg;
          end

          // Check if this is the last combination (255)
          if (counter_reg == 8'b11111111) begin
              state <= DONE;
              done <= 1'b1;
          end

          // Increment the counter
          counter_reg <= counter_reg + 1;
      end else if (state == DONE) begin
          // Remain in DONE state
      end
   end
endmodule