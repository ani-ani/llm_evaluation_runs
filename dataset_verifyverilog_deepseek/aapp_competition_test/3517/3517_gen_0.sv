module critical_path_optimizer(
  input clk,
  input rst_n,
  input start,
  input [1:0] node_count,
  input [7:0] time_vals [0:3],
  input [3:0] deps [0:3],
  output reg [7:0] min_time,
  output reg done
);

  typedef enum {IDLE, CALCULATE_BASELINE, TRY_ELIMINATE, DONE} state_t;
  state_t state, next_state;

  reg [7:0] mod_time_vals [0:3];
  reg [1:0] elim_node;
  reg [7:0] current_cp;
  reg [2:0] cycle_count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_time <= '1;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 0;
          min_time <= '1;
          if (start) begin
            cycle_count <= 0;
            next_state <= CALCULATE_BASELINE;
          end
        end

        CALCULATE_BASELINE: begin
          cycle_count <= cycle_count + 1;
          mod_time_vals <= time_vals;
          elim_node <= 0;
          next_state <= TRY_ELIMINATE;
        end

        TRY_ELIMINATE: begin
          cycle_count <= cycle_count + 1;
          
          
          mod_time_vals <= time_vals;
          mod_time_vals[elim_node] <= 0;
          
          
          current_cp <= compute_cp(mod_time_vals, deps, node_count);
          
          
          if (current_cp < min_time) min_time <= current_cp;
          
          if (elim_node == node_count) begin
            next_state <= DONE;
          end else begin
            elim_node <= elim_node + 1;
          end
          
          if (cycle_count >= 39) next_state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) next_state <= IDLE;
        end
      endcase
    end
  end

  function automatic [7:0] compute_cp(input [7:0] t_vals[0:3], input [3:0] dp[0:3], input [1:0] n);
    reg [7:0] earliest_start[0:3];
    reg [7:0] max_time;
    integer i, j;
    begin
      for (i = 0; i <= n; i = i+1) earliest_start[i] = 0;
      
      for (i = 0; i <= n; i = i+1) begin
        max_time = 0;
        for (j = 0; j <= n; j = j+1) begin
          if (dp[i][j]) begin
            if (earliest_start[j] + t_vals[j] > max_time) begin
              max_time = earliest_start[j] + t_vals[j];
            end
          end
        end
        earliest_start[i] = max_time;
      end
      
      compute_cp = 0;
      for (i = 0; i <= n; i = i+1) begin
        if (earliest_start[i] + t_vals[i] > compute_cp) begin
          compute_cp = earliest_start[i] + t_vals[i];
        end
      end
    end
  endfunction

endmodule