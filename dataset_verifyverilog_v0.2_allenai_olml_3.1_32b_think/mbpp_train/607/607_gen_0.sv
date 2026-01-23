module string_matcher (input clk,input rst_n,input start,input [7:0] text [0:7],input [7:0] pattern [0:3],input [2:0] pattern_length,output reg [2:0] start_index,output reg [2:0] end_index,output reg found,output reg done);
localparam IDLE = 3'd0;
localparam COMPARE = 3'd1;
localparam SLIDE = 3'd2;
localparam FOUND = 3'd3;
localparam NOT_FOUND = 3'd4;
reg [2:0] state, current_position;
reg [7:0] saved_text [0:7];
reg [7:0] saved_pattern [0:3];
reg [2:0] saved_pattern_length;
reg [2:0] start_index, end_index;
reg found, done;
reg match;
always_ff @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      current_position <= 0;
      saved_text <= 0;
      saved_pattern <= 0;
      saved_pattern_length <=0;
      start_index <=0;
      end_index <=0;
      found <=0;
      done <=0;
      match <=0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               saved_text <= text;
               saved_pattern <= pattern;
               saved_pattern_length <= pattern_length;
               current_position <=0;
               state <= COMPARE;
            end else begin
               state <= IDLE;
            end
         end
         COMPARE: begin
            match = 0;
            if (saved_pattern_length ==4) begin
               match = (saved_text[current_position +0] == saved_pattern[0] &&
                      saved_text[current_position +1] == saved_pattern[1] &&
                      saved_text[current_position +2] == saved_pattern[2] &&
                      saved_text[current_position +3] == saved_pattern[3]);
            end else if (saved_pattern_length ==3) begin
               match = (saved_text[current_position +0] == saved_pattern[0] &&
                      saved_text[current_position +1] == saved_pattern[1] &&
                      saved_text[current_position +2] == saved_pattern[2]);
            end else if (saved_pattern_length ==2) begin
               match = (saved_text[current_position +0] == saved_pattern[0] &&
                      saved_text[current_position +1] == saved_pattern[1]);
            end else if (saved_pattern_length ==1) begin
               match = (saved_text[current_position +0] == saved_pattern[0]);
            end
            if (match) begin
               state <= FOUND;
               start_index <= current_position;
               end_index <= current_position + saved_pattern_length;
               found <=1;
               done <=1;
            end else begin
               if (current_position < (8 - saved_pattern_length)) begin
                  state <= SLIDE;
               end else begin
                  state <= NOT_FOUND;
                  start_index <=0;
                  end_index <=0;
                  found <=0;
                  done <=1;
               end
            end
         end
         SLIDE: begin
            current_position <= current_position +1;
            state <= COMPARE;
         end
         FOUND: begin
            state <= FOUND;
         end
         NOT_FOUND: begin
            state <= NOT_FOUND;
         end
      endcase
   end
end