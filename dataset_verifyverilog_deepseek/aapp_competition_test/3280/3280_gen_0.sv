module show_recorder(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] k,
  input [31:0] show_times [0:15],
  output reg [2:0] count,
  output reg done
);

  typedef enum { IDLE, SORTING, ALLOCATING, DONE } state_t;
  state_t state;

  reg [2:0] n_reg;
  reg [1:0] k_reg;
  reg [31:0] show_times_sorted [0:15];
  reg [31:0] slots [0:3];
  reg [5:0] sort_cycle;
  reg [2:0] alloc_index;
  reg [2:0] count_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      count <= 0;
      count_reg <= 0;
      sort_cycle <= 0;
      alloc_index <= 0;
      n_reg <= 0;
      k_reg <= 0;
      foreach (show_times_sorted[i]) show_times_sorted[i] <= 0;
      foreach (slots[i]) slots[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          count_reg <= 0;
          if (start) begin
            n_reg <= n;
            k_reg <= k;
            foreach (show_times_sorted[i]) show_times_sorted[i] <= show_times[i];
            sort_cycle <= 0;
            state <= SORTING;
          end
        end

        SORTING: begin
          if (n_reg > 1) begin
            if (sort_cycle < (n_reg * n_reg)) begin
              automatic int j = sort_cycle % (n_reg - 1);
              if (show_times_sorted[2*j+1] > show_times_sorted[2*(j+1)+1]) begin
                automatic logic [31:0] temp_x = show_times_sorted[2*j];
                automatic logic [31:0] temp_y = show_times_sorted[2*j+1];
                show_times_sorted[2*j] <= show_times_sorted[2*(j+1)];
                show_times_sorted[2*j+1] <= show_times_sorted[2*(j+1)+1];
                show_times_sorted[2*(j+1)] <= temp_x;
                show_times_sorted[2*(j+1)+1] <= temp_y;
              end
              sort_cycle <= sort_cycle + 1;
            end else begin
              alloc_index <= 0;
              foreach (slots[i]) slots[i] <= 32'hFFFFFFFF;
              for (int i=0; i<4; i++) begin
                if (i < k_reg) slots[i] <= 0;
              end
              state <= ALLOCATING;
            end
          end else begin
            alloc_index <= 0;
            foreach (slots[i]) slots[i] <= 32'hFFFFFFFF;
            for (int i=0; i<4; i++) begin
              if (i < k_reg) slots[i] <= 0;
            end
            state <= ALLOCATING;
          end
        end

        ALLOCATING: begin
          if (alloc_index < n_reg) begin
            automatic logic [31:0] x_i = show_times_sorted[2*alloc_index];
            automatic logic [31:0] y_i = show_times_sorted[2*alloc_index+1];
            automatic logic found = 0;
            automatic logic [1:0] found_slot;
            for (int s=0; s<4; s++) begin
              if (s < k_reg && !found) begin
                if (slots[s] <= x_i) begin
                  found = 1;
                  found_slot = s;
                end
              end
            end
            if (found) begin
              slots[found_slot] <= y_i;
              count_reg <= count_reg + 1;
            end
            alloc_index <= alloc_index + 1;
          end else begin
            state <= DONE;
            done <= 1;
            count <= count_reg;
          end
        end

        DONE: begin
          state <= DONE;
        end
      endcase
    end
  end

endmodule