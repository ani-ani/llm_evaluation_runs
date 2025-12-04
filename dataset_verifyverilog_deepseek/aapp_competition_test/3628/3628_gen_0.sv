module permutation_crypto (
  input clk,
  input rst_n,
  input start,
  input [3:0] a [0:7],
  output reg [3:0] pi [0:7],
  output reg [3:0] sigma [0:7],
  output reg valid,
  output reg impossible,
  output reg done
);
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] CHECK = 2'b01;
  localparam [1:0] FOUND = 2'b10;
  localparam [1:0] NOT_FOUND = 2'b11;

  reg [1:0] state;
  reg [3:0] current_pi [0:7];
  wire is_last_perm;
  wire is_sigma_valid;
  reg [3:0] next_pi [0:7];
  reg [3:0] temp_sigma [0:7];
  integer i, j, m;
  reg [2:0] found_k, found_l;
  reg [3:0] temp_swap;
  reg [7:0] seen;
  reg [2:0] idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      impossible <= 0;
      for (i = 0; i < 8; i++) begin
        current_pi[i] <= i;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          impossible <= 0;
          valid <= 0;
          if (start) begin
            state <= CHECK;
            for (i = 0; i < 8; i++) begin
              current_pi[i] <= i;
            end
          end
        end

        CHECK: begin
          done <= 0;
          if (is_sigma_valid) begin
            state <= FOUND;
            done <= 1;
            valid <= 1;
            for (i = 0; i < 8; i++) begin
              pi[i] <= current_pi[i];
            end
            for (i = 0; i < 8; i++) begin
              sigma[i] <= temp_sigma[i];
            end
          end else if (is_last_perm) begin
            state <= NOT_FOUND;
            done <= 1;
            impossible <= 1;
          end else begin
            current_pi <= next_pi;
            state <= CHECK;
          end
        end

        FOUND: begin
          state <= IDLE;
          done <= 0;
        end

        NOT_FOUND: begin
          state <= IDLE;
          done <= 0;
        end
      endcase
    end
  end

  always_comb begin
    next_pi = current_pi;
    found_k = 3'b111;
    for (i = 6; i >= 0; i--) begin
      if (current_pi[i] < current_pi[i + 1]) begin
        found_k = i;
        break;
      end
    end
    is_last_perm = (found_k == 3'b111);
    if (!is_last_perm) begin
      found_l = found_k + 1;
      for (j = 7; j > found_k; j--) begin
        if (current_pi[j] > current_pi[found_k]) begin
          found_l = j;
          break;
        end
      end
      temp_swap = next_pi[found_k];
      next_pi[found_k] = next_pi[found_l];
      next_pi[found_l] = temp_swap;
      for (m = 0; m < ((8 - found_k - 1) / 2); m++) begin
        temp_swap = next_pi[found_k + 1 + m];
        next_pi[found_k + 1 + m] = next_pi[7 - m];
        next_pi[7 - m] = temp_swap;
      end
    end
  end

  always_comb begin
    for (i = 0; i < 8; i++) begin
      temp_sigma[i] = (a[i] - current_pi[i] + 8) % 8;
    end
    seen = 8'b0;
    is_sigma_valid = 1;
    for (i = 0; i < 8; i++) begin
      idx = temp_sigma[i][2:0];
      if (seen[idx]) is_sigma_valid = 0;
      else seen[idx] = 1'b1;
    end
  end

endmodule