module count_unequal_pairs(
  input clk,
  input rst_n,
  input start,
  input [2:0] size,
  input [7:0][7:0] arr,
  output reg [15:0] count,
  output reg done
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam START_PULSE = 2'b01;
  localparam WORKING = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state;
  reg [2:0] i, j;
  reg [15:0] pair_count;
  reg [15:0] total_pairs;
  reg ready_done;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      i <= 0;
      j <= 1;
      pair_count <= 0;
      total_pairs <= 0;
      ready_done <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start)
            state <= START_PULSE;
        end
        
        START_PULSE: begin
          if (size == 0) begin
            state <= DONE;
            done <= 1;
            count <= 0;
          end
          else begin
            state <= WORKING;
            count <= 0;
            total_pairs <= size * (size - 1) / 2;
            pair_count <= 0;
            i <= 0;
            j <= 1;
            done <= 0;
            ready_done <= 0;
          end
        end
        
        WORKING: begin
          if (start) begin
            state <= START_PULSE;
          end
          else if (ready_done) begin
            state <= DONE;
            done <= 1;
            ready_done <= 0;
          end
          else begin
            if (arr[i] != arr[j])
              count <= count + 1;
            
            if (i < size - 1) begin
              if (j < size - 1) begin
                j <= j + 1;
              end
              else begin
                i <= i + 1;
                j <= i + 2;
              end
            end
            
            pair_count <= pair_count + 1;
            
            if (pair_count + 1 == total_pairs)
              ready_done <= 1;
            else
              ready_done <= 0;
          end
        end
        
        DONE: begin
          if (start)
            state <= START_PULSE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule