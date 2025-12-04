module frog_escape(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_frogs,
  input [15:0] pit_depth,
  input [15:0] l_data [0:7],
  input [15:0] w_data [0:7],
  input [15:0] h_data [0:7],
  output reg [3:0] escaped_count,
  output reg done
);

  typedef enum logic [1:0] {IDLE, SORT, PROCESS, DONE} state_t;
  state_t state;

  reg [15:0] l_sorted [0:7];
  reg [15:0] w_sorted [0:7];
  reg [15:0] h_sorted [0:7];
  reg [3:0] i_reg;
  reg [3:0] j_reg;
  reg [2:0] current_frog;
  reg [15:0] carry_weight;
  reg [15:0] h_stack;
  reg [3:0] count_reg;
  reg [5:0] cycle_cnt;
  wire [3:0] num_frogs_4b = {1'b0, num_frogs};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      foreach(l_sorted[i]) begin
        l_sorted[i] <= 16'b0;
        w_sorted[i] <= 16'b0;
        h_sorted[i] <= 16'b0;
      end
      i_reg <= 4'b0;
      j_reg <= 4'b0;
      current_frog <= 3'b0;
      carry_weight <= 16'b0;
      h_stack <= 16'b0;
      count_reg <= 4'b0;
      cycle_cnt <= 6'b0;
      escaped_count <= 4'b0;
      done <= 1'b0;
    end else begin
      done <= (cycle_cnt == 40);
      case (state)
        IDLE: begin
          count_reg <= 4'b0;
          carry_weight <= 16'b0;
          h_stack <= 16'b0;
          current_frog <= 3'b0;
          cycle_cnt <= 6'b0;
          if (start) begin
            foreach(l_sorted[i]) begin
              l_sorted[i] <= l_data[i];
              w_sorted[i] <= w_data[i];
              h_sorted[i] <= h_data[i];
            end
            state <= SORT;
            i_reg <= 4'b0;
            j_reg <= 4'b0;
          end
        end

        SORT: begin
          cycle_cnt <= cycle_cnt + 1;
          if (i_reg < num_frogs_4b - 1) begin
            if (j_reg < num_frogs_4b - i_reg - 1) begin
              if (w_sorted[j_reg] > w_sorted[j_reg+1]) begin
                // Swap elements
                automatic logic [15:0] l_tmp = l_sorted[j_reg];
                automatic logic [15:0] w_tmp = w_sorted[j_reg];
                automatic logic [15:0] h_tmp = h_sorted[j_reg];
                l_sorted[j_reg] <= l_sorted[j_reg+1];
                w_sorted[j_reg] <= w_sorted[j_reg+1];
                h_sorted[j_reg] <= h_sorted[j_reg+1];
                l_sorted[j_reg+1] <= l_tmp;
                w_sorted[j_reg+1] <= w_tmp;
                h_sorted[j_reg+1] <= h_tmp;
              end
              j_reg <= j_reg + 1;
            end else begin
              i_reg <= i_reg + 1;
              j_reg <= 0;
            end
          end else begin
            state <= PROCESS;
          end
        end

        PROCESS: begin
          cycle_cnt <= cycle_cnt + 1;
          if (current_frog < num_frogs) begin
            if (w_sorted[current_frog] > carry_weight) begin
              if ((h_stack + l_sorted[current_frog]) > pit_depth) begin
                count_reg <= count_reg + 1;
              end else begin
                h_stack <= h_stack + h_sorted[current_frog];
                carry_weight <= carry_weight + w_sorted[current_frog];
              end
            end
            current_frog <= current_frog + 1;
          end else begin
            escaped_count <= count_reg;
            state <= DONE;
          end
        end

        DONE: begin
          if (cycle_cnt < 40) cycle_cnt <= cycle_cnt + 1;
        end
      endcase
    end
  end
endmodule