module loda_teleportations(
  input clk,
  input rst_n,
  input start,
  input [7:0] string_count,
  input [15:0][7:0] strings [0:7],
  input [4:0] lengths [0:7],
  output reg [3:0] max_length,
  output reg done
);

  typedef enum logic [2:0] { IDLE, COMPUTE_MATRIX, COMPUTE_DP, FIND_MAX, WAIT, DONE } state_t;
  reg [2:0] state;
  reg [5:0] cycle_counter;
  reg [7:0][7:0] matrix;
  reg [3:0] dp [0:7];
  reg [2:0] current_node;
  
  // Combinational compatibility matrix
  wire [7:0][7:0] matrix_comb;
  
  generate
    genvar i, j, k;
    for (i=0; i<8; i=i+1) begin: gen_i
      for (j=0; j<8; j=j+1) begin: gen_j
        if (j > i) begin: j_gt_i
          logic [15:0] start_eq;
          logic [15:0] end_eq;
          logic starts_with, ends_with;
          
          for (k=0; k<16; k=k+1) begin: gen_k_start
            assign start_eq[k] = (k < lengths[i]) ? (strings[i][k] == strings[j][k]) : 1'b1;
          end
          assign starts_with = (lengths[j] >= lengths[i]) ? &start_eq : 1'b0;
          
          for (k=0; k<16; k=k+1) begin: gen_k_end
            wire [4:0] pos = lengths[j] - lengths[i] + k;
            assign end_eq[k] = (k < lengths[i] && pos < 16) ? 
                              (strings[i][k] == strings[j][pos]) : 
                              ((k >= lengths[i]) ? 1'b1 : 1'b0);
          end
          assign ends_with = (lengths[j] >= lengths[i]) ? &end_eq : 1'b0;
          
          assign matrix_comb[i][j] = (j < string_count) ? (starts_with && ends_with) : 1'b0;
        end else begin
          assign matrix_comb[i][j] = 1'b0;
        end
      end
    end
  endgenerate
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_length <= 4'd0;
      cycle_counter <= 6'd0;
      matrix <= '0;
      foreach (dp[idx]) dp[idx] <= 4'd0;
      current_node <= 3'd0;
    end else begin
      done <= 1'b0;
      
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE_MATRIX;
            cycle_counter <= 6'd0;
          end
        end
        
        COMPUTE_MATRIX: begin
          matrix <= matrix_comb;
          foreach (dp[idx]) dp[idx] <= 4'd1;
          current_node <= 3'd0;
          state <= COMPUTE_DP;
          cycle_counter <= cycle_counter + 1;
        end
        
        COMPUTE_DP: begin
          if (current_node < 8) begin
            for (int i=0; i < current_node; i=i+1) begin
              if (matrix[i][current_node] && (dp[i] + 1 > dp[current_node])) begin
                dp[current_node] <= dp[i] + 1;
              end
            end
            current_node <= current_node + 1;
            cycle_counter <= cycle_counter + 1;
          end else begin
            state <= FIND_MAX;
            cycle_counter <= cycle_counter + 1;
          end
        end
        
        FIND_MAX: begin
          max_length <= 4'd1;
          for (int i=0; i<8; i=i+1) begin
            if (dp[i] > max_length) max_length <= dp[i];
          end
          state <= WAIT;
          cycle_counter <= cycle_counter + 1;
        end
        
        WAIT: begin
          if (cycle_counter == 6'd49) begin
            state <= DONE;
            done <= 1'b1;
          end else begin
            cycle_counter <= cycle_counter + 1;
          end
        end
        
        DONE: begin
          done <= 1'b0;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
  
endmodule