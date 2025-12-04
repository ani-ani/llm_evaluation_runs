module min_diff_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0] element_count,
  input [7:0][7:0] array_in,
  output reg [7:0] min_diff,
  output reg done
);

typedef enum {
  IDLE,
  INIT,
  SORT_START,
  SORT_COMPARE,
  SORT_NEXT_PASS,
  COMPUTE_DIFF_START,
  COMP_LOOP,
  DONE
} state_t;

reg [7:0][7:0] array_reg;
reg [7:0] element_count_reg;
reg [7:0] pass;
reg [7:0] comp_counter;
reg swap_flag;
reg [7:0] i;
reg [7:0] min_diff_temp;
state_t state;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    min_diff <= 8'd0;
    array_reg <= '0;
    element_count_reg <= '0;
    pass <= '0;
    comp_counter <= '0;
    swap_flag <= '0;
    i <= '0;
    min_diff_temp <= '0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) state <= INIT;
      end

      INIT: begin
        array_reg <= array_in;
        element_count_reg <= element_count;
        if (element_count < 8'd2) begin
          min_diff <= 8'd0;
          done <= 1'b1;
          state <= DONE;
        end else begin
          pass <= 8'd0;
          state <= SORT_START;
        end
      end

      SORT_START: begin
        swap_flag <= 1'b0;
        comp_counter <= 8'd0;
        state <= SORT_COMPARE;
      end

      SORT_COMPARE: begin
        if (array_reg[comp_counter] > array_reg[comp_counter + 1]) begin
          array_reg[comp_counter] <= array_reg[comp_counter + 1];
          array_reg[comp_counter + 1] <= array_reg[comp_counter];
          swap_flag <= 1'b1;
        end
        comp_counter <= comp_counter + 8'd1;
        if (comp_counter < (element_count_reg - pass - 8'd2))
          state <= SORT_COMPARE;
        else
          state <= SORT_NEXT_PASS;
      end

      SORT_NEXT_PASS: begin
        pass <= pass + 8'd1;
        if (pass < (element_count_reg - 8'd2) && swap_flag)
          state <= SORT_START;
        else
          state <= COMPUTE_DIFF_START;
      end

      COMPUTE_DIFF_START: begin
        min_diff_temp <= 8'hFF;
        i <= 8'd0;
        state <= COMP_LOOP;
      end

      COMP_LOOP: begin
        if (array_reg[i+1] - array_reg[i] < min_diff_temp)
          min_diff_temp <= array_reg[i+1] - array_reg[i];
        i <= i + 8'd1;
        if (i < (element_count_reg - 8'd2))
          state <= COMP_LOOP;
        else
          state <= DONE;
      end

      DONE: begin
        min_diff <= min_diff_temp;
        done <= 1'b1;
        state <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule