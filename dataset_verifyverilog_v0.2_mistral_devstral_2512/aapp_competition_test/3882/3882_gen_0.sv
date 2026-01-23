module sym_trans_count (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [29:0] result,
  output reg done
);

  // Constants
  localparam P = 30'h3B9ACA01; // 10^9+7
  localparam MAX_N = 8;

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    ROW_LOOP,
    COL_LOOP,
    CALC,
    DONE
  } state_t;

  // State registers
  state_t state, next_state;
  logic [2:0] i, j; // Loop counters
  logic [29:0] A [0:MAX_N][0:MAX_N]; // Table storage
  logic [29:0] temp;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      done <= 0;
      result <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          if (start) begin
            i <= 0;
            j <= 0;
          end
        end
        
        INIT: begin
          if (i == MAX_N) begin
            i <= 0;
            j <= 0;
          end else if (j == MAX_N) begin
            i <= i + 1;
            j <= 0;
          end else begin
            j <= j + 1;
          end
        end
        
        ROW_LOOP: begin
          if (i == n) begin
            i <= 0;
            j <= 0;
          end else if (j == n) begin
            i <= i + 1;
            j <= 0;
          end else begin
            j <= j + 1;
          end
        end
        
        COL_LOOP: begin
          if (j == n) begin
            i <= i + 1;
            j <= 0;
          end else begin
            j <= j + 1;
          end
        end
        
        CALC: begin
          i <= i + 1;
          j <= 0;
        end
        
        DONE: begin
          if (start) begin
            i <= 0;
            j <= 0;
          end
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      
      INIT: begin
        if (i == MAX_N && j == MAX_N) next_state = ROW_LOOP;
      end
      
      ROW_LOOP: begin
        if (i == n && j == n) next_state = CALC;
      end
      
      COL_LOOP: begin
        if (j == n) next_state = ROW_LOOP;
      end
      
      CALC: begin
        if (i == n) next_state = DONE;
      end
      
      DONE: begin
        if (start) next_state = INIT;
      end
    endcase
  end

  // Table initialization
  always @(posedge clk) begin
    if (!rst_n) begin
      for (int k = 0; k <= MAX_N; k++) begin
        for (int l = 0; l <= MAX_N; l++) begin
          A[k][l] <= 0;
        end
      end
    end else if (state == INIT) begin
      if (i == 0 && j == 0) begin
        A[0][0] <= 1;
      end else if (i > 0 && j == 0) begin
        A[i][0] <= A[i-1][i-1];
      end
    end
  end

  // Table computation
  always @(posedge clk) begin
    if (state == ROW_LOOP && i < n && j < n) begin
      if (j == 0) begin
        A[i][j] <= A[i-1][i-1];
      end else begin
        temp = (A[i][j-1] + A[i-1][j-1]) % P;
        A[i][j] <= temp;
      end
    end
  end

  // Result computation
  always @(posedge clk) begin
    if (state == DONE) begin
      result <= A[n][n-1];
      done <= 1;
    end else if (start && state == IDLE) begin
      done <= 0;
    end
  end

endmodule