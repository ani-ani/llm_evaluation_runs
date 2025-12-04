module min_k_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0] K,
  input [3:0][7:0] names,
  input [3:0][7:0] scores,
  output reg [3:0][7:0] min_names,
  output reg [3:0][7:0] min_scores,
  output reg done
);

  typedef enum {IDLE, PROCESSING} state_t;
  state_t state;
  
  reg [3:0][7:0] current_names;
  reg [3:0][7:0] current_scores;
  reg [7:0] K_reg;
  reg [4:0] cycle_counter; // 0-19 (20 cycles)
  reg [2:0] step; // 0-5 (6 compare steps)
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      current_names <= '0;
      current_scores <= '0;
      K_reg <= '0;
      cycle_counter <= '0;
      step <= '0;
      min_names <= '0;
      min_scores <= '0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            current_names <= names;
            current_scores <= scores;
            K_reg <= K;
            cycle_counter <= 0;
            step <= 0;
          end
        end
        
        PROCESSING: begin
          if (cycle_counter == 19) begin
            // Update outputs with sorted values
            min_names[0] <= (K_reg >= 8'd1) ? current_names[0] : 8'd0;
            min_names[1] <= (K_reg >= 8'd2) ? current_names[1] : 8'd0;
            min_names[2] <= (K_reg >= 8'd3) ? current_names[2] : 8'd0;
            min_names[3] <= 8'd0;
            
            min_scores[0] <= (K_reg >= 8'd1) ? current_scores[0] : 8'd0;
            min_scores[1] <= (K_reg >= 8'd2) ? current_scores[1] : 8'd0;
            min_scores[2] <= (K_reg >= 8'd3) ? current_scores[2] : 8'd0;
            min_scores[3] <= 8'd0;
            
            done <= 1;
            state <= IDLE;
          end else begin
            cycle_counter <= cycle_counter + 1;
            done <= 0;
            
            if (step < 6) begin
              case (step)
                // Pass 0 (steps 0-2)
                0: begin // Compare indexes 0-1
                  if (current_scores[0] > current_scores[1]) begin
                    current_scores[0:1] <= {current_scores[1], current_scores[0]};
                    current_names[0:1] <= {current_names[1], current_names[0]};
                  end
                end
                1: begin // Compare indexes 1-2
                  if (current_scores[1] > current_scores[2]) begin
                    current_scores[1:2] <= {current_scores[2], current_scores[1]};
                    current_names[1:2] <= {current_names[2], current_names[1]};
                  end
                end
                2: begin // Compare indexes 2-3
                  if (current_scores[2] > current_scores[3]) begin
                    current_scores[2:3] <= {current_scores[3], current_scores[2]};
                    current_names[2:3] <= {current_names[3], current_names[2]};
                  end
                end
                // Pass 1 (steps 3-4)
                3: begin // Compare indexes 0-1
                  if (current_scores[0] > current_scores[1]) begin
                    current_scores[0:1] <= {current_scores[1], current_scores[0]};
                    current_names[0:1] <= {current_names[1], current_names[0]};
                  end
                end
                4: begin // Compare indexes 1-2
                  if (current_scores[1] > current_scores[2]) begin
                    current_scores[1:2] <= {current_scores[2], current_scores[1]};
                    current_names[1:2] <= {current_names[2], current_names[1]};
                  end
                end
                // Pass 2 (step 5)
                5: begin // Compare indexes 0-1
                  if (current_scores[0] > current_scores[1]) begin
                    current_scores[0:1] <= {current_scores[1], current_scores[0]};
                    current_names[0:1] <= {current_names[1], current_names[0]};
                  end
                end
              endcase
              step <= step + 1;
            end
          end
        end
      endcase
    end
  end
endmodule