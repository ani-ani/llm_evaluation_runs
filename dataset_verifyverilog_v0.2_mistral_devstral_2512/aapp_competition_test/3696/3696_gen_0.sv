module euclid_poly_builder (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] deg_a,
  output reg [7:0] deg_b,
  output reg signed [2:0] a_coeffs [0:120],
  output reg signed [2:0] b_coeffs [0:120],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    ITERATE,
    FINAL,
    DONE
  } state_t;

  state_t state;
  reg [7:0] k; // Iteration counter
  reg signed [2:0] f_prev_prev [0:120]; // F_{k-2}
  reg signed [2:0] f_prev [0:120]; // F_{k-1}
  reg signed [2:0] f_curr [0:120]; // F_k
  reg [7:0] max_deg_prev_prev; // Max degree of F_{k-2}
  reg [7:0] max_deg_prev; // Max degree of F_{k-1}
  reg [7:0] max_deg_curr; // Max degree of F_k
  reg signed [2:0] s_k; // Sign for current iteration
  reg [7:0] i; // Coefficient index
  reg [7:0] temp_deg; // Temporary degree storage
  reg max_coeff_exceeds; // Flag for max coefficient check

  // Initialize all outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      deg_a <= 0;
      deg_b <= 0;
      done <= 0;
      for (i = 0; i < 121; i = i + 1) begin
        a_coeffs[i] <= 0;
        b_coeffs[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          // Initialize F_0 and F_1
          for (i = 0; i < 121; i = i + 1) begin
            f_prev_prev[i] <= 0;
            f_prev[i] <= 0;
          end
          f_prev_prev[0] <= 1; // F_0 = 1
          f_prev[1] <= 1; // F_1 = x
          max_deg_prev_prev <= 0;
          max_deg_prev <= 1;
          k <= 2;
          state <= ITERATE;
        end
        ITERATE: begin
          if (k <= n) begin
            // Compute F_k = x * F_{k-1} + s_k * F_{k-2}
            // First, compute x * F_{k-1} (shift left by 1)
            for (i = 0; i < 121; i = i + 1) begin
              if (i < 120) begin
                f_curr[i+1] <= f_prev[i];
              end else begin
                f_curr[i] <= 0;
              end
            end
            f_curr[0] <= 0;
            max_deg_curr <= max_deg_prev + 1;

            // Check max coefficient of x*F_{k-1}
            max_coeff_exceeds <= 0;
            for (i = 0; i <= max_deg_curr; i = i + 1) begin
              if (f_curr[i] > 1 || f_curr[i] < -1) begin
                max_coeff_exceeds <= 1;
              end
            end

            // Determine s_k
            s_k <= max_coeff_exceeds ? -1 : 1;

            // Add s_k * F_{k-2}
            for (i = 0; i <= max_deg_prev_prev; i = i + 1) begin
              f_curr[i] <= f_curr[i] + s_k * f_prev_prev[i];
            end

            // Update max degree if needed
            if (max_deg_prev_prev > max_deg_curr) begin
              max_deg_curr <= max_deg_prev_prev;
            end

            // Shift registers for next iteration
            for (i = 0; i < 121; i = i + 1) begin
              f_prev_prev[i] <= f_prev[i];
              f_prev[i] <= f_curr[i];
            end
            max_deg_prev_prev <= max_deg_prev;
            max_deg_prev <= max_deg_curr;

            // Increment iteration counter
            k <= k + 1;
          end else begin
            state <= FINAL;
          end
        end
        FINAL: begin
          // Assign outputs
          deg_a <= max_deg_prev; // F_n
          deg_b <= max_deg_prev_prev; // F_{n-1}
          for (i = 0; i < 121; i = i + 1) begin
            a_coeffs[i] <= f_prev[i];
            b_coeffs[i] <= f_prev_prev[i];
          end
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule