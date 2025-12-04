module ad_remover(
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [0:15][0:15],
  output reg [7:0] out_grid [0:15][0:15],
  output reg done
);

  /* Constants & Definitions */
  localparam IMG_CNT = 8;
  typedef enum logic [1:0] {IDLE, WORKING, FINISH} state_t;
  
  /* Grid Buffers */
  reg [7:0] grid_buffer [0:15][0:15];

  /* Stage Registers */
  state_t state;
  reg [3:0] x_ctr, y_ctr;
  reg [3:0] i_left[0:7], i_right[0:7], i_top[0:7], i_bottom[0:7];
  reg [8:0] image_area[0:7];
  reg [7:0] img_valid;
  reg [2:0] img_count;
  
  /* Processing Registers */
  reg found_invalid;
  reg [2:0] smallest_idx;
  reg [8:0] smallest_area;

  /* Temporal Processing Signals */
  wire current_pos_char;
  wire cell_is_inside_rect;
  reg [7:0] temp_border;
  reg [3:0] probe_x, probe_y;
  
  /* Function: is_valid_char */
  function automatic logic is_valid_char (input [7:0] c);
    return ((c >= "A" && c <= "Z") ||
            (c >= "a" && c <= "z") ||
            (c >= "0" && c <= "9") ||
            (c == "?") || (c == "!") ||
            (c == ",") || (c == ".") ||
            (c == " "));
  endfunction

  /* Stage 1: Border detection */
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      x_ctr <= 0;
      y_ctr <= 0;
      img_count <= 0;
      img_valid <= 8'b0;
      for (int i=0; i<IMG_CNT; i++) begin
        i_left[i] <= 0;
        i_right[i] <= 0;
        i_top[i] <= 0;
        i_bottom[i] <= 0;
        image_area[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            grid_buffer <= grid;
            state <= WORKING;
            for (int i=0; i<16; i++) for(int j=0; j<16; j++) out_grid[i][j] <= grid[i][j];
          end
        end

        WORKING: begin
          if (x_ctr < 14) x_ctr <= x_ctr + 1;
          else begin
            x_ctr <= 0;
            y_ctr <= (y_ctr < 15) ? y_ctr + 1 : 15;
          end
          
          // Check for '+' at current cell (border candidate)
          if (grid_buffer[y_ctr][x_ctr] == "+") begin
            temp_border <= 1;
            for (probe_x = x_ctr+1; probe_x < 16; probe_x++) begin
              if (grid_buffer[y_ctr][probe_x] != "+" && grid_buffer[y_ctr][probe_x] != "-") temp_border <= 0;
              if (grid_buffer[y_ctr][probe_x] == "+") break;
            end
            if (probe_x - x_ctr >= 3 && temp_border) begin
              for (probe_y = y_ctr+1; probe_y < 16; probe_y++) begin
                if (grid_buffer[probe_y][x_ctr] != "+" && grid_buffer[probe_y][x_ctr] != "|") temp_border <= 0;
                if (grid_buffer[probe_y][x_ctr] == "+") break;
              end
              if (probe_y - y_ctr >= 3 && temp_border && 
                  grid_buffer[probe_y][probe_x] == "+" &&
                  img_count < IMG_CNT) begin
                i_left[img_count]   <= x_ctr;
                i_right[img_count]  <= probe_x;
                i_top[img_count]    <= y_ctr;
                i_bottom[img_count] <= probe_y;
                image_area[img_count] <= (probe_x - x_ctr + 1) * (probe_y - y_ctr + 1);
                img_count <= img_count + 1;
              end
            end
          end

          // Update escape condition
          if (x_ctr == 15 && y_ctr == 15) begin
            state <= FINISH;
            done <= 1;
          end
        end

        FINISH: begin
          done <= 0;
          state <= IDLE;
          // Stage 3 result update
          smallest_idx = 0;
          smallest_area = 9'h1FF;  // Initialize to max possible (since 16x16=256)
          found_invalid = 0;
          for (int k=0; k<img_count; k++) begin : VALIDITY_CHECK
            // Stage 2: Check interior validity (performed during WORKING phase for simplicity)
            img_valid[k] <= 1;
            for (int yy=i_top[k]+1; yy<i_bottom[k]; yy++) begin
              for (int xx=i_left[k]+1; xx<i_right[k]; xx++) begin
                if (!is_valid_char(grid_buffer[yy][xx])) img_valid[k] <= 0;
              end
            end
            // Stage 3: Find smallest invalid image
            if (!img_valid[k] && image_area[k] < smallest_area) begin
              smallest_idx <= k;
              smallest_area <= image_area[k];
              found_invalid <= 1;
            end
          end
          
          // Replace flagged image with spaces
          if (found_invalid) begin
            for (int yy=i_top[smallest_idx]; yy<=i_bottom[smallest_idx]; yy++) begin
              for (int xx=i_left[smallest_idx]; xx<=i_right[smallest_idx]; xx++) begin
                out_grid[yy][xx] <= " ";
              end
            end
          end
        end
      endcase
    end
  end
endmodule