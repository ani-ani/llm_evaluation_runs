module smart_sort (
  input clk,
  input rst_n,
  input start,
  input [7:0] array_in [0:7],
  input [2:0] num_elements,
  output reg [7:0] sorted_array [0:7],
  output reg done
);

typedef enum logic [1:0] {
  IDLE,
  INIT,
  COMPARE,
  DONE
} state_t;

state_t state;
reg [7:0] current_array [0:7];
reg [2:0] num_elements_stored;
reg sort_order;
reg [2:0] i, j;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    foreach (sorted_array[idx]) sorted_array[idx] <= 8'b0;
    foreach (current_array[idx]) current_array[idx] <= 8'b0;
    num_elements_stored <= 3'b0;
    sort_order <= 1'b0;
    i <= 3'b0;
    j <= 3'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        if (start) state <= INIT;
        else state <= IDLE;
      end
      
      INIT: begin
        for (int idx = 0; idx < 8; idx++) current_array[idx] <= array_in[idx];
        num_elements_stored <= num_elements;
        begin
          logic [7:0] first = array_in[0];
          logic [7:0] last = array_in[num_elements - 1];
          sort_order <= (first + last)[0];
        end
        i <= 0;
        j <= 0;
        state <= COMPARE;
      end
      
      COMPARE: begin
        if (j < (num_elements_stored - i - 1)) begin
          logic swap_en = sort_order ? (current_array[j] > current_array[j+1]) 
                                     : (current_array[j] < current_array[j+1]);
          if (swap_en) begin
            current_array[j]   <= current_array[j+1];
            current_array[j+1] <= current_array[j];
          end
          
          logic [2:0] next_j = j + 1;
          if (next_j >= num_elements_stored - i - 1) begin
            i <= i + 1;
            j <= 0;
            state <= (i + 1 >= num_elements_stored - 1) ? DONE : COMPARE;
          end else begin
            j <= next_j;
            state <= COMPARE;
          end
        end else begin
          i <= i + 1;
          j <= 0;
          state <= (i + 1 >= num_elements_stored - 1) ? DONE : COMPARE;
        end
      end
      
      DONE: begin
        for (int idx = 0; idx < 8; idx++) begin
          sorted_array[idx] <= (idx < num_elements_stored) ? current_array[idx] : 8'b0;
        end
        done <= 1'b1;
        state <= start ? INIT : DONE;
      end
    endcase;
  end
end
endmodule