module t_return_day_finder(
  input clk,
  input rst_n,
  input start,
  input [4:0] L,
  input [15:0] adj_matrix_row0,
  input [15:0] adj_matrix_row1,
  input [15:0] adj_matrix_row2,
  output reg signed [5:0] T_out,
  output reg done
);

  localparam HI_TOL = 20'd996353;
  localparam LO_TOL = 20'd996351;
  
  typedef enum {
    IDLE,
    INIT,
    COMPUTE_DAY,
    CHECK_RESULT,
    STEP_DAY,
    DONE
  } state_t;
  
  reg [2:0] state;
  reg [5:0] day;
  reg [5:0] t_ptr;
  reg [19:0] probs [0:3];
  reg [3:0][3:0] adj[0:2];
  reg found;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      T_out <= -1;
      done <= 0;
      day <= 0;
      t_ptr <= 0;
      found <= 0;
      foreach(probs[i]) probs[i] <= 0;
      foreach(adj[i,j]) adj[i][j] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          T_out <= -1;
          if (start) begin
            state <= INIT;
          end
        end
        
        INIT: begin
          probs[0] <= 20'h400; // node1 = 1.0 Q10.10
          probs[1] <= 0;
          probs[2] <= 0;
          probs[3] <= 0;
          day <= 0;
          t_ptr <= L;
          found <= 0;
          
          // Store adjacency matrix
          for (int i=0; i<4; i++) begin
            adj[0][i] <= adj_matrix_row0[15-4*i -:4];
            adj[1][i] <= adj_matrix_row1[15-4*i -:4];
            adj[2][i] <= adj_matrix_row2[15-4*i -:4];
          end
          
          state <= COMPUTE_DAY;
        end
        
        COMPUTE_DAY: begin
          // Propagate probabilities using adjacency matrix
          begin
            reg [19:0] next_probs [0:3] = '{0,0,0,0};
            for (int i=0; i<3; i++) begin
              integer sum_weights = adj[i][0] + adj[i][1] + adj[i][2] + adj[i][3];
              if (sum_weights != 0) begin
                for (int j=0; j<4; j++) begin
                  reg [23:0] contrib = (probs[i] * adj[i][j]);
                  next_probs[j] = next_probs[j] + contrib / sum_weights;
                end
              end
            end
            probs[0] <= next_probs[0];
            probs[1] <= next_probs[1];
            probs[2] <= next_probs[2];
            probs[3] <= next_probs[3];
          end
          
          day <= day + 1;
          state <= CHECK_RESULT;
        end
        
        CHECK_RESULT: begin
          if ((day >= L) && (day <= (L + 9)) && (day <= 31)) begin
            if ((probs[3] >= LO_TOL) && (probs[3] <= HI_TOL) && !found) begin
              T_out <= day;
              found <= 1;
              state <= DONE;
            end
          end
          
          if (day == (L + 9) || day == 31) begin
            if (!found) T_out <= -1;
            state <= DONE;
          end else begin
            state <= COMPUTE_DAY;
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