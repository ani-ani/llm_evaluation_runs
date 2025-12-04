module sequence_counter (
  input clk,
  input rst_n,
  input start,
  input [15:0] m,
  input [3:0] n,
  output reg [15:0] result,
  output reg done
);
  
  typedef enum {IDLE, INIT, PROCESS, DONE} state_t;
  reg [15:0] T [1:16][1:15];
  reg [15:0] m_reg;
  reg [3:0] n_reg;
  reg [4:0] i_init, j_init;
  reg [4:0] i_counter;
  reg [3:0] j_counter;
  state_t state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            m_reg <= m;
            n_reg <= n;
            state <= INIT;
            i_init <= 5'd1;
            j_init <= 4'd1;
          end
        end
        
        INIT: begin
          T[i_init][j_init] <= 0;
          if (j_init == 4'd15) begin
            if (i_init == 5'd16) begin
              state <= PROCESS;
              i_counter <= 5'd1;
              j_counter <= 4'd1;
            end else begin
              i_init <= i_init + 1;
              j_init <= 4'd1;
            end
          end else begin
            j_init <= j_init + 1;
          end
        end
        
        PROCESS: begin
          if (j_counter > n_reg) begin
            state <= DONE;
          end else begin
            if (i_counter > m_reg) begin
              j_counter <= j_counter + 1;
              i_counter <= 5'd1;
            end else begin
              if (j_counter == 1) begin
                T[i_counter][j_counter] <= i_counter;
              end else if (i_counter < j_counter) begin
                T[i_counter][j_counter] <= 0;
              end else begin
                T[i_counter][j_counter] <= T[i_counter-1][j_counter] + T[i_counter>>1][j_counter-1];
              end
              i_counter <= i_counter + 1;
            end
          end
        end
        
        DONE: begin
          result <= T[m_reg][n_reg];
          done <= 1;
        end
      endcase
    end
  end
endmodule