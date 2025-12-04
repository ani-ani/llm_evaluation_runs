module potato_store_optimizer(
  input        clk,
  input        rst_n,
  input        start,
  input [2:0]  N,
  input [1:0]  L,
  input [3:0][7:0]  a,
  input [3:0][19:0] c,
  output logic [31:0] min_product,
  output logic done
);
  
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_INIT,
    ST_PROCESS,
    ST_DONE
  } state_t;
  
  state_t state, next_state;
  logic [3:0] cnt_subset;
  logic [2:0] cycle;
  logic [3:0] K;
  logic valid_flag;
  
  logic [31:0] total_a;
  logic [31:0] total_c;
  logic [31:0] sum_a1, sum_c1;
  logic [31:0] sum_a2_r, sum_c2_r;
  logic [31:0] P1_reg, P2_reg;
  logic [31:0] product_reg;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= ST_IDLE;
      min_product <= '1;
      done <= 0;
      cnt_subset <= 0;
      cycle <= 0;
    end
    else begin
      case (state)
        ST_IDLE: begin
          if (start) state <= ST_INIT;
          done <= 0;
        end
        
        ST_INIT: begin
          total_a <= (N > 0 ? {24'b0, a[0]} : 0) + (N > 1 ? {24'b0, a[1]} : 0) +
                     (N > 2 ? {24'b0, a[2]} : 0) + (N > 3 ? {24'b0, a[3]} : 0);
          total_c <= (N > 0 ? {12'b0, c[0]} : 0) + (N > 1 ? {12'b0, c[1]} : 0) +
                     (N > 2 ? {12'b0, c[2]} : 0) + (N > 3 ? {12'b0, c[3]} : 0);
          cnt_subset <= 0;
          cycle <= 0;
          state <= ST_PROCESS;
        end
        
        ST_PROCESS: begin
          if (cycle == 5) begin
            cnt_subset <= cnt_subset + 1;
            if (cnt_subset == (1 << N) - 1) state <= ST_DONE;
          end
          cycle <= (cycle == 5) ? 0 : cycle + 1;
        end
        
        ST_DONE: begin
          state <= ST_IDLE;
          done <= 1;
        end
      endcase
      
      if (state == ST_PROCESS && cycle == 3 && valid_flag && product_reg < min_product)
        min_product <= product_reg;
    end
  end

  always_comb begin
    K = '0;
    sum_a1 = '0;
    sum_c1 = '0;
    for (int i=0; i<4; i++) begin
      if (i < N && cnt_subset[i]) begin
        K += 1;
        sum_a1 += {24'b0, a[i]};
        sum_c1 += {12'b0, c[i]};
      end
    end
  end
  
  assign valid_flag = ((K >= L) || (K <= (N - L))) && (K != 0) && (K != N);
  assign sum_a2_r = total_a - sum_a1;
  assign sum_c2_r = total_c - sum_c1;
  
  always_ff @(posedge clk) begin
    if (state == ST_PROCESS && cycle == 1 && valid_flag) begin
      P1_reg <= (sum_c1 << 16) / sum_a1;
      P2_reg <= (sum_c2_r << 16) / sum_a2_r;
    end
    if (state == ST_PROCESS && cycle == 2 && valid_flag)
      product_reg <= (P1_reg * P2_reg) >> 16;
  end
  
endmodule