module minimal_phone_calls(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [15:0] M,
  input [15:0] P0,
  input [31:0] C0,
  input [15:0] P1,
  input [31:0] C1,
  input [15:0] P2,
  input [31:0] C2,
  input [15:0] P3,
  input [31:0] C3,
  input [15:0] P4,
  input [31:0] C4,
  input [15:0] P5,
  input [31:0] C5,
  input [15:0] P6,
  input [31:0] C6,
  input [15:0] P7,
  input [31:0] C7,
  output reg [31:0] result,
  output reg done
);

  reg [15:0] P_reg [0:7];
  reg [31:0] C_reg [0:7];
  reg [3:0] N_reg;
  reg [15:0] M_reg;
  reg [15:0] P_sorted [0:7];
  reg [31:0] C_sorted [0:7];
  reg [6:0] cycle;
  reg [31:0] result_reg;
  reg start_d;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else start_d <= start;
  end
  wire start_edge = start && !start_d;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle <= 7'd0;
      done <= 1'b0;
      result <= 32'd0;
      result_reg <= 32'd0;
      P_reg[0] <= 16'd0;
      P_reg[1] <= 16'd0;
      P_reg[2] <= 16'd0;
      P_reg[3] <= 16'd0;
      P_reg[4] <= 16'd0;
      P_reg[5] <= 16'd0;
      P_reg[6] <= 16'd0;
      P_reg[7] <= 16'd0;
      C_reg[0] <= 32'd0;
      C_reg[1] <= 32'd0;
      C_reg[2] <= 32'd0;
      C_reg[3] <= 32'd0;
      C_reg[4] <= 32'd0;
      C_reg[5] <= 32'd0;
      C_reg[6] <= 32'd0;
      C_reg[7] <= 32'd0;
      for (int i=0; i<8; i=i+1) begin
        P_sorted[i] <= 16'd0;
        C_sorted[i] <= 32'd0;
      end
      N_reg <= 4'd0;
      M_reg <= 16'd0;
    end else begin
      if (start_edge) begin
        cycle <= 7'd0;
        done <= 1'b0;
        P_reg[0] <= P0;
        P_reg[1] <= P1;
        P_reg[2] <= P2;
        P_reg[3] <= P3;
        P_reg[4] <= P4;
        P_reg[5] <= P5;
        P_reg[6] <= P6;
        P_reg[7] <= P7;
        C_reg[0] <= C0;
        C_reg[1] <= C1;
        C_reg[2] <= C2;
        C_reg[3] <= C3;
        C_reg[4] <= C4;
        C_reg[5] <= C5;
        C_reg[6] <= C6;
        C_reg[7] <= C7;
        P_sorted[0] <= P0;
        P_sorted[1] <= P1;
        P_sorted[2] <= P2;
        P_sorted[3] <= P3;
        P_sorted[4] <= P4;
        P_sorted[5] <= P5;
        P_sorted[6] <= P6;
        P_sorted[7] <= P7;
        C_sorted[0] <= C0;
        C_sorted[1] <= C1;
        C_sorted[2] <= C2;
        C_sorted[3] <= C3;
        C_sorted[4] <= C4;
        C_sorted[5] <= C5;
        C_sorted[6] <= C6;
        C_sorted[7] <= C7;
        N_reg <= N;
        M_reg <= M;
        result_reg <= 32'd0;
      end else if (cycle < 7'd100) begin
        cycle <= cycle + 1;
        if (cycle < 7'd28) begin
          automatic int comp_left = cycle;
          automatic int sort_pass_i = 0;
          automatic int sort_current_j = 0;
          for (int i=0; i<7; i=i+1) begin
            automatic int comp_in_this_pass = 7 - i;
            if (comp_left < comp_in_this_pass) begin
              sort_pass_i = i;
              sort_current_j = comp_left;
              break;
            end else begin
              comp_left = comp_left - comp_in_this_pass;
            end
          end
          if ((sort_current_j < 7) && (sort_current_j+1 < N_reg) && (P_sorted[sort_current_j] > P_sorted[sort_current_j+1])) begin
            P_sorted[sort_current_j] <= P_sorted[sort_current_j+1];
            P_sorted[sort_current_j+1] <= P_sorted[sort_current_j];
            C_sorted[sort_current_j] <= C_sorted[sort_current_j+1];
            C_sorted[sort_current_j+1] <= C_sorted[sort_current_j];
          end
        end else if (cycle == 7'd28) begin
          automatic reg [31:0] max_val = 32'd0;
          for (int i=0; i<8; i=i+1) begin
            if (i < N_reg) begin
              if (C_sorted[i] > max_val) max_val = C_sorted[i];
            end
          end
          for (int i=0; i<7; i=i+1) begin
            if (i < (N_reg - 1)) begin
              automatic reg [31:0] diff = C_sorted[i+1] - C_sorted[i];
              if (diff > max_val) max_val = diff;
            end
          end
          result_reg <= max_val;
        end
      end 
      done <= (cycle == 7'd99);
      result <= (cycle >= 7'd99) ? result_reg : 32'd0;
    end
  end
endmodule
