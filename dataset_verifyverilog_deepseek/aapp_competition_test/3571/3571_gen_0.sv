module elder_scroll_display (
  input clk,
  input rst_n,
  input start,
  input [3:0] view_w,
  input [2:0] view_h,
  input [2:0] first_line,
  input [15:0][7:0] text_lines [0:7],
  output reg [7:0][7:0] display_out [0:4],
  output reg [3:0] thumb_pos,
  output reg done
);

reg [3:0] cycle;
reg [7:0][7:0] buffer [0:7];
reg [2:0] buffer_count;
reg [3:0] view_w_reg;
reg [2:0] view_h_reg;
reg [2:0] first_line_reg;

integer i,j;
reg [3:0] line_ptr, char_ptr;
reg [3:0] word_len;
reg wrap_needed;

// Line-wrapping state
reg [3:0] chunk_pos;
reg [7:0] current_word [0:15];

// Thumb position calculation
wire [4:0] numerator = ((view_h_reg - 3'd3) * first_line_reg);
wire [4:0] denominator = (buffer_count > view_h_reg) ? (buffer_count - view_h_reg) : 1;
wire [4:0] calc = numerator / denominator;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    done <= 0;
    cycle <= 0;
    buffer_count <= 0;
    thumb_pos <= 0;
    for (i=0; i<8; i=i+1) buffer[i] <= 64'h2020202020202020; // ASCII spaces
  end
  else begin
    done <= 0;
    if (cycle > 0) cycle <= cycle + 1;
    if (cycle == 15) begin
      done <= 1;
      cycle <= 0;
    end
    
    case (cycle)
      0: begin
        if (start) begin
          cycle <= 1;
          view_w_reg <= view_w;
          view_h_reg <= view_h;
          first_line_reg <= first_line;
          buffer_count <= 0;
          for (i=0; i<8; i=i+1) buffer[i] <= 64'h2020202020202020;
        end
      end
      
      1: begin
        line_ptr <= 0;
        cycle <= 2;
        buffer_count <= 0;
      end
      
      2,3,4,5,6,7,8,9: begin
        if (buffer_count < 8) begin
          // Process line[line_ptr]
          char_ptr = 0;
          chunk_pos = 0;
          wrap_needed = 0;
          // Word extraction
          for (i=0; i<16; i=i+1) begin
            if (text_lines[line_ptr][i] == 8'h20 || i == 15) begin
              word_len = (i == 15) ? (16 - char_ptr) : (i - char_ptr);
              if (word_len > view_w_reg) word_len = view_w_reg;
              
              if (chunk_pos + word_len > view_w_reg) begin
                // Wrap needed
                if (buffer_count < 7) begin
                  buffer_count <= buffer_count + 1;
                  chunk_pos = 0;
                  wrap_needed = 1;
                end
                else word_len = view_w_reg - chunk_pos;
              end
              
              // Copy characters
              for (j=0; j<word_len; j=j+1) begin
                if (buffer_count < 8) begin
                  buffer[buffer_count][chunk_pos+j] <= 
                    (char_ptr+j < 16) ? text_lines[line_ptr][char_ptr+j] : 8'h20;
                end
              end
              
              chunk_pos = chunk_pos + word_len;
              char_ptr = i+1;
              
              if (wrap_needed) begin
                buffer_count <= buffer_count + 1;
                wrap_needed = 0;
                chunk_pos = word_len;
              end
            end
          end
        end
        
        line_ptr <= line_ptr + 1;
        if (line_ptr == 7) cycle <= 10;
      end
      
      10: begin
        // Thumb position calculation
        if (buffer_count > view_h_reg) begin
          thumb_pos <= calc[3:0] < 5 ? calc[3:0] : 4;
        end
        else thumb_pos <= 0;
        cycle <= 11;
      end
      
      11: begin
        // Extract viewport
        for (i=0; i<5; i=i+1) begin
          if (i < view_h_reg && (first_line_reg + i) < 8)
            display_out[i] <= buffer[first_line_reg + i];
          else 
            display_out[i] <= 64'h2020202020202020; // Blank lines
        end
        cycle <= 15;
      end
    endcase
  end
end
endmodule