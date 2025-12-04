module train_sorter (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [4:0] car_numbers [0:15],
  output reg [4:0] min_moves,
  output reg done
);
  
  typedef enum {IDLE, LOAD_POS, SCAN_SEQ, SCAN_INNER, DONE} state_t;
  state_t state;
  
  reg [3:0] index_count;
  reg [4:0] min_car, max_car;
  reg [4:0] i, j;
  reg [4:0] current_length;
  reg [4:0] max_length;
  reg present [0:31];
  reg [3:0] pos [0:31];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_moves <= 0;
      index_count <= 0;
      min_car <= 5'b11111;
      max_car <= 5'b00000;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= LOAD_POS;
            index_count <= 0;
            min_car <= 5'b11111;
            max_car <= 5'b00000;
          end
        end
        
        LOAD_POS: begin
          if (index_count < n) begin
            automatic reg [4:0] current_car = car_numbers[index_count];
            pos[current_car] <= index_count;
            present[current_car] <= 1'b1;
            if (current_car < min_car) min_car <= current_car;
            if (current_car > max_car) max_car <= current_car;
            index_count <= index_count + 1;
          end else begin
            state <= SCAN_SEQ;
            i <= min_car;
            max_length <= 5'b00001;
          end
        end
        
        SCAN_SEQ: begin
          if (i > max_car) begin
            state <= DONE;
          end else if (present[i]) begin
            j <= i;
            current_length <= 5'b00001;
            state <= SCAN_INNER;
          end else begin
            i <= i + 1'b1;
          end
        end
        
        SCAN_INNER: begin
          if ((j < max_car) && present[j+1] && (pos[j+1] > pos[j])) begin
            current_length <= current_length + 1'b1;
            j <= j + 1'b1;
          end else begin
            if (current_length > max_length) max_length <= current_length;
            i <= j + 1'b1;
            state <= SCAN_SEQ;
          end
        end
        
        DONE: begin
          min_moves <= n - max_length;
          done <= 1'b1;
          if (start) begin
            state <= LOAD_POS;
            index_count <= 0;
            min_car <= 5'b11111;
            max_car <= 5'b00000;
          end
        end
      endcase
    end
  end
  
endmodule