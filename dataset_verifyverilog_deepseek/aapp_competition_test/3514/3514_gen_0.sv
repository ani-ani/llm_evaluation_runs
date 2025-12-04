module max_bombs_disarmed (
  input clk,
  input rst_n,
  input start,
  input [63:0] grid_data,
  output reg [2:0] max_count,
  output reg done
);

  reg [63:0] grid_data_reg;
  reg [7:0] row_armed_reg;
  reg [7:0] col_armed_reg;
  reg [5:0] total_armed_reg;
  reg [2:0] delay_cnt;
  reg process_flag;
  reg overlap;
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      grid_data_reg <= 64'd0;
      row_armed_reg <= 8'd0;
      col_armed_reg <= 8'd0;
      total_armed_reg <= 6'd0;
      max_count <= 3'd0;
      done <= 1'b0;
      delay_cnt <= 3'd0;
      process_flag <= 1'b0;
      overlap <= 1'b0;
    end else begin
      if (start) begin
        grid_data_reg <= grid_data;
        delay_cnt <= 3'd0;
        process_flag <= 1'b1;
      end
      
      if (process_flag) begin
        // Cycle 1: compute row/col armed & total
        if (delay_cnt == 0) begin
          for (int i=0; i<8; i++) row_armed_reg[i] <= |grid_data_reg[i*8 +:8];
          for (int j=0; j<8; j++) begin
            col_armed_reg[j] <= |{grid_data_reg[j], grid_data_reg[j+8], grid_data_reg[j+16], 
                                  grid_data_reg[j+24], grid_data_reg[j+32], grid_data_reg[j+40], 
                                  grid_data_reg[j+48], grid_data_reg[j+56]};
          end
          total_armed_reg <= $countones(grid_data_reg);
          overlap <= 1'b0;
          delay_cnt <= delay_cnt + 1;
        end else if (delay_cnt == 1) begin
          // Cycle 2: compute overlap & max_count
          for (int i=0; i<8; i++) begin
            for (int j=0; j<8; j++) begin
              if (grid_data_reg[i*8 + j] && row_armed_reg[i] && col_armed_reg[j])
                overlap <= 1'b1;
            end
          end
          
          if (total_armed_reg == 0)
            max_count <= 3'd0;
          else if (overlap)
            max_count <= (total_armed_reg > 7) ? 3'd7 : total_armed_reg[2:0];
          else
            max_count <= (total_armed_reg > 8) ? 3'd7 : (total_armed_reg - 1)[2:0];
          
          done <= 1'b1;
          delay_cnt <= delay_cnt + 1;
        end else begin
          // Cycle 3: Reset done
          done <= 1'b0;
          process_flag <= 1'b0;
        end
      end
    end
  end

endmodule