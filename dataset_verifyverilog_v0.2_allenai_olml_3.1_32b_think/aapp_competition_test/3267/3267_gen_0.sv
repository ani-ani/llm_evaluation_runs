module chess_spread (
   input clk,
   input rst_n,
   input start,
   input [3:0] board_data,
   input [3:0] board_index,
   output reg [7:0] mirko_spread,
   output reg [7:0] slavko_spread,
   output reg done
);

localparam IDLE = 2'd0;
localparam COLLECT = 2'd1;
localparam COMPUTE = 2'd2;
localparam DONE = 2'd3;

reg [1:0] state, next_state;
reg [4:0] collect_counter;
reg [1:0] mirko_r [0:3];
reg [1:0] mirko_c [0:3];
reg [2:0] mirko_count;
reg [1:0] slavko_r [0:3];
reg [1:0] slavko_c [0:3];
reg [2:0] slavko_count;
reg [7:0] temp_mirko_spread;
reg [7:0] temp_slavko_spread;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      next_state <= IDLE;
      collect_counter <= 16;
      mirko_count <=0;
      slavko_count <=0;
      mirko_r <= {4{2'b00}};
      mirko_c <= {4{2'b00}};
      slavko_r <= {4{2'b00}};
      slavko_c <= {4{2'b00}};
      temp_mirko_spread <=8'b0;
      temp_slavko_spread <=8'b0;
      done <=1'b0;
   end else begin
      state <= next_state;
      next_state = state;

      if (state == IDLE) begin
         if (start) begin
            next_state <= COLLECT;
         end
         done <=1'b0;
      end else if (state == COLLECT) begin
         if (collect_counter >0) begin
            int row = board_index >> 2;
            int col = board_index & 3;
            if (board_data ==1) begin
               if (mirko_count <4) begin
                  mirko_r[mirko_count] <= row;
                  mirko_c[mirko_count] <= col;
                  mirko_count <= mirko_count +1;
               end
            end else if (board_data ==2) begin
               if (slavko_count <4) begin
                  slavko_r[slavko_count] <= row;
                  slavko_c[slavko_count] <= col;
                  slavko_count <= slavko_count +1;
               end
            end
            collect_counter <= collect_counter -1;
         end else begin
            next_state <= COMPUTE;
         end
      end else if (state == COMPUTE) begin
         integer n_m = mirko_count;
         integer n_s = slavko_count;
         integer total_m =0, total_s=0;

         if (n_m >=2) begin
            if (n_m ==2) begin
               total_m = (abs(mirko_r[0]-mirko_r[1]) > abs(mirko_c[0]-mirko_c[1])) ? abs(mirko_r[0]-mirko_r[1]) : abs(mirko_c[0]-mirko_c[1]);
            end else if (n_m ==3) begin
               total_m = ( (abs(mirko_r[0]-mirko_r[1]) > abs(mirko_c[0]-mirko_c[1])) ? abs(mirko_r[0]-mirko_r[1]) : abs(mirko_c[0]-mirko_c[1]) ) + ( (abs(mirko_r[0]-mirko_r[2]) > abs(mirko_c[0]-mirko_c[2])) ? abs(mirko_r[0]-mirko_r[2]) : abs(mirko_c[0]-mirko_c[2]) ) + ( (abs(mirko_r[1]-mirko_r[2]) > abs(mirko_c[1]-mirko_c[2])) ? abs(mirko_r[1]-mirko_r[2]) : abs(mirko_c[1]-mirko_c[2]) );
            end else begin
               total_m = ( (abs(mirko_r[0]-mirko_r[1]) > abs(mirko_c[0]-mirko_c[1])) ? abs(mirko_r[0]-mirko_r[1]) : abs(mirko_c[0]-mirko_c[1]) ) + ( (abs(mirko_r[0]-mirko_r[2]) > abs(mirko_c[0]-mirko_c[2])) ? abs(mirko_r[0]-mirko_r[2]) : abs(mirko_c[0]-mirko_c[2]) ) + ( (abs(mirko_r[0]-mirko_r[3]) > abs(mirko_c[0]-mirko_c[3])) ? abs(mirko_r[0]-mirko_r[3]) : abs(mirko_c[0]-mirko_c[3]) ) + ( (abs(mirko_r[1]-mirko_r[2]) > abs(mirko_c[1]-mirko_c[2])) ? abs(mirko_r[1]-mirko_r[2]) : abs(mirko_c[1]-mirko_c[2]) ) + ( (abs(mirko_r[1]-mirko_r[3]) > abs(mirko_c[1]-mirko_c[3])) ? abs(mirko_r[1]-mirko_r[3]) : abs(mirko_c[1]-mirko_c[3]) ) + ( (abs(mirko_r[2]-mirko_r[3]) > abs(mirko_c[2]-mirko_c[3])) ? abs(mirko_r[2]-mirko_r[3]) : abs(mirko_c[2]-mirko_c[3]) );
            end
         end

         if (n_s >=2) begin
            if (n_s ==2) begin
               total_s = (abs(slavko_r[0]-slavko_r[1]) > abs(slavko_c[0]-slavko_c[1])) ? abs(slavko_r[0]-slavko_r[1]) : abs(slavko_c[0]-slavko_c[1]);
            end else if (n_s ==3) begin
               total_s = ( (abs(slavko_r[0]-slavko_r[1]) > abs(slavko_c[0]-slavko_c[1])) ? abs(slavko_r[0]-slavko_r[1]) : abs(slavko_c[0]-slavko_c[1]) ) + ( (abs(slavko_r[0]-slavko_r[2]) > abs(slavko_c[0]-slavko_c[2])) ? abs(slavko_r[0]-slavko_r[2]) : abs(slavko_c[0]-slavko_c[2]) ) + ( (abs(slavko_r[1]-slavko_r[2]) > abs(slavko_c[1]-slavko_c[2])) ? abs(slavko_r[1]-slavko_r[2]) : abs(slavko_c[1]-slavko_c[2]) );
            end else begin
               total_s = ( (abs(slavko_r[0]-slavko_r[1]) > abs(slavko_c[0]-slavko_c[1])) ? abs(slavko_r[0]-slavko_r[1]) : abs(slavko_c[0]-slavko_c[1]) ) + ( (abs(slavko_r[0]-slavko_r[2]) > abs(slavko_c[0]-slavko_c[2])) ? abs(slavko_r[0]-slavko_r[2]) : abs(slavko_c[0]-slavko_c[2]) ) + ( (abs(slavko_r[0]-slavko_r[3]) > abs(slavko_c[0]-slavko_c[3])) ? abs(slavko_r[0]-slavko_r[3]) : abs(slavko_c[0]-slavko_c[3]) ) + ( (abs(slavko_r[1]-slavko_r[2]) > abs(slavko_c[1]-slavko_c[2])) ? abs(slavko_r[1]-slavko_r[2]) : abs(slavko_c[1]-slavko_c[2]) ) + ( (abs(slavko_r[1]-slavko_r[3]) > abs(slavko_c[1]-slavko_c[3])) ? abs(slavko_r[1]-slavko_r[3]) : abs(slavko_c[1]-slavko_c[3]) ) + ( (abs(slavko_r[2]-slavko_r[3]) > abs(slavko_c[2]-slavko_c[3])) ? abs(slavko_r[2]-slavko_r[3]) : abs(slavko_c[2]-slavko_c[3]) );
            end
         end

         temp_mirko_spread <= total_m;
         temp_slavko_spread <= total_s;
         next_state <= DONE;
      end else if (state == DONE) begin
         mirko_spread <= temp_mirko_spread;
         slavko_spread <= temp_slavko_spread;
         done <=1'b1;
         next_state <= DONE;
      end
   end
endmodule