module remainder_game_decider(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] k,
  input [16*8-1:0] c_i, // flattened to 128-bit packed array
  output reg result,
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, COMPUTE_GCD, COMPUTE_LCM, COMPARE, DONE} state_t;
  state_t state;

  reg [15:0] gcd_results [0:7];
  reg [3:0] cycle_count;
  reg [3:0] index;
  reg [15:0] current_a, current_b;
  reg [15:0] temp_a, temp_b;
  reg [15:0] current_lcm;
  reg [3:0] n_reg;
  reg [15:0] k_reg;

  // Unflatten c_i from 128-bit input
  wire [15:0] c_i_unpacked [0:7];
  generate
    genvar i;
    for (i=0; i<8; i++) begin
      assign c_i_unpacked[i] = c_i[i*16 +: 16];
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      cycle_count <= 0;
      index <= 0;
      foreach(gcd_results[i]) gcd_results[i] <= 0;
      current_a <= 0;
      current_b <= 0;
      current_lcm <= 0;
      n_reg <= 0;
      k_reg <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= INIT;
            n_reg <= n;
            k_reg <= k;
          end
        end

        INIT: begin
          cycle_count <= 0;
          index <= 0;
          state <= COMPUTE_GCD;
          foreach(gcd_results[i]) begin
            if (i < n_reg) begin
              gcd_results[i] <= 0;
              current_a <= (k_reg > c_i_unpacked[i]) ? k_reg : c_i_unpacked[i];
              current_b <= (k_reg > c_i_unpacked[i]) ? c_i_unpacked[i] : k_reg;
            end
          end
        end

        COMPUTE_GCD: begin
          if (cycle_count < 16) begin
            cycle_count <= cycle_count + 1;
            foreach(gcd_results[j]) begin
              if (j < n_reg) begin
                if (current_b != 0) begin
                  temp_a = current_b;
                  temp_b = current_a % current_b;
                  current_a <= temp_a;
                  current_b <= temp_b;
                end
              end
            end
          end else begin
            foreach(gcd_results[j]) begin
              if (j < n_reg) begin
                gcd_results[j] <= current_a;
              end
            end
            state <= COMPUTE_LCM;
            index <= 1;
            current_lcm <= gcd_results[0];
            cycle_count <= 0;
          end
        end

        COMPUTE_LCM: begin
          if (index < n_reg) begin
            if (cycle_count == 0) begin
              current_a <= (current_lcm > gcd_results[index]) ? current_lcm : gcd_results[index];
              current_b <= (current_lcm > gcd_results[index]) ? gcd_results[index] : current_lcm;
            end

            if (cycle_count < 16) begin
              cycle_count <= cycle_count + 1;
              if (current_b != 0) begin
                temp_a = current_b;
                temp_b = current_a % current_b;
                current_a <= temp_a;
                current_b <= temp_b;
              end
            end else begin
              if (current_a != 0) 
                current_lcm <= (current_lcm * gcd_results[index]) / current_a;
              index <= index + 1;
              cycle_count <= 0;
            end
          end else begin
            state <= COMPARE;
          end
        end

        COMPARE: begin
          result <= (current_lcm == k_reg) ? 1'b1 : 1'b0;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
