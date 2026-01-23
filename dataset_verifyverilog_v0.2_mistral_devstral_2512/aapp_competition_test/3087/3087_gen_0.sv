module dance_arrows (
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [31:0] K,
  input [4:0] a [0:15],
  output reg [4:0] result [0:15],
  output reg done,
  output reg impossible
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD = 3'b001;
  localparam [2:0] FIND_CYCLES = 3'b010;
  localparam [2:0] COMPUTE_ROOT = 3'b011;
  localparam [2:0] VERIFY = 3'b100;
  localparam [2:0] DONE = 3'b101;

  reg [2:0] state = IDLE;
  reg [3:0] cycle_count = 0;
  reg [3:0] current_cycle_length = 0;
  reg [3:0] current_cycle_pos = 0;
  reg [3:0] current_element = 0;
  reg [3:0] temp_cycle [0:15];
  reg [3:0] cycle_start [0:15];
  reg [3:0] cycle_length [0:15];
  reg [3:0] visited [0:15];
  reg [3:0] gcd_val = 0;
  reg [3:0] mod_result = 0;
  reg [3:0] split_count = 0;
  reg [3:0] split_pos = 0;
  reg [3:0] verify_pos = 0;
  reg [3:0] verify_count = 0;
  reg [3:0] counter = 0;

  // GCD lookup table for small numbers (1-16)
  reg [3:0] gcd_table [0:15][0:15];
  integer i, j;

  initial begin
    // Initialize GCD table
    for (i = 1; i <= 15; i = i + 1) begin
      for (j = 1; j <= 15; j = j + 1) begin
        gcd_table[i][j] = gcd_calc(i, j);
      end
    end
  end

  function [3:0] gcd_calc;
    input [3:0] a, b;
    reg [3:0] x, y;
    begin
      x = a;
      y = b;
      while (y != 0) begin
        if (x > y) begin
          x = x - y;
        end else begin
          y = y - x;
        end
      end
      gcd_calc = x;
    end
  endfunction

  function [3:0] mod_calc;
    input [3:0] a;
    input [31:0] b;
    reg [3:0] x;
    begin
      x = a;
      while (x > b) begin
        x = x - b;
      end
      mod_calc = x;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      counter <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        result[i] <= 0;
        visited[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            counter <= 0;
            done <= 0;
            impossible <= 0;
            for (i = 0; i < 16; i = i + 1) begin
              visited[i] <= 0;
            end
          end
        end

        LOAD: begin
          if (counter == 0) begin
            // Check for self-mapping
            for (i = 0; i < N; i = i + 1) begin
              if (a[i] == i) begin
                impossible <= 1;
                state <= DONE;
              end
            end
            if (!impossible) begin
              state <= FIND_CYCLES;
              cycle_count <= 0;
              current_element <= 0;
            end
          end
          counter <= counter + 1;
        end

        FIND_CYCLES: begin
          if (current_element < N && !visited[current_element]) begin
            // Start new cycle
            temp_cycle[0] <= current_element;
            visited[current_element] <= 1;
            current_cycle_pos <= 1;
            current_cycle_length <= 1;
            state <= FIND_CYCLES;
          end else if (current_cycle_pos > 0 && current_cycle_pos < 16) begin
            // Continue current cycle
            current_element <= a[temp_cycle[current_cycle_pos - 1]];
            if (!visited[current_element]) begin
              temp_cycle[current_cycle_pos] <= current_element;
              visited[current_element] <= 1;
              current_cycle_pos <= current_cycle_pos + 1;
              current_cycle_length <= current_cycle_length + 1;
            end else begin
              // Cycle complete
              cycle_start[cycle_count] <= temp_cycle[0];
              cycle_length[cycle_count] <= current_cycle_length;
              cycle_count <= cycle_count + 1;
              current_cycle_pos <= 0;
              current_element <= current_element + 1;
            end
          end else if (current_element >= N) begin
            // All cycles found
            state <= COMPUTE_ROOT;
            current_cycle_pos <= 0;
          end else begin
            current_element <= current_element + 1;
          end
        end

        COMPUTE_ROOT: begin
          if (current_cycle_pos < cycle_count) begin
            current_cycle_length <= cycle_length[current_cycle_pos];
            gcd_val <= gcd_table[current_cycle_length][K[3:0]];
            mod_result <= mod_calc(current_cycle_length, K);

            if (gcd_val == 1) begin
              // Simple case: single cycle
              for (i = 0; i < current_cycle_length; i = i + 1) begin
                result[temp_cycle[i]] <= temp_cycle[(i + mod_result) % current_cycle_length];
              end
            end else begin
              // Split into gcd_val cycles
              split_count <= 0;
              split_pos <= 0;
              while (split_count < gcd_val) begin
                for (i = 0; i < current_cycle_length / gcd_val; i = i + 1) begin
                  result[temp_cycle[split_pos]] <= temp_cycle[(split_pos + mod_result) % current_cycle_length];
                  split_pos <= (split_pos + 1) % current_cycle_length;
                end
                split_count <= split_count + 1;
              end
            end
            current_cycle_pos <= current_cycle_pos + 1;
          end else begin
            state <= VERIFY;
            verify_pos <= 0;
            verify_count <= 0;
          end
        end

        VERIFY: begin
          if (verify_count < K) begin
            if (verify_pos < N) begin
              // Apply permutation once
              temp_cycle[verify_pos] <= result[verify_pos];
              verify_pos <= verify_pos + 1;
            end else begin
              // Copy back for next iteration
              for (i = 0; i < N; i = i + 1) begin
                result[i] <= temp_cycle[i];
              end
              verify_pos <= 0;
              verify_count <= verify_count + 1;
            end
          end else begin
            // Verify result
            for (i = 0; i < N; i = i + 1) begin
              if (result[i] != a[i]) begin
                impossible <= 1;
                break;
              end
            end
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule