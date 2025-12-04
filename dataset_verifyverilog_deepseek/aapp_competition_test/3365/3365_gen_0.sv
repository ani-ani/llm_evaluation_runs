module max_partition_score(
  input clk,
  input rst_n,
  input start,
  input [7:0] v0,
  input [7:0] v1,
  input [7:0] v2,
  input [7:0] v3,
  input [7:0] v4,
  input [7:0] v5,
  input [7:0] v6,
  input [7:0] v7,
  input [1:0] k,
  output reg [7:0] score,
  output reg done
);

  typedef enum logic [2:0] { IDLE, COMPUTE_GCD, FIND_PRIMES, DP_CALC, DONE } state_t;
  state_t state, next_state;

  reg [7:0] v_array[0:7];
  reg [1:0] current_k;
  reg [7:0] gcd_results[0:7][0:7];
  reg [7:0] prime_scores[0:7][0:7];
  reg [7:0] dp_table[1:4][0:7];

  reg [2:0] i_cnt;
  reg [3:0] j_cnt;
  reg [3:0] m_cnt;
  reg [7:0] current_max;
  wire [7:0] temp_min;

  function automatic [7:0] gcd_two(input [7:0] a, b);
    reg [7:0] r, aa, bb;
    begin
      aa = a;
      bb = b;
      while (bb != 0) begin
        r = aa % bb;
        aa = bb;
        bb = r;
      end
      gcd_two = aa;
    end
  endfunction

  function automatic is_prime(input [7:0] n);
    integer i;
    begin
      if (n < 2) is_prime = 0;
      else if (n == 2) is_prime = 1;
      else if (n % 2 == 0) is_prime = 0;
      else begin
        is_prime = 1;
        for (i = 3; i * i <= n; i = i + 2)
          if (n % i == 0) begin is_prime = 0; break; end
      end
    end
  endfunction

  function automatic [7:0] largest_prime_divisor(input [7:0] n);
    reg [7:0] lpd;
    integer i;
    begin
      lpd = 0;
      if (n < 2) return 0;
      for (i = n; i >= 2; i = i - 1)
        if (n % i == 0 && is_prime(i)) begin
          lpd = i;
          break;
        end
      largest_prime_divisor = lpd;
    end
  endfunction

  always_comb begin
    for (int i = 0; i < 8; i++) begin
      for (int j = i; j < 8; j++) begin
        automatic reg [7:0] g = v_array[i];
        for (int idx = i+1; idx <= j; idx++)
          g = gcd_two(g, v_array[idx]);
        gcd_results[i][j] = g;
        prime_scores[i][j] = largest_prime_divisor(g);
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      score <= 0;
      for (int i = 0; i < 8; i++) v_array[i] <= 0;
      current_k <= 0;
      i_cnt <= 0;
      j_cnt <= 0;
      m_cnt <= 0;
      current_max <= 0;
      for (int i = 1; i <= 4; i++)
        for (int j = 0; j < 8; j++) dp_table[i][j] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            v_array[0] <= v0;
            v_array[1] <= v1;
            v_array[2] <= v2;
            v_array[3] <= v3;
            v_array[4] <= v4;
            v_array[5] <= v5;
            v_array[6] <= v6;
            v_array[7] <= v7;
            current_k <= k;
            state <= COMPUTE_GCD;
          end
        end

        COMPUTE_GCD: state <= FIND_PRIMES;

        FIND_PRIMES: begin
          for (int j = 0; j < 8; j++)
            dp_table[1][j] <= prime_scores[0][j];
          i_cnt <= 2;
          j_cnt <= 2'd1;
          m_cnt <= 0;
          current_max <= 0;
          state <= DP_CALC;
        end

        DP_CALC: begin
          if (i_cnt > current_k) begin
            score <= dp_table[current_k][7];
            state <= DONE;
          end else if (j_cnt > 4'd7) begin
            i_cnt <= i_cnt + 1'b1;
            j_cnt <= i_cnt;
            m_cnt <= (i_cnt > 1) ? (i_cnt - 2) : 0;
            current_max <= 0;
          end else if (m_cnt > j_cnt - 1) begin
            dp_table[i_cnt][j_cnt] <= current_max;
            j_cnt <= j_cnt + 1'b1;
            m_cnt <= (i_cnt > 1) ? (i_cnt - 2) : 0;
            current_max <= 0;
          end else begin
            temp_min = (dp_table[i_cnt-1][m_cnt] < prime_scores[m_cnt+1][j_cnt]) ? 
                       dp_table[i_cnt-1][m_cnt] : prime_scores[m_cnt+1][j_cnt];
            if (temp_min > current_max) current_max <= temp_min;
            m_cnt <= m_cnt + 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (~start) state <= IDLE;
        end
      endcase
    end
  end
endmodule