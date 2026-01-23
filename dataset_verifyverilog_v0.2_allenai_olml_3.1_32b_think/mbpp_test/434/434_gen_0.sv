module regex_matcher (input clk,input rst_n,input start,input [7:0] char_in,input [2:0] char_index,output reg match_result,output reg done);
localparam IDLE = 2'b00;
localparam SEARCH = 2'b01;
localparam FOUND_A = 2'b10;
localparam COMPLETE = 2'b11;

reg [1:0] state, next_state;

always @(*) begin
    next_state = state;
    case (state)
       IDLE: begin
          if (start) next_state = SEARCH;
          else next_state = IDLE;
       end
       SEARCH: begin
          if (char_in == 8'h61) next_state = FOUND_A;
          else if (char_in == 8'h62) next_state = SEARCH;
          else next_state = SEARCH;
          if (char_index == 7) next_state = COMPLETE;
       end
       FOUND_A: begin
          if (char_in == 8'h62) next_state = FOUND_A;
          else if (char_in == 8'h61) next_state = FOUND_A;
          else next_state = SEARCH;
          if (char_index ==7) next_state = COMPLETE;
       end
       COMPLETE: next_state = COMPLETE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
       state <= IDLE;
       match_result <= 0;
       done <= 0;
    end else begin
       state <= next_state;
       if (state == FOUND_A && char_in == 8'h62) begin
          match_result <= 1;
       end
       done <= (state == COMPLETE);
    end
end
endmodule