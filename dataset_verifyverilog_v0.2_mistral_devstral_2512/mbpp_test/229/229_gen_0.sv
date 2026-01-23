module array_partition (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input signed [7:0] arr [0:7],
  output reg signed [7:0] result [0:7],
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // Internal registers
  state_t state, next_state;
  signed [7:0] internal_arr [0:7];
  reg [2:0] i_reg, j_reg;
  reg [2:0] n_reg;
  reg start_reg;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i_reg <= 0;
      j_reg <= 0;
      n_reg <= 0;
      start_reg <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      if (state == IDLE && start) begin
        start_reg <= 1;
        n_reg <= n;
        for (int k = 0; k < 8; k++) begin
          internal_arr[k] <= arr[k];
        end
      end else if (state == PROCESSING) begin
        if (j_reg == n_reg - 1) begin
          if (i_reg == n_reg - 2) begin
            next_state <= DONE;
          end else begin
            i_reg <= i_reg + 1;
            j_reg <= i_reg + 1;
          end
        end else begin
          j_reg <= j_reg + 1;
        end
      end else if (state == DONE) begin
        start_reg <= 0;
        done <= 1;
        next_state <= IDLE;
      end else begin
        done <= 0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (i_reg == n_reg - 2 && j_reg == n_reg - 1) begin
          next_state = DONE;
        end
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < 8; k++) begin
        result[k] <= 0;
      end
    end else if (state == PROCESSING && start_reg) begin
      if (internal_arr[i_reg] >= 0 && internal_arr[j_reg] < 0) begin
        // Swap elements
        signed [7:0] temp = internal_arr[i_reg];
        internal_arr[i_reg] <= internal_arr[j_reg];
        internal_arr[j_reg] <= temp;
      end
    end else if (state == DONE) begin
      for (int k = 0; k < 8; k++) begin
        result[k] <= internal_arr[k];
      end
    end
  end

endmodule