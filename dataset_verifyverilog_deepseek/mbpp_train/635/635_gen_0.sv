module heap_sort(
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [0:7],
  output reg [7:0] data_out [0:7],
  output reg done
);
  
  typedef enum logic [2:0] {
    IDLE,
    BUILD_HEAP,
    BUILD_HEAP_DECR,
    SORT,
    SORT_SWAP,
    HEAPIFY_DOWN,
    DONE
  } state_t;

  state_t state, next_state;
  state_t return_state;
  
  reg [7:0] data_reg [0:7];
  reg [7:0] temp;
  reg [3:0] heap_size;
  reg [2:0] build_index;
  reg [2:0] curr_idx;
  reg [2:0] left, right;
  reg [2:0] largest;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      data_out <= '{8{8'hFF}};
      data_reg <= '{8{8'h00}};
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            data_reg <= data_in;
            heap_size <= 8;
            build_index <= 3;
            done <= 1'b0;
          end
        end
        
        BUILD_HEAP: begin
          if (build_index >= 0) begin
            curr_idx <= build_index;
            return_state <= BUILD_HEAP_DECR;
          end
        end
        
        BUILD_HEAP_DECR: begin
          build_index <= build_index - 1;
        end
        
        SORT: begin
          // No actions - handled in FSM
        end
        
        SORT_SWAP: begin
          temp <= data_reg[0];
          data_reg[0] <= data_reg[heap_size-1];
          data_reg[heap_size-1] <= temp;
          heap_size <= heap_size - 1;
          curr_idx <= 0;
          return_state <= SORT;
        end
        
        HEAPIFY_DOWN: begin
          left <= 2 * curr_idx + 1;
          right <= 2 * curr_idx + 2;
          largest <= curr_idx;
          
          if ((left < heap_size) && (data_reg[left] > data_reg[largest])) largest <= left;
          if ((right < heap_size) && (data_reg[right] > data_reg[largest])) largest <= right;
          
          if (largest != curr_idx) begin
            temp <= data_reg[curr_idx];
            data_reg[curr_idx] <= data_reg[largest];
            data_reg[largest] <= temp;
            curr_idx <= largest;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          data_out <= data_reg;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = BUILD_HEAP;
      
      BUILD_HEAP: begin
        if (build_index >= 0) next_state = HEAPIFY_DOWN;
        else next_state = SORT;
      end
      
      BUILD_HEAP_DECR: next_state = BUILD_HEAP;
      
      SORT: begin
        if (heap_size > 1) next_state = SORT_SWAP;
        else next_state = DONE;
      end
      
      SORT_SWAP: next_state = HEAPIFY_DOWN;
      
      HEAPIFY_DOWN: begin
        if (largest == curr_idx) next_state = return_state;
        else next_state = HEAPIFY_DOWN;
      end
      
      DONE: next_state = DONE;
      
      default: next_state = IDLE;
    endcase
  end
endmodule