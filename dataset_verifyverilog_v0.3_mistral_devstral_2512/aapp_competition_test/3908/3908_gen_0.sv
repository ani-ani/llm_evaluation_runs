module secret_message (
  input clk,
  input rst_n,
  input start,
  input [4:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
  input [4:0] arr_8, arr_9, arr_10, arr_11, arr_12, arr_13, arr_14, arr_15,
  input [3:0] len,
  output reg [7:0] result,
  output reg done
);

  // States
  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] PROCESS_CHAR = 3'd1;
  localparam [2:0] UPDATE_E = 3'd2;
  localparam [2:0] UPDATE_HIST = 3'd3;
  localparam [2:0] UPDATE_MAX_START = 3'd4;
  localparam [2:0] UPDATE_MAX_HIST = 3'd5;
  localparam [2:0] UPDATE_MAX_E = 3'd6;
  localparam [2:0] UPDATE_RESULT = 3'd7;

  // Internal registers
  reg [2:0] state;
  reg [3:0] index;
  reg [4:0] k;
  reg [4:0] current_char_reg;
  reg [7:0] hist [0:25];
  reg [7:0] e [0:25][0:25];
  reg [7:0] max_d;
  reg [7:0] max_e;
  reg [4:0] i;
  reg [4:0] j;
  reg [5:0] idx_hist;

  // Combinational current character selection
  wire [4:0] current_char;
  assign current_char = 
    (index ==  0) ? arr_0  :
    (index ==  1) ? arr_1  :
    (index ==  2) ? arr_2  :
    (index ==  3) ? arr_3  :
    (index ==  4) ? arr_4  :
    (index ==  5) ? arr_5  :
    (index ==  6) ? arr_6  :
    (index ==  7) ? arr_7  :
    (index ==  8) ? arr_8  :
    (index ==  9) ? arr_9  :
    (index == 10) ? arr_10 :
    (index == 11) ? arr_11 :
    (index == 12) ? arr_12 :
    (index == 13) ? arr_13 :
    (index == 14) ? arr_14 :
    (index == 15) ? arr_15 : 5'b0;

  // State machine and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 8'd0;
      index <= 4'd0;
      k <= 5'd0;
      current_char_reg <= 5'd0;
      max_d <= 8'd0;
      max_e <= 8'd0;
      i <= 5'd0;
      j <= 5'd0;
      idx_hist <= 6'd0;
      for (integer idx = 0; idx < 26; idx = idx + 1) begin
        hist[idx] <= 8'd0;
        for (integer jdx = 0; jdx < 26; jdx = jdx + 1) begin
          e[idx][jdx] <= 8'd0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= PROCESS_CHAR;
            index <= 4'd0;
            k <= 5'd0;
          end
        end

        PROCESS_CHAR: begin
          if (index < len) begin
            current_char_reg <= current_char;
            state <= UPDATE_E;
            k <= 5'd0;
          end else begin
            state <= UPDATE_MAX_START;
          end
        end

        UPDATE_E: begin
          e[k][current_char_reg] <= e[k][current_char_reg] + hist[k];
          k <= k + 1'b1;
          if (k == 5'd25) begin
            state <= UPDATE_HIST;
          end
        end

        UPDATE_HIST: begin
          hist[current_char_reg] <= hist[current_char_reg] + 8'd1;
          index <= index + 1'b1;
          state <= PROCESS_CHAR;
        end

        UPDATE_MAX_START: begin
          max_d <= 8'd0;
          max_e <= 8'd0;
          idx_hist <= 6'd0;
          state <= UPDATE_MAX_HIST;
        end

        UPDATE_MAX_HIST: begin
          if (idx_hist < 6'd26) begin
            if (hist[idx_hist] > max_d) begin
              max_d <= hist[idx_hist];
            end
            idx_hist <= idx_hist + 1'b1;
          end else begin
            i <= 5'd0;
            j <= 5'd0;
            state <= UPDATE_MAX_E;
          end
        end

        UPDATE_MAX_E: begin
          if (i < 5'd26) begin
            if (j < 5'd26) begin
              if (e[i][j] > max_e) begin
                max_e <= e[i][j];
              end
              j <= j + 1'b1;
            end else begin
              j <= 5'd0;
              i <= i + 1'b1;
            end
          end else begin
            state <= UPDATE_RESULT;
          end
        end

        UPDATE_RESULT: begin
          result <= (max_d > max_e) ? max_d : max_e;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule