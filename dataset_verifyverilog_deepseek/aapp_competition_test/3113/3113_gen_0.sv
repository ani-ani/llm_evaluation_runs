module cloud_cover_comparator(
  input clk,               
  input rst_n,             
  input start,             
  input [1:0] g_tcount,    
  input [95:0] g_tri1,     
  input [95:0] g_tri2,     
  input [1:0] j_tcount,    
  input [95:0] j_tri1,     
  input [95:0] j_tri2,     
  output reg result,       
  output reg done          
);

  reg [1:0] g_tcount_reg, j_tcount_reg;
  reg [95:0] g_tri1_reg, g_tri2_reg, j_tri1_reg, j_tri2_reg;
  reg running;
  reg [2:0] count;
  
  // Triangle coordinates
  reg [15:0] g1_x1, g1_y1, g1_x2, g1_y2, g1_x3, g1_y3;
  reg [15:0] g2_x1, g2_y1, g2_x2, g2_y2, g2_x3, g2_y3;
  reg [15:0] j1_x1, j1_y1, j1_x2, j1_y2, j1_x3, j1_y3;
  reg [15:0] j2_x1, j2_y1, j2_x2, j2_y2, j2_x3, j2_y3;
  
  // Calculation registers
  reg signed [15:0] g1_dy1, g1_dy2, g1_dy3;
  reg signed [15:0] g2_dy1, g2_dy2, g2_dy3;
  reg signed [15:0] j1_dy1, j1_dy2, j1_dy3;
  reg signed [15:0] j2_dy1, j2_dy2, j2_dy3;
  
  reg signed [31:0] g1_t1, g1_t2, g1_t3;
  reg signed [31:0] g2_t1, g2_t2, g2_t3;
  reg signed [31:0] j1_t1, j1_t2, j1_t3;
  reg signed [31:0] j2_t1, j2_t2, j2_t3;
  
  reg signed [31:0] g1_sum, g2_sum, j1_sum, j2_sum;
  reg [31:0] g1_area, g2_area, j1_area, j2_area;
  
  reg [31:0] g_area_sum, j_area_sum;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result <= 1'b0;
      running <= 1'b0;
      count <= 3'b0;
    end else begin
      done <= 1'b0;
      
      if (start && !running) begin
        g_tcount_reg <= g_tcount;
        j_tcount_reg <= j_tcount;
        g_tri1_reg <= g_tri1;
        g_tri2_reg <= g_tri2;
        j_tri1_reg <= j_tri1;
        j_tri2_reg <= j_tri2;
        running <= 1'b1;
        count <= 3'd1;
      end else if (running) begin
        if (count == 3'd5) begin
          done <= 1'b1;
          result <= (g_tcount_reg == j_tcount_reg) && (g_area_sum == j_area_sum);
          running <= 1'b0;
        end else begin
          count <= count + 1;
        end
      end
      
      case (count)
        3'd1: begin
          g1_x1 <= g_tri1_reg[95:80];
          g1_y1 <= g_tri1_reg[79:64];
          g1_x2 <= g_tri1_reg[63:48];
          g1_y2 <= g_tri1_reg[47:32];
          g1_x3 <= g_tri1_reg[31:16];
          g1_y3 <= g_tri1_reg[15:0];
          
          g2_x1 <= g_tri2_reg[95:80];
          g2_y1 <= g_tri2_reg[79:64];
          g2_x2 <= g_tri2_reg[63:48];
          g2_y2 <= g_tri2_reg[47:32];
          g2_x3 <= g_tri2_reg[31:16];
          g2_y3 <= g_tri2_reg[15:0];
          
          j1_x1 <= j_tri1_reg[95:80];
          j1_y1 <= j_tri1_reg[79:64];
          j1_x2 <= j_tri1_reg[63:48];
          j1_y2 <= j_tri1_reg[47:32];
          j1_x3 <= j_tri1_reg[31:16];
          j1_y3 <= j_tri1_reg[15:0];
          
          j2_x1 <= j_tri2_reg[95:80];
          j2_y1 <= j_tri2_reg[79:64];
          j2_x2 <= j_tri2_reg[63:48];
          j2_y2 <= j_tri2_reg[47:32];
          j2_x3 <= j_tri2_reg[31:16];
          j2_y3 <= j_tri2_reg[15:0];
        end
        
        3'd2: begin
          g1_dy1 <= $signed(g1_y2) - $signed(g1_y3);
          g1_dy2 <= $signed(g1_y3) - $signed(g1_y1);
          g1_dy3 <= $signed(g1_y1) - $signed(g1_y2);
          
          g2_dy1 <= $signed(g2_y2) - $signed(g2_y3);
          g2_dy2 <= $signed(g2_y3) - $signed(g2_y1);
          g2_dy3 <= $signed(g2_y1) - $signed(g2_y2);
          
          j1_dy1 <= $signed(j1_y2) - $signed(j1_y3);
          j1_dy2 <= $signed(j1_y3) - $signed(j1_y1);
          j1_dy3 <= $signed(j1_y1) - $signed(j1_y2);
          
          j2_dy1 <= $signed(j2_y2) - $signed(j2_y3);
          j2_dy2 <= $signed(j2_y3) - $signed(j2_y1);
          j2_dy3 <= $signed(j2_y1) - $signed(j2_y2);
        end
        
        3'd3: begin
          g1_t1 <= $signed(g1_x1) * $signed(g1_dy1);
          g1_t2 <= $signed(g1_x2) * $signed(g1_dy2);
          g1_t3 <= $signed(g1_x3) * $signed(g1_dy3);
          
          g2_t1 <= $signed(g2_x1) * $signed(g2_dy1);
          g2_t2 <= $signed(g2_x2) * $signed(g2_dy2);
          g2_t3 <= $signed(g2_x3) * $signed(g2_dy3);
          
          j1_t1 <= $signed(j1_x1) * $signed(j1_dy1);
          j1_t2 <= $signed(j1_x2) * $signed(j1_dy2);
          j1_t3 <= $signed(j1_x3) * $signed(j1_dy3);
          
          j2_t1 <= $signed(j2_x1) * $signed(j2_dy1);
          j2_t2 <= $signed(j2_x2) * $signed(j2_dy2);
          j2_t3 <= $signed(j2_x3) * $signed(j2_dy3);
        end
        
        3'd4: begin
          g1_sum <= g1_t1 + g1_t2 + g1_t3;
          g2_sum <= g2_t1 + g2_t2 + g2_t3;
          j1_sum <= j1_t1 + j1_t2 + j1_t3;
          j2_sum <= j2_t1 + j2_t2 + j2_t3;
          
          g1_area <= g1_sum[31] ? -g1_sum : g1_sum;
          g2_area <= g2_sum[31] ? -g2_sum : g2_sum;
          j1_area <= j1_sum[31] ? -j1_sum : j1_sum;
          j2_area <= j2_sum[31] ? -j2_sum : j2_sum;
        end
        
        3'd5: begin
          case (g_tcount_reg)
            2'd0: g_area_sum <= 0;
            2'd1: g_area_sum <= g1_area;
            2'd2: g_area_sum <= g1_area + g2_area;
            default: g_area_sum <= 0;
          endcase
          
          case (j_tcount_reg)
            2'd0: j_area_sum <= 0;
            2'd1: j_area_sum <= j1_area;
            2'd2: j_area_sum <= j1_area + j2_area;
            default: j_area_sum <= 0;
          endcase
        end
      endcase
    end
  end
endmodule