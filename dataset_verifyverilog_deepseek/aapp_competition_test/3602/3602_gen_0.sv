module lamp_illumination_checker(
  input clk,
  input rst_n,
  input start,
  input [2:0] grid_size,
  input [2:0] lamp_reach,
  input [2:0] num_lamps,
  input [2:0] lamp_rows [0:7],
  input [2:0] lamp_cols [0:7],
  output reg result,
  output reg done
);

  localparam MAX_N = 4;
  localparam MAX_LAMPS = 8;
  
  typedef enum {
    IDLE,
    LOAD,
    CHECK_ROW,
    CHECK_COL,
    EVALUATE,
    FINISH
  } state_t;
  
  state_t current_state, next_state;
  reg [2:0] grid_reg;
  reg [2:0] reach_reg;
  reg [2:0] lamps_reg;
  reg [2:0] lamp_row_regs [0:7];
  reg [2:0] lamp_col_regs [0:7];
  reg [2:0] lamp_idx;
  reg [7:0] orientation;
  reg [7:0] temp_orient;
  reg conflict_found;
  reg [2:0] iter;
  reg [3:0] cycles;
  
  reg [7:0] row_illum [0:3];
  reg [7:0] col_illum [0:3];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 1'b0;
      cycles <= 4'b0;
    end else begin
      current_state <= next_state;
      cycles <= (start || current_state != IDLE) ? cycles + 1 : 4'b0;
    end
  end
  
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE:   if (start) next_state = LOAD;
      LOAD:   next_state = CHECK_ROW;
      CHECK_ROW: next_state = CHECK_COL;
      CHECK_COL: begin
        if (lamp_idx == num_lamps-1) next_state = EVALUATE;
        else next_state = CHECK_ROW;
      end
      EVALUATE: begin
        if (iter == 2**num_lamps-1) next_state = FINISH;
        else next_state = LOAD;
      end
      FINISH: next_state = IDLE;
    endcase
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result <= 1'b0;
      conflict_found <= 1'b0;
      grid_reg <= 3'b0;
      reach_reg <= 3'b0;
      lamps_reg <= 3'b0;
      lamp_idx <= 3'b0;
      temp_orient <= 8'b0;
      orientation <= 8'b0;
      iter <= 3'b0;
      foreach (row_illum[i]) row_illum[i] <= 8'b0;
      foreach (col_illum[i]) col_illum[i] <= 8'b0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          result <= 1'b0;
          conflict_found <= 1'b0;
          orientation <= 8'b0;
        end
        LOAD: begin
          grid_reg <= grid_size;
          reach_reg <= lamp_reach;
          lamps_reg <= num_lamps;
          foreach (lamp_row_regs[i]) lamp_row_regs[i] <= lamp_rows[i];
          foreach (lamp_col_regs[i]) lamp_col_regs[i] <= lamp_cols[i];
          foreach (row_illum[i]) row_illum[i] <= 8'b0;
          foreach (col_illum[i]) col_illum[i] <= 8'b0;
          temp_orient <= orientation;
          lamp_idx <= 3'b0;
        end
        CHECK_ROW: begin
          if (!temp_orient[lamp_idx]) begin
            for (int c = 0; c < MAX_N; c++) begin
              if (c >= lamp_col_regs[lamp_idx]-reach_reg && c <= lamp_col_regs[lamp_idx]+reach_reg && c < grid_reg) begin
                if (row_illum[lamp_row_regs[lamp_idx]][c]) conflict_found <= 1'b1;
                row_illum[lamp_row_regs[lamp_idx]][c] <= 1'b1;
              end
            end
          end
        end
        CHECK_COL: begin
          if (temp_orient[lamp_idx]) begin
            for (int r = 0; r < MAX_N; r++) begin
              if (r >= lamp_row_regs[lamp_idx]-reach_reg && r <= lamp_row_regs[lamp_idx]+reach_reg && r < grid_reg) begin
                if (col_illum[lamp_col_regs[lamp_idx]][r]) conflict_found <= 1'b1;
                col_illum[lamp_col_regs[lamp_idx]][r] <= 1'b1;
              end
            end
          end
          lamp_idx <= lamp_idx + 1;
        end
        EVALUATE: begin
          if (!conflict_found) begin
            result <= 1'b1;
            next_state = FINISH;
          end else if (iter == 2**num_lamps-1) begin
            result <= 1'b0;
            done <= 1'b1;
          end
          iter <= iter + 1;
          orientation <= iter + 1;
          conflict_found <= 1'b0;
        end
        FINISH: begin
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule