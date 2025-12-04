module check_right_shift_sort (
  input clk,
  input rst_n,
  input start,
  input [7:0] arr_size,
  input [15:0] arr [7:0],
  output reg result,
  output reg done
);

typedef enum logic [1:0] {IDLE, CHECK_SHIFT, COMPLETE} state_t;
state_t state, next_state;

reg [7:0] arr_size_reg;
reg [15:0] arr_reg [7:0];
reg [2:0] shift_cnt;
reg sorted_found;
reg done_reg, result_reg;

// Main state machine
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    result_reg <= 0;
    done_reg <= 0;
  end
  else begin
    case (state)
      IDLE: begin
        done_reg <= 0;
        result_reg <= 0;
        if (start) begin
          arr_size_reg <= arr_size;
          arr_reg <= arr;
          if (arr_size == 0) begin
            result_reg <= 1;
            done_reg <= 1;
            state <= COMPLETE;
          end
          else begin
            shift_cnt <= 0;
            sorted_found <= 0;
            state <= CHECK_SHIFT;
          end
        end
      end

      CHECK_SHIFT: begin
        // Generate rotated array and check
        automatic logic sorted_flag = 1'b1;
        for (int i=0; i < arr_size_reg-1; i++) begin
          automatic logic [15:0] curr = arr_reg[(i + arr_size_reg - shift_cnt) % arr_size_reg];
          automatic logic [15:0] next = arr_reg[(i+1 + arr_size_reg - shift_cnt) % arr_size_reg];
          if (curr > next) sorted_flag = 1'b0;
        end

        if (sorted_flag) sorted_found <= 1'b1;

        if (shift_cnt == arr_size_reg - 1) begin
          state <= COMPLETE;
          result_reg <= sorted_found;
          done_reg <= 1'b1;
        end
        else begin
          shift_cnt <= shift_cnt + 1;
        end
      end

      COMPLETE: begin
        if (!start) state <= IDLE;
      end
    endcase
  end
end

assign done = done_reg;
assign result = result_reg;

endmodule