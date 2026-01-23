module max_independent_set ( input clk, input rst_n, input start, input [2:0] num_nodes, input [7:0] num_edges, input [2:0] edge_a [0:7], input [2:0] edge_b [0:7], output reg [3:0] result, output reg done );
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;
reg [1:0] state;
reg [7:0] mask_counter;
reg [3:0] max_size;
function automatic bit is_bit_set;
   int v, reg [7:0] m;
   begin
      case ({v})
         0: is_bit_set = m[0];
         1: is_bit_set = m[1];
         2: is_bit_set = m[2];
         3: is_bit_set = m[3];
         4: is_bit_set = m[4];
         5: is_bit_set = m[5];
         6: is_bit_set = m[6];
         7: is_bit_set = m[7];
         default: is_bit_set = 0;
      endcase
   end
endfunction
function automatic int popcount;
   reg [7:0] m;
   begin
      popcount = m[0] + m[1] + m[2] + m[3] + m[4] + m[5] + m[6] + m[7];
   end
endfunction
always @(*) begin
   reg [7:0] valid_mask;
   case ({num_nodes})
      1: valid_mask = 1;
      2: valid_mask = 3;
      3: valid_mask = 7;
      4: valid_mask = 15;
      5: valid_mask = 31;
      6: valid_mask = 63;
      7: valid_mask = 127;
      8: valid_mask = 255;
      default: valid_mask = 0;
   endcase
   wire is_valid = ( (mask_counter & ~valid_mask) == 0 );
   wire conflict_i0 = (num_edges > 0) ? (is_bit_set(edge_a[0], mask_counter) && is_bit_set(edge_b[0], mask_counter)) : 1'b0;
   wire conflict_i1 = (num_edges > 1) ? (is_bit_set(edge_a[1], mask_counter) && is_bit_set(edge_b[1], mask_counter)) : 1'b0;
   wire conflict_i2 = (num_edges > 2) ? (is_bit_set(edge_a[2], mask_counter) && is_bit_set(edge_b[2], mask_counter)) : 1'b0;
   wire conflict_i3 = (num_edges > 3) ? (is_bit_set(edge_a[3], mask_counter) && is_bit_set(edge_b[3], mask_counter)) : 1'b0;
   wire conflict_i4 = (num_edges > 4) ? (is_bit_set(edge_a[4], mask_counter) && is_bit_set(edge_b[4], mask_counter)) : 1'b0;
   wire conflict_i5 = (num_edges > 5) ? (is_bit_set(edge_a[5], mask_counter) && is_bit_set(edge_b[5], mask_counter)) : 1'b0;
   wire conflict_i6 = (num_edges > 6) ? (is_bit_set(edge_a[6], mask_counter) && is_bit_set(edge_b[6], mask_counter)) : 1'b0;
   wire conflict_i7 = (num_edges > 7) ? (is_bit_set(edge_a[7], mask_counter) && is_bit_set(edge_b[7], mask_counter)) : 1'b0;
   wire is_independent = ~ (conflict_i0 | conflict_i1 | conflict_i2 | conflict_i3 | conflict_i4 | conflict_i5 | conflict_i6 | conflict_i7);
   reg [3:0] current_size;
   if (is_valid && is_independent) begin
      current_size = popcount(mask_counter);
   end else begin
      current_size = 0;
   end
end
always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      mask_counter <= 0;
      max_size <= 0;
   end else begin
      case (state)
         IDLE: begin
            if (start)
               state <= PROCESSING;
               mask_counter <= 0;
               max_size <= 0;
            end
         end
         PROCESSING: begin
            if (mask_counter == 255) begin
               state <= DONE;
            end else begin
               mask_counter <= mask_counter + 1;
               if (is_valid && is_independent && (current_size > max_size)) begin
                  max_size <= current_size;
               end
            end
         end
         DONE: state <= DONE;
      endcase
   end
end
assign result = max_size;
assign done = (state == DONE);
endmodule