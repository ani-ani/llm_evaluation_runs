module frog_tower (
   input clk,
   input rst_n,
   input start,
   input [5:0] frog_count,
   input [15:0] frog_data [0:15],
   output reg [7:0] tower_position,
   output reg [7:0] tower_size,
   output reg done
);

reg [1:0] state;
reg [1:0] process_phase;
reg [7:0] position_counter;
reg [7:0] max_count;
reg [7:0] best_position;
reg [7:0] current_p;
reg [7:0] count_part1_reg;
reg [7:0] count_part2_reg;
reg [5:0] frog_count_reg;
reg [15:0] frog_data_reg [0:15];

localparam IDLE = 2'b00;
localparam LOAD_FROGS = 2'b01;
localparam FIND_MAX_TOWER = 2'b10;
localparam DONE = 2'b11;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      process_phase <= 0;
      position_counter <= 0;
      max_count <= 0;
      best_position <= 0;
      current_p <= 0;
      count_part1_reg <= 0;
      count_part2_reg <= 0;
      frog_count_reg <= 0;
      frog_data_reg[0] <= 16'b0;
      frog_data_reg[1] <= 16'b0;
      frog_data_reg[2] <= 16'b0;
      frog_data_reg[3] <= 16'b0;
      frog_data_reg[4] <= 16'b0;
      frog_data_reg[5] <= 16'b0;
      frog_data_reg[6] <= 16'b0;
      frog_data_reg[7] <= 16'b0;
      frog_data_reg[8] <= 16'b0;
      frog_data_reg[9] <= 16'b0;
      frog_data_reg[10] <= 16'b0;
      frog_data_reg[11] <= 16'b0;
      frog_data_reg[12] <= 16'b0;
      frog_data_reg[13] <= 16'b0;
      frog_data_reg[14] <= 16'b0;
      frog_data_reg[15] <= 16'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start == 1)
               state <= LOAD_FROGS;
         end
         LOAD_FROGS: begin
            frog_count_reg <= frog_count;
            frog_data_reg[0] <= frog_data[0];
            frog_data_reg[1] <= frog_data[1];
            frog_data_reg[2] <= frog_data[2];
            frog_data_reg[3] <= frog_data[3];
            frog_data_reg[4] <= frog_data[4];
            frog_data_reg[5] <= frog_data[5];
            frog_data_reg[6] <= frog_data[6];
            frog_data_reg[7] <= frog_data[7];
            frog_data_reg[8] <= frog_data[8];
            frog_data_reg[9] <= frog_data[9];
            frog_data_reg[10] <= frog_data[10];
            frog_data_reg[11] <= frog_data[11];
            frog_data_reg[12] <= frog_data[12];
            frog_data_reg[13] <= frog_data[13];
            frog_data_reg[14] <= frog_data[14];
            frog_data_reg[15] <= frog_data[15];
            state <= FIND_MAX_TOWER;
         end
         FIND_MAX_TOWER: begin
            if (process_phase == 0) begin
               current_p <= position_counter;
               count_part1_reg <= 0;
               count_part2_reg <= 0;
               process_phase <= 1;
            end else if (process_phase == 1) begin
               count_part1_reg <= 0;
               if (frog_count_reg > 0) begin
                  [15:0] frog0 = frog_data_reg[0];
                  [7:0] d0 = frog0[7:0];
                  [15:8] x0 = frog0[15:8];
                  if (current_p >= x0 && ((current_p - x0) % d0 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               if (frog_count_reg > 1) begin
                  [15:0] frog1 = frog_data_reg[1];
                  [7:0] d1 = frog1[7:0];
                  [15:8] x1 = frog1[15:8];
                  if (current_p >= x1 && ((current_p - x1) % d1 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               if (frog_count_reg > 2) begin
                  [15:0] frog2 = frog_data_reg[2];
                  [7:0] d2 = frog2[7:0];
                  [15:8] x2 = frog2[15:8];
                  if (current_p >= x2 && ((current_p - x2) % d2 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               if (frog_count_reg > 3) begin
                  [15:0] frog3 = frog_data_reg[3];
                  [7:0] d3 = frog3[7:0];
                  [15:8] x3 = frog3[15:8];
                  if (current_p >= x3 && ((current_p - x3) % d3 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               if (frog_count_reg > 4) begin
                  [15:0] frog4 = frog_data_reg[4];
                  [7:0] d4 = frog4[7:0];
                  [15:8] x4 = frog4[15:8];
                  if (current_p >= x4 && ((current_p - x4) % d4 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               if (frog_count_reg > 5) begin
                  [15:0] frog5 = frog_data_reg[5];
                  [7:0] d5 = frog5[7:0];
                  [15:8] x5 = frog5[15:8];
                  if (current_p >= x5 && ((current_p - x5) % d5 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               if (frog_count_reg > 6) begin
                  [15:0] frog6 = frog_data_reg[6];
                  [7:0] d6 = frog6[7:0];
                  [15:8] x6 = frog6[15:8];
                  if (current_p >= x6 && ((current_p - x6) % d6 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               if (frog_count_reg > 7) begin
                  [15:0] frog7 = frog_data_reg[7];
                  [7:0] d7 = frog7[7:0];
                  [15:8] x7 = frog7[15:8];
                  if (current_p >= x7 && ((current_p - x7) % d7 == 0))
                     count_part1_reg <= count_part1_reg + 1;
               end
               process_phase <= 2;
            end else if (process_phase == 2) begin
               count_part2_reg <= 0;
               if (frog_count_reg > 8) begin
                  [15:0] frog8 = frog_data_reg[8];
                  [7:0] d8 = frog8[7:0];
                  [15:8] x8 = frog8[15:8];
                  if (current_p >= x8 && ((current_p - x8) % d8 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (frog_count_reg > 9) begin
                  [15:0] frog9 = frog_data_reg[9];
                  [7:0] d9 = frog9[7:0];
                  [15:8] x9 = frog9[15:8];
                  if (current_p >= x9 && ((current_p - x9) % d9 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (frog_count_reg > 10) begin
                  [15:0] frog10 = frog_data_reg[10];
                  [7:0] d10 = frog10[7:0];
                  [15:8] x10 = frog10[15:8];
                  if (current_p >= x10 && ((current_p - x10) % d10 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (frog_count_reg > 11) begin
                  [15:0] frog11 = frog_data_reg[11];
                  [7:0] d11 = frog11[7:0];
                  [15:8] x11 = frog11[15:8];
                  if (current_p >= x11 && ((current_p - x11) % d11 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (frog_count_reg > 12) begin
                  [15:0] frog12 = frog_data_reg[12];
                  [7:0] d12 = frog12[7:0];
                  [15:8] x12 = frog12[15:8];
                  if (current_p >= x12 && ((current_p - x12) % d12 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (frog_count_reg > 13) begin
                  [15:0] frog13 = frog_data_reg[13];
                  [7:0] d13 = frog13[7:0];
                  [15:8] x13 = frog13[15:8];
                  if (current_p >= x13 && ((current_p - x13) % d13 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (frog_count_reg > 14) begin
                  [15:0] frog14 = frog_data_reg[14];
                  [7:0] d14 = frog14[7:0];
                  [15:8] x14 = frog14[15:8];
                  if (current_p >= x14 && ((current_p - x14) % d14 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (frog_count_reg > 15) begin
                  [15:0] frog15 = frog_data_reg[15];
                  [7:0] d15 = frog15[7:0];
                  [15:8] x15 = frog15[15:8];
                  if (current_p >= x15 && ((current_p - x15) % d15 == 0))
                     count_part2_reg <= count_part2_reg + 1;
               end
               if (count_part1_reg + count_part2_reg > max_count) begin
                  max_count <= count_part1_reg + count_part2_reg;
                  best_position <= current_p;
               end else if (count_part1_reg + count_part2_reg == max_count) begin
                  if (current_p < best_position) 
                     best_position <= current_p;
               end
               process_phase <= 3;
            end else if (process_phase == 3) begin
               position_counter <= position_counter + 1;
               if (position_counter < 256) begin
                  process_phase <= 0;
               end else begin
                  state <= DONE;
                  process_phase <= 0;
               end
            end
      endcase
   end
   done <= (state == DONE) ? 1 : 0;
endmodule