module josip_painter(
  input clk,
  input rst_n,
  input start,
  input [63:0] target_image,
  output reg [6:0] min_difference,
  output reg [63:0] output_image,
  output reg done
);
  
  localparam IDLE = 3'b000;
  localparam CALC_N = 3'b001;
  localparam INIT_WORK = 3'b010;
  localparam PROCESS_SQUARE = 3'b011;
  localparam NEXT_SQUARE = 3'b100;
  localparam NEXT_K = 3'b101;
  localparam FINAL_DIFF = 3'b110;
  localparam DONE_STATE = 3'b111;
  
  reg [2:0] state, next_state;
  reg [1:0] current_k;
  reg [5:0] square_counter;
  reg [2:0] N_reg;
  reg [1:0] max_k;
  reg [63:0] target_reg;
  reg [63:0] working_image;
  
  function automatic [63:0] gen_mask;
    input [1:0] k;
    input [5:0] sq_idx;
    input [2:0] N_val;
    integer tile_size, grid_size;
    integer sq_row, sq_col;
    integer row, col, pos;
    integer row_offs, col_offs;
    begin
      gen_mask = 64'd0;
      tile_size = 1 << k;
      grid_size = N_val >> k;
      sq_row = (sq_idx / grid_size) * tile_size;
      sq_col = (sq_idx % grid_size) * tile_size;
      
      for (row_offs = 0; row_offs < tile_size; row_offs = row_offs + 1) begin
        for (col_offs = 0; col_offs < tile_size; col_offs = col_offs + 1) begin
          row = sq_row + row_offs;
          col = sq_col + col_offs;
          if (row < N_val && col < N_val) begin
            pos = 63 - (row * 8 + col);
            gen_mask[pos] = 1'b1;
          end
        end
      end
    end
  endfunction
  
  function automatic [6:0] popcount;
    input [63:0] vec;
    integer i;
    begin
      popcount = 7'd0;
      for (i=0; i<64; i=i+1)
        popcount = popcount + vec[i];
    end
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_k <= 2'd0;
      square_counter <= 6'd0;
      N_reg <= 3'd0;
      working_image <= 64'd0;
      done <= 1'b0;
      output_image <= 64'd0;
      min_difference <= 7'd0;
      target_reg <= 64'd0;
      max_k <= 2'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            target_reg <= target_image;
            state <= CALC_N;
          end
        end
        
        CALC_N: begin
          if (|target_image[63:16])      N_reg <= 3'd8;
          else if (|target_image[63:4])  N_reg <= 3'd4;
          else if (|target_image[63:1])  N_reg <= 3'd2;
          else                          N_reg <= 3'd1;
          
          if (N_reg == 3'd8)      max_k <= 2'd3;
          else if (N_reg == 3'd4) max_k <= 2'd2;
          else if (N_reg == 3'd2) max_k <= 2'd1;
          else                    max_k <= 2'd0;
          
          state <= INIT_WORK;
        end
        
        INIT_WORK: begin
          working_image <= target_reg;
          current_k <= 2'd0;
          square_counter <= 6'd0;
          state <= PROCESS_SQUARE;
        end
        
        PROCESS_SQUARE: begin
          if (current_k > 0) begin
            reg [63:0] mask;
            reg [63:0] target_bits;
            reg [63:0] current_bits;
            reg [6:0] white_diff, black_diff, div_diff;
            mask = gen_mask(current_k, square_counter, N_reg);
            target_bits = target_reg & mask;
            current_bits = working_image & mask;
            
            white_diff = popcount(target_bits);
            black_diff = popcount(mask & ~target_reg);
            div_diff = popcount((working_image ^ target_reg) & mask);
            
            if (white_diff <= black_diff && white_diff <= div_diff) begin
              working_image <= working_image & ~mask;
            end else if (black_diff <= white_diff && black_diff <= div_diff) begin
              working_image <= working_image | mask;
            end
            
          end
          state <= NEXT_SQUARE;
        end
        
        NEXT_SQUARE: begin
          integer grid_size;
          grid_size = N_reg >> current_k;
          if (square_counter < (grid_size * grid_size) - 1) begin
            square_counter <= square_counter + 1;
            state <= PROCESS_SQUARE;
          end else begin
            state <= NEXT_K;
          end
        end
        
        NEXT_K: begin
          if (current_k < max_k) begin
            current_k <= current_k + 1;
            square_counter <= 6'd0;
            state <= PROCESS_SQUARE;
          end else begin
            state <= FINAL_DIFF;
          end
        end
        
        FINAL_DIFF: begin
          min_difference <= popcount(working_image ^ target_reg);
          output_image <= working_image;
          done <= 1'b1;
          state <= DONE_STATE;
        end
        
        DONE_STATE: begin
          if (~start) state <= IDLE;
        end
        
      endcase
    end
  end
endmodule