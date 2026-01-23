module dance_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] N,
  input [7:0] K,
  input [7:0] A_in [0:7],
  output reg [7:0] P_out [0:7],
  output reg done,
  output reg possible
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PREPARE,
    COMPUTE_P,
    VERIFY,
    DONE
  } state_t;
  state_t state;

  // Internal registers
  reg [7:0] cycle_start [0:7];
  reg [7:0] cycle_length [0:7];
  reg [7:0] visited [0:7];
  reg [7:0] current_cycle [0:7];
  reg [7:0] current_index;
  reg [7:0] cycle_count;
  reg [7:0] offset;
  reg [7:0] j;
  reg [7:0] g;
  reg [7:0] L;
  reg [7:0] G;
  reg [7:0] M;
  reg [7:0] temp;
  reg [7:0] i;
  reg [7:0] k;
  reg [7:0] verify_index;
  reg [7:0] verify_temp;
  reg [7:0] verify_count;
  reg [7:0] P_temp [0:7];

  // GCD function
  function [7:0] gcd;
    input [7:0] a, b;
    reg [7:0] x, y;
    begin
      x = a;
      y = b;
      while (y != 0) begin
        temp = y;
        y = x % y;
        x = temp;
      end
      gcd = x;
    end
  endfunction

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      possible <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        P_out[i] <= 0;
        visited[i] <= 0;
        cycle_start[i] <= 0;
        cycle_length[i] <= 0;
      end
      current_index <= 0;
      cycle_count <= 0;
      offset <= 0;
      j <= 0;
      g <= 0;
      L <= 0;
      G <= 0;
      M <= 0;
      i <= 0;
      k <= 0;
      verify_index <= 0;
      verify_temp <= 0;
      verify_count <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        P_temp[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREPARE;
            done <= 0;
            possible <= 0;
            for (i = 0; i < 8; i = i + 1) begin
              visited[i] <= 0;
              cycle_start[i] <= 0;
              cycle_length[i] <= 0;
            end
            current_index <= 0;
            cycle_count <= 0;
          end
        end
        PREPARE: begin
          // Find cycles in A
          if (current_index < N) begin
            if (!visited[current_index]) begin
              // Start new cycle
              cycle_start[cycle_count] <= current_index;
              temp <= current_index;
              L <= 0;
              // Traverse cycle
              while (!visited[temp]) begin
                visited[temp] <= 1;
                current_cycle[L] <= temp;
                L <= L + 1;
                temp <= A_in[temp];
              end
              cycle_length[cycle_count] <= L;
              cycle_count <= cycle_count + 1;
            end
            current_index <= current_index + 1;
          end else begin
            state <= COMPUTE_P;
            current_index <= 0;
            cycle_count <= 0;
          end
        end
        COMPUTE_P: begin
          // Construct P from cycles
          if (cycle_count < cycle_count) begin
            L <= cycle_length[cycle_count];
            G <= gcd(L, K);
            M <= L / G;
            for (g = 0; g < G; g = g + 1) begin
              for (j = 0; j < M; j = j + 1) begin
                temp <= (g + j * K) % L;
                P_temp[current_cycle[temp]] <= current_cycle[(g + (j + 1) * K) % L];
              end
            end
            cycle_count <= cycle_count + 1;
          end else begin
            state <= VERIFY;
            verify_index <= 0;
            verify_count <= 0;
          end
        end
        VERIFY: begin
          // Verify P^K == A
          if (verify_count < N) begin
            verify_temp <= verify_index;
            for (k = 0; k < K; k = k + 1) begin
              verify_temp <= P_temp[verify_temp];
            end
            if (verify_temp != A_in[verify_index]) begin
              possible <= 0;
              state <= DONE;
            end
            verify_index <= verify_index + 1;
            verify_count <= verify_count + 1;
          end else begin
            possible <= 1;
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1;
          for (i = 0; i < 8; i = i + 1) begin
            P_out[i] <= P_temp[i];
          end
        end
      endcase
    end
  end

endmodule