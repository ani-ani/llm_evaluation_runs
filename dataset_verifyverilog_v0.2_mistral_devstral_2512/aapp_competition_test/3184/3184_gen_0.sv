module camera_coverage (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [7:0] a_i [0:7],
  input [7:0] b_i [0:7],
  output reg [3:0] result,
  output reg done,
  output reg impossible
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PREPROCESS,
    SEARCH,
    DONE
  } state_t;

  state_t state;
  reg [2:0] current_k;
  reg [7:0] current_combination;
  reg [7:0] coverage_mask [0:7];
  reg [7:0] combined_mask;
  reg [2:0] min_cameras;
  reg found;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_k <= 0;
      current_combination <= 0;
      min_cameras <= 0;
      found <= 0;
      result <= 0;
      done <= 0;
      impossible <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREPROCESS;
            current_k <= 1;
            min_cameras <= 8;
            found <= 0;
            done <= 0;
            impossible <= 0;
          end
        end
        PREPROCESS: begin
          // Preprocess all cameras
          for (int i = 0; i < 8; i++) begin
            if (a_i[i] > b_i[i]) begin
              // Wrap-around case: two intervals
              coverage_mask[i] = ((1 << n) - 1) & ~((1 << (b_i[i] - 1)) - 1);
              coverage_mask[i] = coverage_mask[i] | ((1 << (a_i[i] - 1)) - 1);
            end else begin
              // Normal case: single interval
              coverage_mask[i] = ((1 << (b_i[i] - 1)) - 1) ^ ((1 << (a_i[i] - 1)) - 1);
            end
          end
          state <= SEARCH;
        end
        SEARCH: begin
          if (current_k > k) begin
            if (found) begin
              result <= min_cameras;
              state <= DONE;
            end else begin
              impossible <= 1;
              state <= DONE;
            end
          end else begin
            // Check all combinations of current_k cameras
            if (current_combination == (1 << k) - 1) begin
              current_k <= current_k + 1;
              current_combination <= 0;
            end else begin
              // Calculate combined coverage
              combined_mask = 0;
              for (int i = 0; i < 8; i++) begin
                if (current_combination[i]) begin
                  combined_mask = combined_mask | coverage_mask[i];
                end
              end
              
              // Check if all walls covered
              if (combined_mask == (1 << n) - 1) begin
                found <= 1;
                if (current_k < min_cameras) begin
                  min_cameras <= current_k;
                end
              end
              current_combination <= current_combination + 1;
            end
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule