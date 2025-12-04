module missing_number_finder (
  input clk,
  input rst_n,
  input start,
  input [3:0] array [0:7],
  output reg [3:0] missing,
  output reg done
);

  // State machine states
  typedef enum bit [2:0] {
    IDLE  = 3'b000,
    ITER1 = 3'b001,
    ITER2 = 3'b010
  } state_t;

  state_t state;
  reg [3:0] current_start, current_end, mid;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      missing <= 4'b0;
      current_start <= 4'b0;
      current_end <= 4'b0;
      mid <= 4'b0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize and perform first iteration
            current_start <= 4'd0;
            current_end <= 4'd7;
            mid <= (current_start + current_end) >> 1; // mid = 3
            
            if (array[mid] == mid) begin
              current_start <= mid + 1; // 4
              current_end <= current_end; // 7
            end
            else begin
              current_start <= current_start; // 0
              current_end <= mid; // 3
            end
            
            state <= ITER1;
          end
          else begin
            state <= IDLE;
          end
          done <= 1'b0;
        end

        ITER1: begin
          // Second iteration
          mid <= (current_start + current_end) >> 1;
          
          if (array[mid] == mid) begin
            current_start <= mid + 1;
            current_end <= current_end;
          end
          else begin
            current_start <= current_start;
            current_end <= mid;
          end
          
          state <= ITER2;
        end

        ITER2: begin
          // Third iteration and result computation
          mid <= (current_start + current_end) >> 1;
          
          if (array[mid] == mid) begin
            current_start <= mid + 1;
            current_end <= current_end;
          end
          else begin
            current_start <= current_start;
            current_end <= mid;
          end
          
          // Set result and signal completion
          missing <= current_start;
          done <= 1'b1;
          
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule