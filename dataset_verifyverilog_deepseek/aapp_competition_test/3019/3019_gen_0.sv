module max_revenue_calculator (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [9:0] S0,
  input [9:0] S1,
  input [9:0] S2,
  input [9:0] S3,
  input [9:0] S4,
  output logic [7:0] max_rev,
  output logic done
);

enum logic [2:0] {IDLE, INIT, COMPUTE, DONE} state;
logic [14:0] assignment_counter;
logic [14:0] n_power_n;
logic [7:0] rom_prime_count [0:5000];
logic [10:0] customer_sums [4:0];
logic [7:0] current_rev;
logic [2:0] assigments [4:0];
logic [9:0] S_data [4:0];

function int count_distinct_primes(int num);
  if (num <= 1) return 0;
  int cnt = 0;
  int temp = num;
  for (int i = 2; i * i <= temp; i++) begin
    if (temp % i == 0) begin
      cnt++;
      while (temp % i == 0) temp /= i;
    end
  end
  if (temp > 1) cnt++;
  return cnt;
endfunction

initial begin
  for (int i = 0; i <= 5000; i++) begin
    rom_prime_count[i] = count_distinct_primes(i);
  end
end

assign S_data = '{S0, S1, S2, S3, S4};

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    max_rev <= 8'b0;
    done <= 1'b0;
    assignment_counter <= 15'b0;
    current_rev <= 8'b0;
    n_power_n <= 15'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) state <= INIT;
      end
      INIT: begin
        max_rev <= 8'b0;
        current_rev <= 8'b0;
        n_power_n <= N ** N;
        assignment_counter <= 15'b0;
        state <= COMPUTE;
      end
      COMPUTE: begin
        if (assignment_counter < n_power_n) begin
          automatic logic [7:0] total = 8'b0;
          assignment_counter <= assignment_counter + 1;
          foreach (customer_sums[i]) customer_sums[i] = 11'b0;
          foreach (assigments[i]) 
            if (i < N) assigments[i] = (assignment_counter / (N**i)) % N;
          foreach (S_data[i]) 
            if (i < N) customer_sums[assigments[i]] += S_data[i];
          foreach (customer_sums[i]) 
            if (i < N && customer_sums[i] > 1) total += rom_prime_count[customer_sums[i]];
          if (total > max_rev) max_rev <= total;
        end else begin
          state <= DONE;
        end
      end
      DONE: begin
        done <= 1'b1;
        if (!start) state <= IDLE;
      end
    endcase
  end
end

endmodule