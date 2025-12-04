module knapsack_solver(
  input clk,
  input rst_n,
  input start,
  input [2:0] jewel_count,
  input [7:0] jewel_sizes [0:7],
  input [7:0] jewel_values [0:7],
  output reg [10:0] dp_table [0:7],
  output reg done
);

  typedef enum {
    IDLE,
    INIT,
    PROCESS,
    DONE
  } state_t;

  state_t state_reg, next_state;
  reg [2:0] jewel_index_reg, next_jewel_index;
  reg [10:0] dp_table_next [0:7];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      jewel_index_reg <= 0;
      done <= 0;
      for (int i = 0; i < 8; i++) begin
        dp_table[i] <= 0;
      end
    end else begin
      state_reg <= next_state;
      jewel_index_reg <= next_jewel_index;
      done <= (next_state == DONE);

      for (int i = 0; i < 8; i++) begin
        dp_table[i] <= dp_table_next[i];
      end
    end
  end

  always_comb begin
    next_state = state_reg;
    next_jewel_index = jewel_index_reg;
    for (int i = 0; i < 8; i++)
      dp_table_next[i] = dp_table[i];

    case (state_reg)
      IDLE: begin
        if (start) next_state = INIT;
      end

      INIT: begin
        for (int i = 0; i < 8; i++)
          dp_table_next[i] = 0;
        next_state = PROCESS;
        next_jewel_index = 0;
      end

      PROCESS: begin
        if (jewel_index_reg < jewel_count) begin
          for (int w = 0; w < 8; w++) begin
            logic [7:0] s = jewel_sizes[jewel_index_reg];
            logic [7:0] v = jewel_values[jewel_index_reg];
            if (s <= (w + 1)) begin
              integer residual = (w + 1) - s;
              logic [10:0] candidate;
              if (residual > 0) begin
                int idx = residual - 1;
                candidate = (idx >= 0) ? dp_table[idx] + v : v;
              end else begin
                candidate = v;
              end
              if (candidate > dp_table[w])
                dp_table_next[w] = candidate;
            end
          end
          next_jewel_index = jewel_index_reg + 1;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        next_state = IDLE;
        next_jewel_index = 0;
      end
    endcase
  end
endmodule