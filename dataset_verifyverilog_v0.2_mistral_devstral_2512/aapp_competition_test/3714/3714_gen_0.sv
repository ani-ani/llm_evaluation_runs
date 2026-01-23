module crush_game (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] crush [15:0],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT,
    CHECK_CYCLES,
    COMPUTE_LCM,
    DONE
  } state_t;

  state_t state;
  reg [3:0] current_node;
  reg [3:0] step_count;
  reg [3:0] cycle_lengths [15:0];
  reg [3:0] adjusted_lengths [15:0];
  reg [3:0] valid_cycles [15:0];
  reg [3:0] lcm_result;
  reg [3:0] node_index;
  reg [3:0] cycle_index;
  reg [3:0] temp_gcd;
  reg [3:0] temp_lcm;
  reg [3:0] counter;

  // GCD calculation function
  function [3:0] gcd;
    input [3:0] a;
    input [3:0] b;
    reg [3:0] x;
    reg [3:0] y;
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
      gcd = x;
    end
  endfunction

  // LCM calculation function
  function [3:0] lcm;
    input [3:0] a;
    input [3:0] b;
    begin
      if (a == 0 || b == 0) begin
        lcm = 0;
      end else begin
        lcm = (a * b) / gcd(a, b);
      end
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'hFFFFFFFF;
      done <= 1'b0;
      current_node <= 4'd0;
      step_count <= 4'd0;
      node_index <= 4'd0;
      cycle_index <= 4'd0;
      counter <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            result <= 32'hFFFFFFFF;
            done <= 1'b0;
          end
        end

        INIT: begin
          // Initialize all cycle tracking registers
          for (int i = 0; i < 16; i = i + 1) begin
            cycle_lengths[i] <= 4'd0;
            adjusted_lengths[i] <= 4'd0;
            valid_cycles[i] <= 4'd0;
          end
          node_index <= 4'd0;
          state <= CHECK_CYCLES;
        end

        CHECK_CYCLES: begin
          if (node_index < n) begin
            current_node <= node_index;
            step_count <= 4'd0;
            // Start checking cycle for current node
            state <= CHECK_CYCLES;
          end else begin
            // All nodes checked, proceed to LCM computation
            state <= COMPUTE_LCM;
            lcm_result <= 4'd1;
            cycle_index <= 4'd0;
          end
        end

        COMPUTE_LCM: begin
          if (cycle_index < n) begin
            if (valid_cycles[cycle_index]) begin
              temp_lcm <= lcm(lcm_result, adjusted_lengths[cycle_index]);
              lcm_result <= temp_lcm;
            end
            cycle_index <= cycle_index + 1'b1;
          end else begin
            if (lcm_result == 4'd0) begin
              result <= 32'hFFFFFFFF; // -1 in 32-bit
            end else begin
              result <= lcm_result;
            end
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Cycle checking logic
  always @(posedge clk) begin
    if (state == CHECK_CYCLES && node_index < n) begin
      if (step_count < n) begin
        current_node <= crush[current_node];
        step_count <= step_count + 1'b1;
        // Check if we've returned to the starting node
        if (current_node == node_index) begin
          cycle_lengths[node_index] <= step_count;
          // Adjust cycle length
          if (step_count % 2 == 0) begin
            adjusted_lengths[node_index] <= step_count / 2;
          end else begin
            adjusted_lengths[node_index] <= step_count;
          end
          valid_cycles[node_index] <= 1'b1;
          node_index <= node_index + 1'b1;
        end
      end else begin
        // No cycle found within n steps
        valid_cycles[node_index] <= 1'b0;
        node_index <= node_index + 1'b1;
      end
    end
  end

  // Counter for latency requirement
  always @(posedge clk) begin
    if (state == INIT) begin
      counter <= 4'd0;
    end else if (state != IDLE && state != DONE) begin
      if (counter < 256) begin
        counter <= counter + 1'b1;
      end
    end
  end

endmodule