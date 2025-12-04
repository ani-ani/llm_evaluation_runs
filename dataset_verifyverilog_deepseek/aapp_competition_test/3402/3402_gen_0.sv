module password_recovery(
  input clk,
  input rst_n,
  input start,
  input [7:0] s_chars [0:15],
  input [7:0] t_data [0:25][0:3],
  input [2:0] K,
  input [1:0] M,
  input [11:0] positions [0:3],
  output reg [7:0] results [0:3],
  output reg done
);
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  reg [1:0] state;
  reg [2:0] K_reg;
  reg [1:0] M_reg;
  reg [7:0] s_chars_reg [0:15];
  reg [11:0] positions_reg [0:3];
  reg [11:0] pos_shift[0:3];
  reg [5:0] cycle_count;
  wire [5:0] max_cycle = {K_reg, 2'b00} + 1;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      cycle_count <= 0;
      K_reg <= 0;
      M_reg <= 0;
      foreach (positions_reg[i]) positions_reg[i] <= 0;
      foreach (pos_shift[i]) pos_shift[i] <= 0;
      foreach (s_chars_reg[i]) s_chars_reg[i] <= 0;
      foreach (results[i]) results[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            cycle_count <= 0;
            K_reg <= K;
            M_reg <= M;
            foreach (s_chars[i]) s_chars_reg[i] <= s_chars[i];
            foreach (positions[i]) begin
              positions_reg[i] <= positions[i];
              pos_shift[i] <= positions[i];
            end
          end
        end
        PROCESSING: begin
          if (cycle_count == max_cycle) begin
            done <= 1;
            state <= IDLE;
          end else begin
            cycle_count <= cycle_count + 1;
            if (cycle_count < K_reg) begin
              foreach (pos_shift[i]) pos_shift[i] <= pos_shift[i] >> 2;
            end
            if (cycle_count == K_reg) begin
              for (int i=0; i<4; i++) begin
                if (i < M_reg) results[i] <= s_chars_reg[pos_shift[i][3:0]];
              end
            end
          end
        end
      endcase
    end
  end
endmodule