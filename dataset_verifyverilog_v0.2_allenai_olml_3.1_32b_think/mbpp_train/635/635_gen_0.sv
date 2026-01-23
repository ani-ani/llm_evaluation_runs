module heap_sort (
input clk,
input rst_n, // active-low reset
input start,
input [4:0] num_elements,
input [15:0] data_in [15:0], // 16 elements of 16 bits
output reg [15:0] data_out [15:0],
output reg done
);

// Internal registers
reg [15:0] data_arr [15:0]; // 16 elements
reg [4:0] current_num_elements;
reg [4:0] heap_size;
reg [2:0] state; // 3 bits
reg [4:0] target_index;
reg [4:0] build_index;
reg [2:0] return_state;
reg heapify_done;
reg [15:0] temp;
reg done_reg;

// State encoding
localparam IDLE = 3'b000;
localparam BUILD_HEAP = 3'b001;
localparam EXTRACT_MAX = 3'b010;
localparam HEAPIFY = 3'b011;
localparam DONE = 3'b100;

// Default assignments on reset
always @(posedge clk) begin
   if (!rst_n) begin
      data_arr <= 16'b0;
current_num_elements <= 5'd0;
heap_size <= 4'd0;
state <= IDLE;
target_index <= 5'd0;
build_index <= 5'd0;
return_state <= 3'b000;
heapify_done <= 1'b0;
temp <= 16'b0;
done_reg <= 1'b0;
data_out <= 16'b0;
   end
end

// State machine logic
always @(posedge clk) begin
   if (!rst_n) begin
      data_arr <= 16'b0;
current_num_elements <= 5'd0;
heap_size <= 4'd0;
state <= IDLE;
target_index <= 5'd0;
build_index <= 5'd0;
return_state <= 3'b000;
heapify_done <= 1'b0;
temp <= 16'b0;
done_reg <= 1'b0;
data_out <= 16'b0;
   end else begin
      data_out <= data_out; // Hold previous value

      if (state == IDLE) begin
         if (start) begin
            current_num_elements <= num_elements;
data_arr <= data_in;
heap_size <= current_num_elements;
build_index <= (current_num_elements == 5'd0) ? 5'd0 : ((current_num_elements - 1) >> 1);
if (current_num_elements == 5'd0) begin
   state <= DONE;
done_reg <= 1'b1;
end else begin
   state <= BUILD_HEAP;
end
         end
      end else if (state == BUILD_HEAP) begin
         if (build_index >= 5'd0) begin
            if (!heapify_done) begin
               target_index <= build_index;
return_state <= BUILD_HEAP;
state <= HEAPIFY;
            end else begin
               build_index <= build_index - 5'd1;
            end
         end else begin
            state <= EXTRACT_MAX;
         end
      end else if (state == EXTRACT_MAX) begin
         if (heap_size > 1) begin
            temp = data_arr[0];
data_arr[0] = data_arr[heap_size - 1];
data_arr[heap_size - 1] = temp;
heap_size <= heap_size - 1;
target_index <= 0;
return_state <= EXTRACT_MAX;
state <= HEAPIFY;
         end else begin
            state <= DONE;
done_reg <= 1'b1;
         end
      end else if (state == HEAPIFY) begin
         int i = target_index;
int left = 2*i + 1;
int right = 2*i + 2;
int largest = i;

         if (left < heap_size && data_arr[left] > data_arr[largest])
             largest = left;
         if (right < heap_size && data_arr[right] > data_arr[largest])
             largest = right;

         if (largest != i) begin
            temp = data_arr[i];
data_arr[i] = data_arr[largest];
data_arr[largest] = temp;
target_index <= largest;
         end else begin
            heapify_done <= 1'b1;
state <= return_state;
         end
      end else if (state == DONE) begin
         data_out <= data_arr;
      end
   end
end

endmodule