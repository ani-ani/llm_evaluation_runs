module arcaea_diversity (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [7:0] frag [0:7],
  input [7:0] step [0:7],
  input [7:0] frag_awaken [0:7],
  input [7:0] step_awaken [0:7],
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PREPARE,
    ENUMERATE,
    COMPUTE,
    UPDATE,
    DONE
  } state_t;

  state_t state, next_state;

  // Counters and registers
  reg [2:0] awakening_count;
  reg [7:0] combination;
  reg [3:0] current_diversity;
  reg [3:0] max_diversity;
  reg [2:0] i, j;
  reg [7:0] current_frag [0:7];
  reg [7:0] current_step [0:7];
  reg [7:0] partner_state [0:7];
  reg [7:0] dominance_mask [0:7];

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PREPARE;
      end
      PREPARE: begin
        next_state = ENUMERATE;
      end
      ENUMERATE: begin
        if (awakening_count == k) next_state = UPDATE;
        else if (combination == (1 << n) - 1) next_state = UPDATE;
        else next_state = COMPUTE;
      end
      COMPUTE: begin
        next_state = ENUMERATE;
      end
      UPDATE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      awakening_count <= 0;
      combination <= 0;
      current_diversity <= 0;
      max_diversity <= 0;
      i <= 0;
      j <= 0;
      for (int p = 0; p < 8; p++) begin
        current_frag[p] <= 0;
        current_step[p] <= 0;
        partner_state[p] <= 0;
        dominance_mask[p] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          // Reset all registers
          awakening_count <= 0;
          combination <= 0;
          current_diversity <= 0;
          max_diversity <= 0;
          i <= 0;
          j <= 0;
          for (int p = 0; p < 8; p++) begin
            current_frag[p] <= 0;
            current_step[p] <= 0;
            partner_state[p] <= 0;
            dominance_mask[p] <= 0;
          end
        end
        PREPARE: begin
          // Initialize for new computation
          awakening_count <= 0;
          combination <= 0;
          current_diversity <= 0;
          max_diversity <= 0;
          i <= 0;
          j <= 0;
          for (int p = 0; p < 8; p++) begin
            current_frag[p] <= 0;
            current_step[p] <= 0;
            partner_state[p] <= 0;
            dominance_mask[p] <= 0;
          end
        end
        ENUMERATE: begin
          // Increment combination counter
          if (combination == (1 << n) - 1) begin
            combination <= 0;
          end else begin
            combination <= combination + 1;
          end
          // Count awakenings in current combination
          awakening_count <= 0;
          for (int p = 0; p < n; p++) begin
            if (combination[p]) awakening_count <= awakening_count + 1;
          end
          // Initialize partner states
          for (int p = 0; p < n; p++) begin
            if (combination[p]) begin
              current_frag[p] <= frag_awaken[p];
              current_step[p] <= step_awaken[p];
            end else begin
              current_frag[p] <= frag[p];
              current_step[p] <= step[p];
            end
          end
        end
        COMPUTE: begin
          // Compute dominance relationships
          for (int p = 0; p < n; p++) begin
            dominance_mask[p] <= 0;
            for (int q = 0; q < n; q++) begin
              if (p != q && current_frag[p] >= current_frag[q] && current_step[p] >= current_step[q]) begin
                dominance_mask[p] <= dominance_mask[p] | (1 << q);
              end
            end
          end
          // Count maximum antichain (simplified for synthesis)
          current_diversity <= 0;
          for (int p = 0; p < n; p++) begin
            if (~|(dominance_mask[p] & ~(1 << p))) begin
              current_diversity <= current_diversity + 1;
            end
          end
        end
        UPDATE: begin
          // Update maximum diversity
          if (current_diversity > max_diversity) begin
            max_diversity <= current_diversity;
          end
          // Signal completion
          done <= 1;
          result <= max_diversity;
        end
        DONE: begin
          // Wait for start to go low
          if (!start) begin
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule