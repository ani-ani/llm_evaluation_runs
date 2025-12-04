module complex_to_polar(input clk, input rst_n, input start, input [31:0] real_part, input [31:0] imag_part, output reg [31:0] magnitude, output reg [31:0] phase, output reg done);
  localparam CORDIC_ITER = 16;
  typedef enum {IDLE, COMPUTE, DONE} state_t;
  state_t state;
  
  reg [3:0] count;
  reg [31:0] x_reg, y_reg, angle_reg;
  reg [31:0] angle_table [0:15];
  reg start_delay;
  
  localparam K = 32'h0001A5ED;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_delay <= 0;
    end else begin
      start_delay <= start;
    end
  end
  
  wire start_pulse = start & ~start_delay;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      magnitude <= 0;
      phase <= 0;
      count <= 0;
      x_reg <= 0;
      y_reg <= 0;
      angle_reg <= 0;
      
      angle_table[0] <= 32'h0000C90F;
      angle_table[1] <= 32'h000076B1;
      angle_table[2] <= 32'h00003EB6;
      angle_table[3] <= 32'h00001FD5;
      angle_table[4] <= 32'h00000FFA;
      angle_table[5] <= 32'h000007FF;
      angle_table[6] <= 32'h000003FF;
      angle_table[7] <= 32'h000001FF;
      angle_table[8] <= 32'h000000FF;
      angle_table[9] <= 32'h0000007F;
      angle_table[10] <= 32'h0000003F;
      angle_table[11] <= 32'h0000001F;
      angle_table[12] <= 32'h0000000F;
      angle_table[13] <= 32'h00000007;
      angle_table[14] <= 32'h00000003;
      angle_table[15] <= 32'h00000001;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start_pulse) begin
            x_reg <= real_part;
            y_reg <= imag_part;
            angle_reg <= 0;
            count <= 0;
            state <= COMPUTE;
          end
        end
        
        COMPUTE: begin
          if (count < CORDIC_ITER - 1) begin
            reg dir = y_reg[31];
            reg [31:0] x_shift = x_reg >>> count;
            reg [31:0] y_shift = y_reg >>> count;
            
            if (dir) begin
              x_reg <= x_reg - y_shift;
              y_reg <= y_reg + x_shift;
              angle_reg <= angle_reg - angle_table[count];
            end else begin
              x_reg <= x_reg + y_shift;
              y_reg <= y_reg - x_shift;
              angle_reg <= angle_reg + angle_table[count];
            end
            count <= count + 1;
          end else begin
            reg dir = y_reg[31];
            reg [31:0] x_shift = x_reg >>> count;
            reg [31:0] y_shift = y_reg >>> count;
            
            if (dir) begin
              x_reg <= x_reg - y_shift;
              y_reg <= y_reg + x_shift;
              angle_reg <= angle_reg - angle_table[count];
            end else begin
              x_reg <= x_reg + y_shift;
              y_reg <= y_reg - x_shift;
              angle_reg <= angle_reg + angle_table[count];
            end
            state <= DONE;
          end
        end
        
        DONE: begin
          magnitude <= (x_reg * K) >>> 16;
          phase <= angle_reg;
          done <= 1;
          
          if (start_pulse) begin
            x_reg <= real_part;
            y_reg <= imag_part;
            angle_reg <= 0;
            count <= 0;
            done <= 0;
            state <= COMPUTE;
          end
        end
      endcase
    end
  end
endmodule