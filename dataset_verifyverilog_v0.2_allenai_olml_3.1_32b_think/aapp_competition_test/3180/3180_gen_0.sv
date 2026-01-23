module drawing_canvas (
input clk,
input rst_n,
input start,
input [5:0] cmd_type,
input [3:0] color,
input [1:0] x1, y1,
input [1:0] x2, y2,
input [1:0] load_idx,
output reg [3:0] pixel_data,
output reg [3:0] pixel_addr_x,
output reg [3:0] pixel_addr_y,
output reg pixel_wr,
output reg done
);
reg [3:0] grid [3:0][3:0];
reg [3:0] save_mem [1:0][3:0][3:0];

reg [3:0] cmd_count;

reg [1:0] paint_x1, paint_y1, paint_x2, paint_y2;
reg [3:0] paint_color;

reg [1:0] load_slot;

reg [2:0] state;

reg [1:0] current_x, current_y;

always @(negedge rst_n) begin
   if (!rst_n) begin
      grid <= 0;
save_mem <=0;
cmd_count <=0;
paint_x1 <=2'b00; paint_y1 <=2'b00;
paint_x2 <=2'b00; paint_y2 <=2'b00;
paint_color <=4'd0;
load_slot <=2'd0;
current_x <=2'd0; current_y <=2'd0;
state <=3'd0;
pixel_data <=4'd0;
pixel_addr_x <=4'd0;
pixel_addr_y <=4'd0;
pixel_wr <=0;
done <=0;
   end
end

always @(posedge clk) begin
case (state)
   3'd0: 
      if (start) begin
         if (cmd_count < 4'd8) begin
            if (cmd_type == 4'd0) begin 
               paint_x1 <= x1;
paint_y1 <= y1;
paint_x2 <= x2;
paint_y2 <= y2;
paint_color <= color;
current_x <= x1;
current_y <= y1;
state <= 3'd1; 
            end
            else if (cmd_type ==4'd1) begin 
               state <=3'd2; 
            end
            else if (cmd_type ==4'd2) begin 
               load_slot <= load_idx -1; 
               state <=3'd3; 
            end
            else begin 
               cmd_count <= cmd_count +1;
            end
         end
         else begin
            done <=1;
            state <=3'd4; 
         end
      end
   end

   3'd1: 
      if (current_x > paint_x2) begin
         pixel_data <=4'd0;
pixel_addr_x <=4'd0;
pixel_addr_y <=4'd0;
pixel_wr <=0;
state <=3'd0;
cmd_count <= cmd_count +1;
      end else if (current_y > paint_y2) begin
         pixel_data <=4'd0;
pixel_addr_x <=4'd0;
pixel_addr_y <=4'd0;
pixel_wr <=0;
current_x <= current_x +1;
current_y <= paint_y1;
      end else begin
         if ( (current_x + current_y) % 2 ==0 ) begin
            pixel_data <= paint_color;
pixel_addr_x <= {2'd0, current_x};
pixel_addr_y <= {2'd0, current_y};
pixel_wr <=1;
         end else begin
            pixel_data <=4'd0;
pixel_addr_x <=4'd0;
pixel_addr_y <=4'd0;
pixel_wr <=0;
         end
         current_y <= current_y +1;
      end
   end

   3'd2: 
      save_mem[0] <= grid;
pixel_data <=4'd0;
pixel_addr_x <=4'd0;
pixel_addr_y <=4'd0;
pixel_wr <=0;
state <=3'd0;
cmd_count <= cmd_count +1;
   end

   3'd3: 
      grid <= save_mem[load_slot];
pixel_data <=4'd0;
pixel_addr_x <=4'd0;
pixel_addr_y <=4'd0;
pixel_wr <=0;
state <=3'd0;
cmd_count <= cmd_count +1;
   end

   3'd4: 
      pixel_data <=4'd0;
pixel_addr_x <=4'd0;
pixel_addr_y <=4'd0;
pixel_wr <=0;
done <=1;
   endcase
end
end
endmodule