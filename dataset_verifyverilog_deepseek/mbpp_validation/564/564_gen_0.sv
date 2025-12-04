module count_unequal_pairs(input clk, input rst_n, input start, input [2:0] size, input [7:0][7:0] arr, output reg [15:0] count, output reg done);
  typedef enum {IDLE, COMPUTE, DONE} state_t;
  reg [2:0] i, j;
  reg [2:0] size_reg;
  reg [7:0][7:0] arr_reg;
  state_t state;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      i <= 0;
      j <= 1;
      size_reg <= 0;
      arr_reg <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            size_reg <= size;
            arr_reg <= arr;
            count <= 0;
            if (size < 3'd2) begin
              state <= DONE;
            end else begin
              i <= 3'd0;
              j <= 3'd1;
              state <= COMPUTE;
            end
          end
        end
        COMPUTE: begin
          if (arr_reg[i] != arr_reg[j]) count <= count + 1;
          if (j < (size_reg - 1)) begin
            j <= j + 1;
          end else begin
            if (i < (size_reg - 2)) begin
              i <= i + 1;
              j <= i + 2;
            end else begin
              state <= DONE;
            end
          end
        end
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule