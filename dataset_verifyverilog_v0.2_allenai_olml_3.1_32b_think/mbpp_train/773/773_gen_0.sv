module substring_matcher (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [7:0] text [0:15], // 16-byte text array
   input [7:0] pattern [0:7], // 8-byte pattern array
   input [4:0] text_len,
   input [3:0] pattern_len,
   output reg [3:0] start_pos,
   output reg [3:0] end_pos,
   output reg match_found,
   output reg done
);

localparam IDLE = 3'd0,
          SEARCHING = 3'd1,
          MATCHING = 3'd2,
          COMPLETE = 3'd3,
          NOT_FOUND = 3'd4;

reg [2:0] state;
reg [4:0] text_index;
reg [3:0] pattern_index;
reg [7:0] latched_text_array [0:15];
reg [7:0] latched_pattern_array [0:7];
reg [4:0] latched_text_len;
reg [3:0] latched_pattern_len;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      text_index <= 0;
      pattern_index <= 0;
      match_found <= 0;
      done <= 0;
      latched_text_array <= 0;
      latched_pattern_array <= 0;
      latched_text_len <= 0;
      latched_pattern_len <= 0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            latched_text_array <= text;
            latched_pattern_array <= pattern;
            latched_text_len <= text_len;
            latched_pattern_len <= pattern_len;
            if (latched_pattern_len == 0 || latched_text_len < latched_pattern_len) begin
               state <= NOT_FOUND;
               match_found <= 0;
               done <= 1;
               start_pos <= 15;
               end_pos <= 15;
            end else begin
               state <= SEARCHING;
               text_index <= 0;
               pattern_index <= 0;
            end
         end
      end else if (state == SEARCHING) begin
         if (latched_text_array[text_index] == latched_pattern_array[0]) begin
            state <= MATCHING;
            pattern_index <= 1;
         end else begin
            if (text_index < (latched_text_len - latched_pattern_len)) begin
               text_index <= text_index + 1;
            end else begin
               state <= NOT_FOUND;
               match_found <= 0;
               done <= 1;
               start_pos <= 15;
               end_pos <= 15;
            end
         end
      end else if (state == MATCHING) begin
         if (pattern_index < latched_pattern_len) begin
            localparam int addr = text_index + pattern_index;
            if (addr < latched_text_len) begin
               if (latched_text_array[addr] == latched_pattern_array[pattern_index]) begin
                  pattern_index <= pattern_index + 1;
                  if (pattern_index == latched_pattern_len) begin
                     state <= COMPLETE;
                     match_found <= 1;
                     done <= 1;
                     start_pos <= text_index;
                     end_pos <= text_index + latched_pattern_len - 1;
                  end else begin
                     state <= MATCHING;
                  end
               end else begin
                  text_index <= text_index + 1;
                  pattern_index <= 0;
                  state <= SEARCHING;
                  if (text_index > (latched_text_len - latched_pattern_len)) begin
                     state <= NOT_FOUND;
                     match_found <= 0;
                     done <= 1;
                     start_pos <= 15;
                     end_pos <= 15;
                  end
               end
            end else begin
               state <= NOT_FOUND;
               match_found <= 0;
               done <= 1;
               start_pos <= 15;
               end_pos <= 15;
            end
         end else begin
            state <= COMPLETE;
            match_found <= 1;
            done <= 1;
            start_pos <= text_index;
            end_pos <= text_index + latched_pattern_len - 1;
         end
      end else if (state == COMPLETE) begin
         done <= 1;
         match_found <= 1;
         start_pos <= text_index;
         end_pos <= text_index + latched_pattern_len - 1;
      end else if (state == NOT_FOUND) begin
         done <= 1;
         match_found <= 0;
         start_pos <= 15;
         end_pos <= 15;
      end
   end
endmodule