module gcd_distinct_count(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0][15:0] a,
  output reg [5:0] count,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam GCD_CALC = 2'b10;
  localparam DONE_ST = 2'b11;
  
  reg [1:0] state, next_state;
  reg [2:0] i, next_i;
  reg [2:0] j, next_j;
  reg [15:0] a_reg, b_reg, next_gcd;
  reg [15:0] unique_gcds [0:35];
  reg [5:0] count_unique, next_count;
  reg [7:0] cycle_cnt;
  reg calc_done;
  
  integer k;
  reg is_unique;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 3'b0;
      j <= 3'b0;
      count_unique <= 6'b0;
      unique_gcds[0] <= 16'b0;
      cycle_cnt <= 8'b0;
      done <= 1'b0;
      count <= 6'b0;
      a_reg <= 16'b0;
      b_reg <= 16'b0;
    end else begin
      state <= next_state;
      i <= next_i;
      j <= next_j;
      cycle_cnt <= (state == COMPUTE || state == GCD_CALC) ? cycle_cnt + 8'b1 : 8'b0;
      
      if (state == COMPUTE) begin
        if (j == i) begin
          is_unique = 1'b1;
          for (k=0; k<count_unique; k=k+1) begin
            if (unique_gcds[k] == a[i]) is_unique = 1'b0;
          end
          if (is_unique) begin
            unique_gcds[count_unique] <= a[i];
            count_unique <= count_unique + 6'b1;
          end
        end
      end else if (state == GCD_CALC) begin
        if (b_reg == 0) begin
          next_gcd = a_reg;
          a_reg <= a_reg;
          b_reg <= b_reg;
        end else begin
          a_reg <= b_reg;
          b_reg <= a_reg % b_reg;
        end
        
        if (calc_done) begin
          is_unique = 1'b1;
          for (k=0; k<count_unique; k=k+1) begin
            if (unique_gcds[k] == next_gcd) is_unique = 1'b0;
          end
          if (is_unique) begin
            unique_gcds[count_unique] <= next_gcd;
            count_unique <= count_unique + 6'b1;
          end
        end
      end else if (state == DONE_ST) begin
        done <= 1'b1;
        count <= count_unique;
      end else begin
        done <= 1'b0;
      end
    end
  end
  
  always_comb begin
    next_state = state;
    next_i = i;
    next_j = j;
    calc_done = 1'b0;
    
    case(state)
      IDLE: begin
        if (start) begin
          next_state = COMPUTE;
          next_i = 0;
          next_j = 0;
        end
      end
      
      COMPUTE: begin
        if (cycle_cnt == 8'd255) begin
          next_state = DONE_ST;
        end else if (i < n) begin
          if (j < n) begin
            if (j == i) begin
              next_j = j + 1;
            end else begin
              next_state = GCD_CALC;
            end
          end else begin
            next_i = i + 1;
            next_j = next_i;
          end
        end else begin
          next_state = DONE_ST;
        end
      end
      
      GCD_CALC: begin
        if (b_reg == 0) begin
          calc_done = 1'b1;
          next_state = COMPUTE;
          next_j = j + 1;
        end
      end
      
      DONE_ST: next_state = IDLE;
    endcase
  end

  initial begin
    for (k=0; k<36; k=k+1) begin
      unique_gcds[k] = 0;
    end
  end

endmodule