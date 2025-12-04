module theorem_dag_min_length(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_theorems,
  input [3:0] num_proofs [0:3],
  input [31:0] proof_lengths [0:3][0:9],
  input [1:0] num_deps [0:3][0:9],
  input [1:0] deps [0:3][0:9][0:2],
  output reg [31:0] min_length,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    INIT,
    PROCESS_THM,
    WAIT_CYCLES,
    DONE
  } state_t;
  
  state_t state;
  reg [3:0] theorem_idx;
  reg [31:0] min_lengths [0:3];
  reg [3:0] cycle_count;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      theorem_idx <= 0;
      min_length <= 0;
      done <= 0;
      cycle_count <= 0;
      min_lengths[0] <= '1;
      min_lengths[1] <= '1;
      min_lengths[2] <= '1;
      min_lengths[3] <= '1;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          cycle_count <= 0;
          if (start) begin
            state <= INIT;
          end
        end

        INIT: begin
          min_lengths[0] <= '1;
          min_lengths[1] <= '1;
          min_lengths[2] <= '1;
          min_lengths[3] <= '1;
          theorem_idx <= 0;
          state <= PROCESS_THM;
          cycle_count <= 1;
        end

        PROCESS_THM: begin
          cycle_count <= cycle_count + 1;
          // Calculate min proof length for current theorem
          begin
            reg [31:0] current_min;
            current_min = min_lengths[theorem_idx];
            for (integer p = 0; p < 10; p++) begin
              if (p < num_proofs[theorem_idx]) begin
                reg [31:0] total;
                total = proof_lengths[theorem_idx][p];
                for (integer k = 0; k < 3; k++) begin
                  if (k < num_deps[theorem_idx][p]) begin
                    total += min_lengths[deps[theorem_idx][p][k]];
                  end
                end
                if (total < current_min) current_min = total;
              end
            end
            min_lengths[theorem_idx] <= current_min;
          end
          
          if (theorem_idx == num_theorems - 1) begin
            state <= WAIT_CYCLES;
          end
          else begin
            theorem_idx <= theorem_idx + 1;
          end
        end
        
        WAIT_CYCLES: begin
          cycle_count <= cycle_count + 1;
          if (cycle_count >= 8) begin
            min_length <= min_lengths[0];
            state <= DONE;
          end
        end
        
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule