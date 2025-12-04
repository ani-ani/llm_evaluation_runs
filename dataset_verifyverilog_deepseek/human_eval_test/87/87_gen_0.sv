module find_coordinates(
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] data_row0,
  input [7:0][7:0] data_row1,
  input [7:0][7:0] data_row2,
  input [7:0][7:0] data_row3,
  input [7:0][7:0] data_row4,
  input [7:0][7:0] data_row5,
  input [7:0][7:0] data_row6,
  input [7:0][7:0] data_row7,
  input [7:0][2:0] row_len,
  input [7:0] target,
  output reg done,
  output reg [4:0] count,
  output reg [15:0][5:0] coordinates
);
  
  typedef enum logic [2:0] { IDLE, PROCESS_ROW, PROCESS_COL, NEXT_ROW, DONE } state_t;
  reg [2:0] state;
  reg [3:0] row_counter;
  reg [3:0] col_counter;
  reg [4:0] count_reg;
  reg [15:0][5:0] coord_reg;
  
  wire [7:0] sel_data;
  wire [2:0] curr_col = col_counter[2:0];
  
  always_comb begin
    case (row_counter[2:0])
      3'd0: sel_data = data_row0[curr_col];
      3'd1: sel_data = data_row1[curr_col];
      3'd2: sel_data = data_row2[curr_col];
      3'd3: sel_data = data_row3[curr_col];
      3'd4: sel_data = data_row4[curr_col];
      3'd5: sel_data = data_row5[curr_col];
      3'd6: sel_data = data_row6[curr_col];
      3'd7: sel_data = data_row7[curr_col];
      default: sel_data = 8'b0;
    endcase
  end
  
  wire [3:0] nxt_col = col_counter - 1;
  wire col_underflow = (nxt_col == 4'b1111);
  wire match = (sel_data == target) && (count_reg < 5'd16);
  wire cnt_full = (count_reg + match) >= 5'd16;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      row_counter <= 4'b0;
      col_counter <= 4'b0;
      count_reg <= 5'b0;
      coord_reg <= '0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) begin
            row_counter <= 4'b0;
            count_reg <= 5'b0;
            coord_reg <= '0;
            state <= PROCESS_ROW;
          end
        end
        
        PROCESS_ROW: begin
          if (row_len[row_counter[2:0]] != 3'b0) begin
            col_counter <= {1'b0, row_len[row_counter[2:0]]} - 1'b1;
            state <= PROCESS_COL;
          end else
            state <= NEXT_ROW;
        end
        
        PROCESS_COL: begin
          col_counter <= nxt_col;
          if (match) begin
            coord_reg[count_reg] <= {row_counter[2:0], curr_col};
            count_reg <= count_reg + 1'b1;
          end
          
          if (col_underflow)
            state <= NEXT_ROW;
          else if (cnt_full)
            state <= DONE;
        end
        
        NEXT_ROW: begin
          row_counter <= row_counter + 1'b1;
          if (row_counter == 4'd7)
            state <= DONE;
          else
            state <= PROCESS_ROW;
        end
        
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
  
  assign count = count_reg;
  assign coordinates = coord_reg;
  
endmodule