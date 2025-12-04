module optimal_assembler(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [7:0][2:0] symbols,
  input [7:0][7:0][15:0] time_table,
  input [7:0][7:0][2:0] result_table,
  input [3:0] seq_len,
  input [7:0][2:0] seq,
  output reg [15:0] min_time,
  output reg [2:0] result_sym,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    INIT,
    L_LOOP,
    I_LOOP,
    K_LOOP,
    STORE,
    DONE_ST
  } state_t;

  state_t current_state, next_state;
  reg [15:0] dp [0:7][0:7];
  reg [2:0] sym_tbl [0:7][0:7];
  reg [2:0] l_reg;
  reg [2:0] i_reg;
  reg [2:0] j_val;
  reg [2:0] k_reg;
  reg [15:0] current_min;
  reg [2:0] current_sym;
  reg [3:0] init_counter;
  wire [2:0] k_max = j_val - 1;

  always_comb begin
    j_val = i_reg + l_reg - 1;
  end

  wire [15:0] left_time = dp[i_reg][k_reg];
  wire [2:0] left_symbol = sym_tbl[i_reg][k_reg];
  wire [15:0] right_time = dp[k_reg+1][j_val];
  wire [2:0] right_symbol = sym_tbl[k_reg+1][j_val];
  wire [15:0] combine_time = time_table[left_symbol][right_symbol];
  wire [15:0] total_time = left_time + right_time + combine_time;
  wire [2:0] new_sym = result_table[left_symbol][right_symbol];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      min_time <= 16'b0;
      result_sym <= 3'b0;
      for (int i=0; i<8; i++) begin
        for (int j=0; j<8; j++) begin
          dp[i][j] <= 16'b0;
          sym_tbl[i][j] <= 3'b0;
        end
      end
    end
    else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_state <= INIT;
            init_counter <= 4'b0;
          end
        end

        INIT: begin
          if (init_counter < seq_len) begin
            dp[init_counter][init_counter] <= 16'b0;
            sym_tbl[init_counter][init_counter] <= seq[init_counter];
            init_counter <= init_counter + 1;
          end
          else begin
            l_reg <= 3'd2;
            current_state <= L_LOOP;
          end
        end

        L_LOOP: begin
          if (l_reg > seq_len) begin
            min_time <= dp[0][seq_len-1];
            result_sym <= sym_tbl[0][seq_len-1];
            done <= 1'b1;
            current_state <= DONE_ST;
          end
          else begin
            i_reg <= 3'b0;
            current_state <= I_LOOP;
          end
        end

        I_LOOP: begin
          if (i_reg <= seq_len - l_reg) begin
            k_reg <= i_reg;
            current_min <= 16'hFFFF;
            current_sym <= 3'b0;
            current_state <= K_LOOP;
          end
          else begin
            l_reg <= l_reg + 1;
            current_state <= L_LOOP;
          end
        end

        K_LOOP: begin
          if (total_time < current_min) begin
            current_min <= total_time;
            current_sym <= new_sym;
          end

          if (k_reg == k_max) begin
            current_state <= STORE;
          end
          else begin
            k_reg <= k_reg + 1;
          end
        end

        STORE: begin
          dp[i_reg][j_val] <= current_min;
          sym_tbl[i_reg][j_val] <= current_sym;
          i_reg <= i_reg + 1;
          current_state <= I_LOOP;
        end

        DONE_ST: begin
          done <= 1'b1;
          if (~start)
            current_state <= IDLE;
        end
      endcase
    end
  end
endmodule