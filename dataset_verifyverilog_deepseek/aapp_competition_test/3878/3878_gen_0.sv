module min_clique_steps (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [4:0] m,
  input [2:0] u_in,
  input [2:0] v_in,
  input edge_valid,
  output reg [3:0] step_count,
  output reg [2:0] guest_steps [0:7],
  output reg done
);

  typedef enum logic [2:0] { IDLE, LOAD, PRE_COMPUTE, COMPUTE, BACKTRACE, DONE } state_t;
  state_t state;

  reg [7:0] adj [0:7];
  reg [7:0] is_clique;
  reg [3:0] dp [0:255];
  reg [7:0] backtrace [0:255];
  reg [7:0] mask_full;

  // Queue structures
  reg [7:0] queue [0:255];
  reg [7:0] q_head, q_tail;
  reg [255:0] enqueued;

  reg [4:0] edge_cnt;
  reg [8:0] compute_cnt;
  reg [3:0] btr_step;
  reg [7:0] current_mask;
  reg [2:0] n_reg;

  // Function to find first set bit
  function automatic [2:0] first_set(input [7:0] mask);
    for (int i=0; i<8; i++) begin
      if (mask[i]) begin
        return i[2:0];
      end
    end
    return 0;
  endfunction

  // Main state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      step_count <= 0;
      q_head <= 0;
      q_tail <= 0;
      enqueued <= 0;
      edge_cnt <= 0;
      foreach (guest_steps[i]) guest_steps[i] <= 0;
      foreach (adj[i]) adj[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= LOAD;
            edge_cnt <= 0;
            n_reg <= n;
          end
        end

        LOAD: begin
          if (edge_valid) begin
            adj[u_in] <= adj[u_in] | (1 << v_in);
            adj[v_in] <= adj[v_in] | (1 << u_in);
            edge_cnt <= edge_cnt + 1;
          end
          if (edge_cnt == m) begin
            state <= PRE_COMPUTE;
            mask_full <= (1 << n) - 1;
          end
        end

        PRE_COMPUTE: begin
          // Compute is_clique
          for (int subset=0; subset<256; subset++) begin
            automatic bit valid = 1;
            for (int i=0; i<8; i++) begin
              if (subset[i]) begin
                for (int j=i+1; j<8; j++) begin
                  if (subset[j] && !adj[i][j]) valid = 0;
                end
              end
            end
            is_clique[subset] <= valid;
          end
          // Initialize DP
          for (int i=0; i<256; i++) begin
            dp[i] <= 8;
          end
          for (int i=0; i<8; i++) begin
            dp[1<<i] <= 0;
            queue[q_tail] <= 1<<i;
            q_tail <= q_tail +1;
            enqueued[1<<i] <= 1;
          end
          compute_cnt <= 0;
          state <= COMPUTE;
        end

        COMPUTE: begin
          if (q_head != q_tail && compute_cnt < 300) begin
            current_mask <= queue[q_head];
            q_head <= q_head + 1;
            enqueued[current_mask] <= 0;

            for (int clique=0; clique<256; clique++) begin
              if (is_clique[clique] && !(clique & current_mask)) begin
                automatic bit [7:0] new_mask = current_mask | clique;
                automatic bit [3:0] new_step = dp[current_mask] + 1;
                if (new_step < dp[new_mask]) begin
                  dp[new_mask] <= new_step;
                  backtrace[new_mask] <= clique;
                  if (!enqueued[new_mask]) begin
                    queue[q_tail] <= new_mask;
                    q_tail <= q_tail +1;
                    enqueued[new_mask] <= 1;
                  end
                end
              end
            end
            compute_cnt <= compute_cnt + 1;
          end else begin
            state <= BACKTRACE;
            btr_step <= dp[mask_full];
            current_mask <= mask_full;
          end
        end

        BACKTRACE: begin
          if (btr_step > 0) begin
            automatic bit [7:0] prev_clique = backtrace[current_mask];
            guest_steps[btr_step-1] <= first_set(prev_clique);
            step_count <= btr_step;
            current_mask <= current_mask & ~prev_clique;
            btr_step <= btr_step - 1;
          end else begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (start) state <= IDLE;
        end
      endcase
    end
  end

endmodule