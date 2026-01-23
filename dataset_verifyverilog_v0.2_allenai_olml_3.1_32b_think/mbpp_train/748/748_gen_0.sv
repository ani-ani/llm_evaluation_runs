module capital_words_spaces (
   input clk,
   input rst_n, // active low
   input start,
   input [7:0] char_in,
   input [3:0] char_index,
   input input_valid,
   output reg [7:0] char_out,
   output reg [3:0] out_index,
   output reg output_valid,
   output reg done
);

localparam MAX_LEN = 16;
localparam SPACE = 32;

reg [7:0] buf [MAX_LEN-1:0];
reg [2:0] state;
reg [3:0] last_index;
reg [3:0] process_idx;
reg [1:0] emit_state;
reg is_upper_prev;
reg [4:0] output_count;
reg [7:0] output_char_reg;
reg output_valid_reg;
reg [3:0] out_index_reg;
reg done_reg;
reg data_received;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= 3'b000; // IDLE
      last_index <= 4'd0;
      process_idx <=4'd0;
      emit_state <=2'd0;
      is_upper_prev <=0;
      output_count <=5'd0;
      done_reg <=0;
      output_char_reg <=8'd0;
      output_valid_reg <=0;
      out_index_reg <=4'd0;
      data_received <=0;
      // Reset buffer
      buf[0] <=8'd0;
      buf[1] <=8'd0;
      buf[2] <=8'd0;
      buf[3] <=8'd0;
      buf[4] <=8'd0;
      buf[5] <=8'd0;
      buf[6] <=8'd0;
      buf[7] <=8'd0;
      buf[8] <=8'd0;
      buf[9] <=8'd0;
      buf[10] <=8'd0;
      buf[11] <=8'd0;
      buf[12] <=8'd0;
      buf[13] <=8'd0;
      buf[14] <=8'd0;
      buf[15] <=8'd0;
   end else begin
      case (state)
         3'b000: // IDLE
            output_valid_reg <=0;
            output_char_reg <=8'd0;
            out_index_reg <=4'd0;
            if (start ==1) begin
               state <= 3'b001; // LOAD
            end
         3'b001: // LOAD
            output_valid_reg <=0;
            output_char_reg <=8'd0;
            out_index_reg <=4'd0;
            if (input_valid) begin
               if (char_index < MAX_LEN) begin
                  buf[char_index] <= char_in;
                  if (char_index > last_index) begin
                     last_index <= char_index;
                  end
                  data_received <=1;
               end
            end
            if (!start && data_received) begin
               state <= 3'b010; // PROCESS
               process_idx <=4'd0;
               emit_state <=2'd0;
               is_upper_prev <=0;
               output_count <=5'd0;
            end
         3'b010: // PROCESS
            output_valid_reg <=0;
            output_char_reg <=8'd0;
            out_index_reg <=4'd0;
            done_reg <=0;
            if (process_idx > last_index) begin
               state <= 3'b011; // DONE
               done_reg <=1;
            end else begin
               if (emit_state ==2'd0) begin
                  if (process_idx ==4'd0) begin
                     output_char_reg <= buf[process_idx];
                     output_valid_reg <=1;
                     out_index_reg <= output_count;
                     output_count <= output_count +1;
                     is_upper_prev <= (buf[process_idx] >= 'A' && buf[process_idx] <= 'Z');
                     process_idx <= process_idx +1;
                  end else begin
                     if ((buf[process_idx] >= 'A' && buf[process_idx] <= 'Z') && !is_upper_prev) begin
                        output_char_reg <= SPACE;
                        output_valid_reg <=1;
                        out_index_reg <= output_count;
                        output_count <= output_count +1;
                        emit_state <=2'd1;
                     end else begin
                        output_char_reg <= buf[process_idx];
                        output_valid_reg <=1;
                        out_index_reg <= output_count;
                        output_count <= output_count +1;
                        is_upper_prev <= (buf[process_idx] >= 'A' && buf[process_idx] <= 'Z');
                        process_idx <= process_idx +1;
                     end
                  end
               end else if (emit_state ==2'd1) begin
                  output_char_reg <= buf[process_idx];
                  output_valid_reg <=1;
                  out_index_reg <= output_count;
                  output_count <= output_count +1;
                  is_upper_prev <= (buf[process_idx] >= 'A' && buf[process_idx] <= 'Z');
                  process_idx <= process_idx +1;
                  emit_state <=2'd0;
               end
            end
         3'b011: // DONE
            output_valid_reg <=0;
            output_char_reg <=8'd0;
            out_index_reg <=4'd0;
            done_reg <=1;
      endcase
      // Assign outputs
      char_out <= output_char_reg;
      out_index <= out_index_reg;
      output_valid <= output_valid_reg;
      done <= done_reg;
   end
endmodule