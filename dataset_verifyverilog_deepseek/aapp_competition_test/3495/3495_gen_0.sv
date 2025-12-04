module robotic_arm_controller(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [15:0] L_0,
  input [15:0] L_1,
  input [15:0] L_2,
  input [15:0] L_3,
  input [15:0] L_4,
  input [15:0] L_5,
  input [15:0] L_6,
  input [15:0] L_7,
  input [31:0] target_x,
  input [31:0] target_y,
  output reg [31:0] x_0, y_0,
  output reg [31:0] x_1, y_1,
  output reg [31:0] x_2, y_2,
  output reg [31:0] x_3, y_3,
  output reg [31:0] x_4, y_4,
  output reg [31:0] x_5, y_5,
  output reg [31:0] x_6, y_6,
  output reg [31:0] x_7, y_7,
  output reg done
);

  reg [2:0] counter;
  reg computing;
  reg [31:0] x_prev, y_prev;
  reg [15:0] curr_L;
  reg [31:0] dx, dy;
  reg [63:0] dist_squared;
  wire [31:0] sqrt_val;
  reg [31:0] curr_x, curr_y;
  wire [31:0] unit_x, unit_y;
  reg [31:0] dist_scaled;
  parameter THRESHOLD_SQ = 655 * 655 * (1 << 16);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {x_0, y_0, x_1, y_1, x_2, y_2, x_3, y_3, x_4, y_4, x_5, y_5, x_6, y_6, x_7, y_7} <= '0;
      done <= 1'b0;
      counter <= 3'b0;
      computing <= 1'b0;
      x_prev <= '0;
      y_prev <= '0;
    end
    else begin
      if (start && !computing) begin
        computing <= 1'b1;
        counter <= 3'b0;
        done <= 1'b0;
        x_prev <= '0;
        y_prev <= '0;
      end
      else if (computing) begin
        if (counter < N) begin
          dx <= target_x - x_prev;
          dy <= target_y - y_prev;
          dist_squared <= dx*dx + dy*dy;
          curr_L <= (counter == 0) ? L_0 :
                   (counter == 1) ? L_1 :
                   (counter == 2) ? L_2 :
                   (counter == 3) ? L_3 :
                   (counter == 4) ? L_4 :
                   (counter == 5) ? L_5 :
                   (counter == 6) ? L_6 : L_7;

          if (dist_squared < THRESHOLD_SQ) begin
            curr_x <= target_x;
            curr_y <= target_y;
          end
          else begin
            dist_scaled <= sqrt_val;
            if (dist_scaled == 0) begin
              curr_x <= x_prev;
              curr_y <= y_prev;
            end
            else begin
              unit_x <= (dx[31] ? -( (-dx) / dist_scaled ) : dx / dist_scaled);
              unit_y <= (dy[31] ? -( (-dy) / dist_scaled ) : dy / dist_scaled);
              curr_x <= x_prev + ((unit_x * curr_L) >>> 16);
              curr_y <= y_prev + ((unit_y * curr_L) >>> 16);
            end
          end

          case (counter)
            0: begin x_0 <= curr_x; y_0 <= curr_y; end
            1: begin x_1 <= curr_x; y_1 <= curr_y; end
            2: begin x_2 <= curr_x; y_2 <= curr_y; end
            3: begin x_3 <= curr_x; y_3 <= curr_y; end
            4: begin x_4 <= curr_x; y_4 <= curr_y; end
            5: begin x_5 <= curr_x; y_5 <= curr_y; end
            6: begin x_6 <= curr_x; y_6 <= curr_y; end
            7: begin x_7 <= curr_x; y_7 <= curr_y; end
          endcase

          x_prev <= (counter < N-1) ? curr_x : x_prev;
          y_prev <= (counter < N-1) ? curr_y : y_prev;
          counter <= counter + 1;
        end
        else begin
          computing <= 1'b0;
          done <= 1'b1;
        end
      end
      else begin
        done <= 1'b0;
      end
    end
  end

  fixed_point_sqrt sqrt_calc(.num(dist_squared), .sqrt_val(sqrt_val));
  
endmodule

module fixed_point_sqrt(
  input [63:0] num,
  output reg [31:0] sqrt_val
);
  
  reg [31:0] root;
  reg [33:0] test;
  reg [63:0] remainder;
  integer i;
  
  always @(*) begin
    root = 0;
    remainder = num;
    for (i = 0; i < 32; i = i+1) begin
      root = root << 1;
      test = (root << 1) + 1;
      if (remainder >= (test << (2*(31-i)) )) begin
        remainder = remainder - (test << (2*(31-i)));
        root = root + 1;
      end
    end
    sqrt_val = root;
  end

endmodule