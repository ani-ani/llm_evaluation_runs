module stamp_nub_minimizer(
  input clk,
  input rst_n,
  input start,
  input [7:0] grid_height,
  input [7:0] grid_width,
  input [63:0] paper_mark,
  output reg [3:0] min_nubs,
  output reg done
);

  typedef enum logic [3:0] {
    IDLE,
    INIT,
    TRY_STAMP_SIZE,
    TRY_PATTERN,
    TRY_X1,
    TRY_Y1,
    CHECK_STAMP1,
    CAPTURE_MASK1,
    TRY_X2,
    TRY_Y2,
    CHECK_STAMP2,
    CHECK_COMBINE,
    RECORD_MIN,
    DONE
  } state_t;
  
  state_t state, next_state;
  reg [63:0] grid_mask;
  reg [63:0] mask1, mask2;
  
  // Iteration counters
  reg [2:0] h_current, w_current;
  reg [5:0] x1, y1, x2, y2;
  reg [2:0] i, j;
  
  // Pattern tracking
  reg [63:0] pattern_reg;
  reg [5:0] pattern_idx;
  reg [6:0] stamp_size;
  wire [5:0] current_max_x = grid_height - h_current;
  wire [5:0] current_max_y = grid_width - w_current;
  
  // Popcount temporary
  wire [6:0] pattern_popcount;
  
  // Flag regs
  reg stamp1_valid, stamp2_valid;
  reg all_covered;

  // Popcount function for pattern
  popcount64 popcount_inst(pattern_reg, pattern_popcount);


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_nubs <= 4'hF;
    end else begin
      case (state)
        IDLE: begin
          if (start) state <= INIT;
          done <= 0;
        end
        
        INIT: begin
          mask1 <= 0;
          mask2 <= 0;
          grid_mask <= 0;
          pattern_reg <= 0;
          h_current <= 3'd1;
          w_current <= 3'd1;
          x1 <= 0;
          y1 <= 0;
          x2 <= 0;
          y2 <= 0;
          min_nubs <= 4'hF;
          pattern_idx <= 0;
          // Generate grid mask
          for (int i=0; i<64; i++) begin
            grid_mask[i] = (i < grid_height * grid_width) ? 1'b1 : 1'b0;
          end
          state <= TRY_STAMP_SIZE;
        end
        
       TRY_STAMP_SIZE: begin
          if (h_current > grid_height) begin
            state <= DONE;
          end else if (w_current > grid_width) begin
            w_current <= 3'd1;
            h_current <= h_current + 1;
          end else begin
            stamp_size = h_current * w_current;
            pattern_idx <= 0;
            pattern_reg <= 0;
            state <= TRY_PATTERN;
          end
       end
       
       TRY_PATTERN: begin
          if (pattern_idx >= (1 << stamp_size)) begin
            w_current <= w_current + 1;
            state <= TRY_STAMP_SIZE;
          end else begin
            pattern_reg <= pattern_idx;
            x1 <= 0;
            state <= TRY_X1;
          end
       end
       
       TRY_X1: begin
          if (x1 > current_max_x) begin
            pattern_idx <= pattern_idx + 1;
            state <= TRY_PATTERN;
          end else begin
            y1 <= 0;
            state <= TRY_Y1;
          end
       end
       
       TRY_Y1: begin
          if (y1 > current_max_y) begin
            x1 <= x1 + 1;
            state <= TRY_X1;
          end else begin
            // Check stamp1 placement validity
            stamp1_valid <= 1'b1;
            i <= 0;
            j <= 0;
            state <= CHECK_STAMP1;
          end
       end
       
       CHECK_STAMP1: begin
          if (i == h_current) begin
            if (stamp1_valid) state <= CAPTURE_MASK1;
            else begin
              y1 <= y1 + 1;
              state <= TRY_Y1;
            end
          end else if (j == w_current) begin
            i <= i + 1;
            j <= 0;
          end else begin
            if (pattern_reg[i*w_current + j] && 
                ((x1 + i) >= grid_height || (y1 + j) >= grid_width || 
                 !paper_mark[8*(x1+i) + (y1+j)])) begin
              stamp1_valid <= 1'b0;
            end
            j <= j + 1;
          end
       end
       
       CAPTURE_MASK1: begin
          mask1 <= 0;
          for (int i=0; i<8; i++) begin
            for (int j=0; j<8; j++) begin
              if (i < h_current && j < w_current && (x1 + i) < 8 && (y1 + j) < 8) begin
                mask1[8*(x1+i) + (y1+j)] <= pattern_reg[i*w_current + j];
              end
            end
          end
          x2 <= 0;
          state <= TRY_X2;
       end
       
       TRY_X2: begin
          if (x2 > current_max_x) begin
            y1 <= y1 + 1;
            state <= TRY_Y1;
          end else begin
            y2 <= 0;
            state <= TRY_Y2;
          end
       end
       
       TRY_Y2: begin
          if (y2 > current_max_y) begin
            x2 <= x2 + 1;
            state <= TRY_X2;
          end else begin
            // Check stamp2 validity
            stamp2_valid <= 1'b1;
            i <= 0;
            j <= 0;
            state <= CHECK_STAMP2;
          end
       end
       
       CHECK_STAMP2: begin
          if (i == h_current) begin
            if (stamp2_valid) state <= CHECK_COMBINE;
            else begin
              y2 <= y2 + 1;
              state <= TRY_Y2;
            end
          end else if (j == w_current) begin
            i <= i + 1;
            j <= 0;
          } else begin
            if (pattern_reg[i*w_current + j] && 
                ((x2 + i) >= grid_height || (y2 + j) >= grid_width || 
                 !paper_mark[8*(x2+i) + (y2+j)])) begin
              stamp2_valid <= 1'b0;
            end
            j <= j + 1;
          end
       end
       
       CHECK_COMBINE: begin
          mask2 <= 0;
          for (int i=0; i<8; i++) begin
            for (int j=0; j<8; j++) begin
              if (i < h_current && j < w_current && (x2 + i) < 8 && (y2 + j) < 8) begin
                mask2[8*(x2+i) + (y2+j)] <= pattern_reg[i*w_current + j];
              end
            end
          end
          all_covered <= ((mask1 | mask2) & grid_mask) == (paper_mark & grid_mask);
          state <= RECORD_MIN;
       end
       
       RECORD_MIN: begin
          if (all_covered && (pattern_popcount < min_nubs)) begin
            min_nubs <= pattern_popcount[3:0];
          end
          y2 <= y2 + 1;
          state <= TRY_Y2;
       end
       
       DONE: begin
          done <= 1'b1;
          if (!start) state <= IDLE;
       end
      endcase
    end
  end

endmodule

module popcount64 (
  input [63:0] in,
  output reg [6:0] out
);
  always_comb begin
    out = 0;
    for (int i=0; i<64; i++) 
      out += in[i];
  end
endmodule