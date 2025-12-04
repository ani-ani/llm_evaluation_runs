module speedrun_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [15:0] r,
  input [15:0] trick_t [0:3],
  input [31:0] trick_p [0:3],
  input [15:0] trick_d [0:3],
  input [2:0] m,
  output reg [31:0] result,
  output reg done
);

  typedef enum {IDLE, INIT, PROCESS, DONE} state_t;
  state_t current_state;

  reg [1:0] init_counter;
  reg [3:0] process_cycles_left;
  reg [31:0] expected_time_reg;
  reg [2:0] m_reg;
  reg [31:0] trick_p_reg;
  reg [15:0] trick_t_reg, trick_d_reg;
  reg process_phase;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 32'b0;
      init_counter <= 2'b0;
      process_cycles_left <= 4'b0;
      expected_time_reg <= 32'b0;
      m_reg <= 3'b0;
      process_phase <= 1'b0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_state <= INIT;
            init_counter <= 2'b0;
            expected_time_reg <= n << 16; // n to Q16.16
            m_reg <= m;
          end
        end

        INIT: begin
          if (init_counter == 2'd3) begin
            if (m_reg == 3'd0) begin
              current_state <= DONE;
              result <= n << 16;
            end else begin
              current_state <= PROCESS;
              process_cycles_left <= m_reg << 1; // 2*m
              process_phase <= 1'b0;
            end
          end else init_counter <= init_counter + 1;
        end

        PROCESS: begin
          if (process_cycles_left == 0) begin
            current_state <= DONE;
          end else begin
            process_cycles_left <= process_cycles_left - 1;
            
            if (!process_phase) begin // First cycle
              // Latch trick data (reverse order - m_reg-1 is first)
              automatic logic [1:0] idx = m_reg - 1 - ((process_cycles_left - 1) >> 1);
              trick_t_reg <= trick_t[idx];
              trick_p_reg <= trick_p[idx];
              trick_d_reg <= trick_d[idx];
              process_phase <= 1'b1;
            end else begin // Second cycle: Calculation
              automatic logic [31:0] t_shift = {16'b0, trick_t_reg} << 16;
              automatic logic [31:0] d_shift = {16'b0, trick_d_reg} << 16;
              automatic logic [63:0] success_term = trick_p_reg * (expected_time_reg - t_shift);
              automatic logic [63:0] failure_term = (32'h00010000 - trick_p_reg) * (expected_time_reg + d_shift);
              automatic logic [31:0] attempt_time = (success_term + failure_term) >> 16;
              
              if (attempt_time < expected_time_reg)
                expected_time_reg <= attempt_time;
              
              process_phase <= 1'b0;
            end
          end
        end

        DONE: begin
          result <= expected_time_reg;
          done <= 1'b1;
          current_state <= IDLE;
        end
      endcase
    end
  end
endmodule