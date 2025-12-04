module monotonic_subgrid_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] r_in,
  input [1:0] c_in,
  input [15:0][4:0] grid,
  output reg [7:0] count,
  output reg done
);

function automatic logic is_row_monotonic(input [3:0] row_mask, input [3:0] col_mask, input [15:0][4:0] grid, input [1:0] row_idx);
  logic [3:0][4:0] elements;
  int k = 0;
  for (int j=0; j<4; j++) begin
    if (col_mask[j]) begin
      elements[k] = grid[row_idx*4 + j];
      k++;
    end
  end
  if (k <= 1) return 1'b1;
  logic non_decr = 1'b1;
  logic non_incr = 1'b1;
  for (int i=0; i<k-1; i++) begin
    non_decr = non_decr & (elements[i+1] >= elements[i]);
    non_incr = non_incr & (elements[i+1] <= elements[i]);
  end
  return non_decr | non_incr;
endfunction

function automatic logic is_col_monotonic(input [3:0] row_mask, input [3:0] col_mask, input [15:0][4:0] grid, input [1:0] col_idx);
  logic [3:0][4:0] elements;
  int k = 0;
  for (int i=0; i<4; i++) begin
    if (row_mask[i]) begin
      elements[k] = grid[i*4 + col_idx];
      k++;
    end
  end
  if (k <= 1) return 1'b1;
  logic non_decr = 1'b1;
  logic non_incr = 1'b1;
  for (int i=0; i<k-1; i++) begin
    non_decr = non_decr & (elements[i+1] >= elements[i]);
    non_incr = non_incr & (elements[i+1] <= elements[i]);
  end
  return non_decr | non_incr;
endfunction

typedef enum logic [2:0] {
  IDLE,
  INIT,
  PROCESS_SUBSET,
  CHECK_STEP,
  UPDATE_COUNT,
  NEXT_MASK,
  DONE
} state_t;

state_t state_reg, state_next;
reg [3:0] row_mask_reg, row_mask_next;
reg [3:0] col_mask_reg, col_mask_next;
reg [3:0] step_reg, step_next;
reg all_rows_ok_reg, all_rows_ok_next;
reg all_cols_ok_reg, all_cols_ok_next;
reg [7:0] count_reg, count_next;
reg done_reg, done_next;
reg [3:0] row_enable_mask_reg, row_enable_mask_next;
reg [3:0] col_enable_mask_reg, col_enable_mask_next;

always_comb begin
  state_next = state_reg;
  row_mask_next = row_mask_reg;
  col_mask_next = col_mask_reg;
  step_next = step_reg;
  all_rows_ok_next = all_rows_ok_reg;
  all_cols_ok_next = all_cols_ok_reg;
  count_next = count_reg;
  done_next = done_reg;
  row_enable_mask_next = row_enable_mask_reg;
  col_enable_mask_next = col_enable_mask_reg;

  case (state_reg)
    IDLE: begin
      if (start) begin
        state_next = INIT;
      end
    end

    INIT: begin
      count_next = '0;
      done_next = 1'b0;
      row_mask_next = 4'b0001;
      col_mask_next = 4'b0001;
      step_next = '0;
      row_enable_mask_next = (4'b1 << r_in) - 1;
      col_enable_mask_next = (4'b1 << c_in) - 1;
      state_next = PROCESS_SUBSET;
    end

    PROCESS_SUBSET: begin
      if (row_mask_reg == '0 || col_mask_reg == '0 || 
          (row_mask_reg & row_enable_mask_reg) != row_mask_reg || 
          (col_mask_reg & col_enable_mask_reg) != col_mask_reg) begin
        state_next = NEXT_MASK;
      end else begin
        all_rows_ok_next = 1'b1;
        all_cols_ok_next = 1'b1;
        step_next = '0;
        state_next = CHECK_STEP;
      end
    end

    CHECK_STEP: begin
      if (step_reg < 4'd8) begin
        step_next = step_reg + 1;
        if (step_reg < 4) begin
          if (row_mask_reg[step_reg[1:0]]) begin
            if (!is_row_monotonic(row_mask_reg, col_mask_reg, grid, step_reg[1:0])) begin
              all_rows_ok_next = 1'b0;
            end
          end
        end else begin
          if (col_mask_reg[step_reg[1:0]-4]) begin
            if (!is_col_monotonic(row_mask_reg, col_mask_reg, grid, step_reg[1:0]-4)) begin
              all_cols_ok_next = 1'b0;
            end
          end
        end
      end else begin
        state_next = UPDATE_COUNT;
      end
    end

    UPDATE_COUNT: begin
      if (all_rows_ok_reg && all_cols_ok_reg) begin
        count_next = count_reg + 1;
      end
      state_next = NEXT_MASK;
    end

    NEXT_MASK: begin
      col_mask_next = (col_mask_reg + 1) & col_enable_mask_reg;
      if (col_mask_next == '0) begin
        col_mask_next = 4'b0001;
        row_mask_next = (row_mask_reg + 1) & row_enable_mask_reg;
        if (row_mask_next == '0) begin
          state_next = DONE;
        end else begin
          state_next = PROCESS_SUBSET;
        end
      end else begin
        state_next = PROCESS_SUBSET;
      end
    end

    DONE: begin
      done_next = 1'b1;
      if (!start) begin
        state_next = IDLE;
      end
    end

    default: state_next = IDLE;
  endcase
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state_reg <= IDLE;
    count_reg <= '0;
    done_reg <= 1'b0;
    row_mask_reg <= '0;
    col_mask_reg <= '0;
    step_reg <= '0;
    all_rows_ok_reg <= '0;
    all_cols_ok_reg <= '0;
    row_enable_mask_reg <= '0;
    col_enable_mask_reg <= '0;
  end else begin
    state_reg <= state_next;
    row_mask_reg <= row_mask_next;
    col_mask_reg <= col_mask_next;
    step_reg <= step_next;
    all_rows_ok_reg <= all_rows_ok_next;
    all_cols_ok_reg <= all_cols_ok_next;
    count_reg <= count_next;
    done_reg <= done_next;
    row_enable_mask_reg <= row_enable_mask_next;
    col_enable_mask_reg <= col_enable_mask_next;
  end
end
endmodule