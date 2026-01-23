module replant_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [4:0] M,
  input [3:0] species_in,
  input load_species,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    COMPUTE_DP,
    FIND_MAX,
    CALCULATE_RESULT,
    DONE
  } state_t;

  state_t state;
  reg [3:0] species [0:7]; // Buffer for species (max 8 plants)
  reg [3:0] dp [0:7]; // DP array
  reg [3:0] max_len;
  reg [3:0] i, j;
  reg [3:0] current_max;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      i <= 0;
      j <= 0;
      current_max <= 0;
      max_len <= 0;
      for (int k = 0; k < 8; k++) begin
        species[k] <= 0;
        dp[k] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (load_species) begin
            species[i] <= species_in;
            i <= i + 1;
            if (i == N) begin
              i <= 0;
              state <= COMPUTE_DP;
            end
          end else if (start) begin
            state <= COMPUTE_DP;
          end
        end

        COMPUTE_DP: begin
          dp[i] <= 1;
          current_max <= 0;
          for (j = 0; j < i; j = j + 1) begin
            if (species[j] <= species[i]) begin
              if (dp[j] > current_max) begin
                current_max <= dp[j];
              end
            end
          end
          dp[i] <= current_max + 1;
          i <= i + 1;
          if (i == N) begin
            i <= 0;
            state <= FIND_MAX;
          end
        end

        FIND_MAX: begin
          if (dp[i] > max_len) begin
            max_len <= dp[i];
          end
          i <= i + 1;
          if (i == N) begin
            i <= 0;
            state <= CALCULATE_RESULT;
          end
        end

        CALCULATE_RESULT: begin
          result <= N - max_len;
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            done <= 0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule