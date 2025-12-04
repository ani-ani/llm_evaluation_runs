module permutation_checker(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] k,
  input [23:0] q,
  input [23:0] s,
  output reg result,
  output reg done
);

  typedef enum logic [2:0] { IDLE, INIT, CHECK_E, CHECK_F, DONE } state_t;
  state_t state, next_state;
  
  reg [2:0] q_arr[0:7];
  reg [2:0] s_arr[0:7];
  reg [2:0] inv_q_arr[0:7];
  reg s_is_identity;
  reg match_q;
  reg match_inv_q;
  reg valid_e;
  reg valid_f;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      foreach (q_arr[i]) q_arr[i] <= 0;
      foreach (s_arr[i]) s_arr[i] <= 0;
      foreach (inv_q_arr[i]) inv_q_arr[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          result <= 0;
          if (start) begin
            foreach (q_arr[i]) q_arr[i] <= (i < n) ? q[i*3 +: 3] : 0;
            foreach (s_arr[i]) s_arr[i] <= (i < n) ? s[i*3 +: 3] : 0;
            state <= INIT;
          end
        end
        
        INIT: begin
          // Check if s is identity
          s_is_identity <= 1;
          for (int i=0; i<8; i++) begin
            if (i < n) begin
              if (s_arr[i] != i)
                s_is_identity <= 0;
            end
          end
          
          // Compute inverse of q
          for (int j=0; j<8; j++) begin
            inv_q_arr[j] <= 0;
            for (int i=0; i<8; i++) begin
              if (i < n && j < n && q_arr[i] == j)
                inv_q_arr[j] <= i;
            end
          end
          
          state <= (s_is_identity) ? DONE : CHECK_E;
        end
        
        CHECK_E: begin
          match_q <= 1;
          for (int i=0; i<8; i++) begin
            if (i < n && q_arr[i] != s_arr[i])
              match_q <= 0;
          end
          valid_e <= match_q && (k == 4'd1);
          state <= CHECK_F;
        end
        
        CHECK_F: begin
          match_inv_q <= 1;
          for (int i=0; i<8; i++) begin
            if (i < n && inv_q_arr[i] != s_arr[i])
              match_inv_q <= 0;
          end
          valid_f <= match_inv_q && (k == 4'd1);
          state <= DONE;
        end
        
        DONE: begin
          done <= 1;
          result <= (s_is_identity) ? 1'b0 : (valid_e || valid_f);
          state <= IDLE;
        end
      endcase
    end
  end
  
endmodule