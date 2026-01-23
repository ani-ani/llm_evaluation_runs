module name_filter_sum (input clk, input rst_n, input start, input [7:0] char_data, input valid_char, output reg [2:0] name_addr, output reg [2:0] char_addr, output reg fetch_next, output reg [7:0] result, output reg done, output reg error);
// Internal signals
reg [2:0] current_name;
reg [2:0] current_char;
reg [7:0] accumulated_sum;
reg [2:0] total_names;
reg [2:0] current_length;
reg is_valid;
reg [1:0] state; // 2 bits, 4 states
localparam STATE_IDLE = 2'd0;
localparam STATE_READING_NAME = 2'd1;
localparam STATE_EVALUATING_NAME = 2'd2;
localparam STATE_DONE = 2'd3;
reg error_flag;

// Initialize on reset
always_ff @(posedge clk) begin
   if (!rst_n) begin
      current_name <= 3'd0;
      current_char <=3'd0;
      accumulated_sum <=8'd0;
      total_names <=3'd0;
      current_length <=3'd0;
      is_valid <=1'b0;
      error_flag <=1'b0;
      state <= STATE_IDLE;
   end else begin
      case (state)
         STATE_IDLE: begin
            if (start && total_names < 3'd8) begin
               current_name <= total_names;
               current_char <=3'd0;
               current_length <=3'd0;
               is_valid <=1'b1;
               state <= STATE_READING_NAME;
            end else begin
               state <= STATE_IDLE;
            end
         end
         STATE_READING_NAME: begin
            if (valid_char) begin
               if (char_data == 8'd0) begin
                  current_length <= current_char;
                  state <= STATE_EVALUATING_NAME;
               end else begin
                  if (current_char ==3'd0) begin
                     if (char_data >=8'd65 && char_data <=8'd90) begin
                        is_valid <=1'b1;
                     end else begin
                        is_valid <=1'b0;
                     end
                  end else begin
                     if (char_data >=8'd97 && char_data <=8'd122) begin
                        is_valid <= is_valid;
                     end else begin
                        is_valid <=1'b0;
                     end
                  end
                  current_length <= current_length +1;
                  if (current_char <3'd7) begin
                     current_char <= current_char +1;
                  end else begin
                     current_length <=4'd8;
                     state <= STATE_EVALUATING_NAME;
                  end
               end
            end
         end
         STATE_EVALUATING_NAME: begin
            if (current_length <=3'd0 || !is_valid) begin
               error_flag <= error_flag | 1'b1;
            end
            if (current_length >3'd0 && is_valid) begin
               accumulated_sum <= accumulated_sum + current_length;
            end
            total_names <= total_names +1;
            if (total_names <3'd8) begin
               current_char <=3'd0;
               current_length <=3'd0;
               is_valid <=1'b1;
               current_name <= total_names;
               state <= STATE_READING_NAME;
            end else begin
               state <= STATE_DONE;
            end
         end
         STATE_DONE: begin
            state <= STATE_DONE;
         end
      endcase
   end
end

// Combinational outputs
assign name_addr = (state == STATE_READING_NAME) ? current_name : 3'd0;
assign char_addr = (state == STATE_READING_NAME) ? current_char : 3'd0;
assign fetch_next = (state == STATE_READING_NAME) ? 1'b1 : 1'b0;
assign result = (state == STATE_DONE) ? accumulated_sum : 8'd0;
assign done = (state == STATE_DONE);
assign error = error_flag;
endmodule