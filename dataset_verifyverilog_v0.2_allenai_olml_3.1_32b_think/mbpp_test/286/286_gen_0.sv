module max_subarray_repeated (
   input clk,
   input rst_n, 
   input start,
   input [1:0] n,
   input [31:0] a [0:3],
   output reg [31:0] result,
   output reg done
);

reg [31:0] current_max, max_so_far;
reg [3:0] i;
reg [1:0] state;

localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam CHECK_DONE = 2'b10;
localparam DONE = 2'b11;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      i <=0;
      current_max <=0;
      max_so_far <=0;
      result <=0;
      done <=0;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               state <= PROCESSING;
               i <=0;
            end
         end
         PROCESSING: begin
            integer n_int = n;
            integer k_int = k;
            integer total_elements = n_int * k_int;
            integer next_i = i +1;
            integer mod = i % n_int;
            reg [31:0] x = a[mod];
            if (i ==0) begin
               current_max <= x;
               max_so_far <=x;
               i <= next_i;
               if (next_i >= total_elements) begin
                  state <= CHECK_DONE;
               end
            end else begin
               int temp = current_max + x;
               reg [31:0] current_max_next;
               if (x > temp) begin
                  current_max_next = x;
               end else begin
                  current_max_next = temp;
               end
               reg [31:0] max_so_far_next;
               if (current_max_next > max_so_far) begin
                  max_so_far_next = current_max_next;
               end else begin
                  max_so_far_next = max_so_far;
               end
               current_max <= current_max_next;
               max_so_far <= max_so_far_next;
               i <= next_i;
               if (next_i >= total_elements) begin
                  state <= CHECK_DONE;
               end
            end
         end
         CHECK_DONE: begin
            state <= DONE;
            result <= max_so_far;
            done <=1;
         end
         DONE: begin
            done <=1;
         end
      endcase
   end
endmodule