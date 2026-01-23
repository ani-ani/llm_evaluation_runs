module costume_solver (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] i,
  input [3:0] l,
  input [3:0] r,
  input x,
  output reg [29:0] result,
  output reg done,
  output reg impossible
);

  // Constants
  localparam MOD = 30'h3B9ACA07;
  localparam MAX_N = 4'd16;

  // State machine
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    SOLVE,
    CALC,
    DONE
  } state_t;
  state_t state, next_state;

  // Matrix storage (16x16 + augmented column)
  reg [16:0] matrix [0:15];
  reg [3:0] row_count;
  reg [3:0] pivot_col;
  reg [3:0] pivot_row;
  reg [3:0] rank;
  reg [3:0] current_row;
  reg [3:0] current_col;
  reg [3:0] exponent;
  reg [29:0] power_result;
  reg [29:0] base;
  reg [29:0] temp;

  // State machine transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      result <= 0;
      row_count <= 0;
      pivot_col <= 0;
      pivot_row <= 0;
      rank <= 0;
      current_row <= 0;
      current_col <= 0;
      exponent <= 0;
      power_result <= 0;
      base <= 0;
      temp <= 0;
      for (int j = 0; j < 16; j++) begin
        matrix[j] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (row_count == n - 1) next_state = SOLVE;
      end
      SOLVE: begin
        if (current_col == n) begin
          if (rank == n) next_state = CALC;
          else next_state = CALC;
        end
      end
      CALC: begin
        if (exponent == 0) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = LOAD;
      end
      default: next_state = IDLE;
    endcase
  end

  // LOAD state: Build matrix
  always @(posedge clk) begin
    if (state == LOAD && row_count < n) begin
      matrix[row_count] <= 0;
      // Set augmented bit
      matrix[row_count][16] <= x;
      // Set constraint bits
      for (int j = 0; j < n; j++) begin
        if ((j >= (i - l)) && (j <= (i + r))) begin
          matrix[row_count][j] <= 1;
        end else if ((i - l) < 0 && (j + 16 >= (i - l + 16))) begin
          matrix[row_count][j] <= 1;
        end else if ((i + r) >= n && (j <= (i + r - n))) begin
          matrix[row_count][j] <= 1;
        end
      end
      row_count <= row_count + 1;
    end
  end

  // SOLVE state: Gaussian elimination
  always @(posedge clk) begin
    if (state == SOLVE) begin
      if (current_col < n) begin
        // Find pivot row
        pivot_row <= 0;
        for (int j = current_row; j < n; j++) begin
          if (matrix[j][current_col]) begin
            pivot_row <= j;
            break;
          end
        end
        
        if (pivot_row != 0) begin
          // Swap rows if needed
          if (pivot_row != current_row) begin
            temp <= matrix[current_row];
            matrix[current_row] <= matrix[pivot_row];
            matrix[pivot_row] <= temp;
          end
          
          // Eliminate column
          for (int j = 0; j < n; j++) begin
            if (j != current_row && matrix[j][current_col]) begin
              matrix[j] <= matrix[j] ^ matrix[current_row];
            end
          end
          rank <= rank + 1;
        end
        current_col <= current_col + 1;
        current_row <= current_row + 1;
      end
    end
  end

  // CALC state: Compute 2^(n-rank) mod MOD
  always @(posedge clk) begin
    if (state == CALC) begin
      if (exponent == 0) begin
        exponent <= n - rank;
        power_result <= 1;
        base <= 2;
      end else begin
        if (exponent[0]) begin
          power_result <= (power_result * base) % MOD;
        end
        base <= (base * base) % MOD;
        exponent <= exponent >> 1;
      end
    end
  end

  // Check consistency and set outputs
  always @(posedge clk) begin
    if (state == DONE) begin
      impossible <= 0;
      for (int j = rank; j < n; j++) begin
        if (matrix[j][16]) begin
          impossible <= 1;
          result <= 0;
          break;
        end
      end
      if (!impossible) begin
        result <= power_result;
      end
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule