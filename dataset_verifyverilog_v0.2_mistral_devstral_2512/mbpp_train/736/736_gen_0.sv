module left_insertion (
  input clk,
  input rst_n,
  input start,
  input [7:0] value,
  input [2:0] array_size,
  input [7:0] array_data [0:7],
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCH,
    UPDATE,
    DONE
  } state_t;

  state_t state;
  reg [3:0] low;
  reg [3:0] high;
  reg [3:0] mid;

  // Reset state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      low <= 0;
      high <= 0;
      mid <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SEARCH;
            low <= 0;
            high <= array_size;
          end
        end
        SEARCH: begin
          state <= UPDATE;
          mid <= (low + high) >> 1;
        end
        UPDATE: begin
          if (value > array_data[mid]) begin
            low <= mid + 1;
          end else begin
            high <= mid;
          end
          if (low >= high) begin
            state <= DONE;
          end else begin
            state <= SEARCH;
          end
        end
        DONE: begin
          result <= low;
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule