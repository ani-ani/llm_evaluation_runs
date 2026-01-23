module critical_elements (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] seq [0:7],
  output reg [7:0] critical_mask,
  output reg done,
  output reg error
);

  localparam IDLE = 3'd0, CHECK_L0 = 3'd1, CHECK_L1 = 3'd2, CHECK_L2 = 3'd3, CHECK_L3 = 3'd4, CHECK_L4 = 3'd5, CHECK_L5 = 3'd6, CHECK_L6 = 3'd7, CHECK_L7 = 3'd8, DONE = 3'd9;

  reg [3:0] state;
  reg [2:0] stored_n;
  reg [7:0] seq_reg [0:7];
  reg [3:0] stored_L0;
  reg [7:0] critical_mask_reg;
  reg done_reg;
  reg error_reg;

  function [3:0] compute_lis;
    input [7:0] seq [0:7];
    input [2:0] length;
    reg [3:0] dp [0:7];
    reg [3:0] max_len;
    integer i, j;
    max_len = 0;
    for (i=0; i<length; i=i+1) begin
      dp[i] = 1;
      for (j=0; j<i; j=j+1) begin
        if (seq[j] < seq[i] && dp[j] +1 > dp[i])
          dp[i] = dp[j] +1;
      end
      if (dp[i] > max_len) max_len = dp[i];
    end
    compute_lis = max_len;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE; stored_n <= 3'b0; seq_reg <= 8'b0; stored_L0 <= 4'b0; critical_mask_reg <= 8'b0; done_reg <= 1'b0; error_reg <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start && !error_reg && !done_reg) begin
            if (n < 2 || n > 8) begin
              error_reg <= 1'b1; done_reg <= 1'b1; state <= DONE;
            end else begin
              stored_n <= n; seq_reg <= seq; stored_L0 <= compute_lis(seq_reg, stored_n); state <= CHECK_L0;
            end
          end
        end
        CHECK_L0: begin
          if (0 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 0 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[0] <= 1'b1;
          end
          state <= CHECK_L1;
        end
        CHECK_L1: begin
          if (1 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 1 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[1] <= 1'b1;
          end
          state <= CHECK_L2;
        end
        CHECK_L2: begin
          if (2 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 2 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[2] <= 1'b1;
          end
          state <= CHECK_L3;
        end
        CHECK_L3: begin
          if (3 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 3 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[3] <= 1'b1;
          end
          state <= CHECK_L4;
        end
        CHECK_L4: begin
          if (4 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 4 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[4] <= 1'b1;
          end
          state <= CHECK_L5;
        end
        CHECK_L5: begin
          if (5 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 5 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[5] <= 1'b1;
          end
          state <= CHECK_L6;
        end
        CHECK_L6: begin
          if (6 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 6 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[6] <= 1'b1;
          end
          state <= CHECK_L7;
        end
        CHECK_L7: begin
          if (7 < stored_n) begin
            reg [7:0] modified_seq [0:7];
            for (int k=0; k<7; k=k+1) modified_seq[k] = (k < stored_n -1) ? (k < 7 ? seq_reg[k+1] : seq_reg[k]) : 8'h0;
            [3:0] li = compute_lis(modified_seq, stored_n -1);
            if (li < stored_L0) critical_mask_reg[7] <= 1'b1;
          end
          state <= DONE;
        end
        DONE: begin
          done_reg <= 1'b1; state <= DONE;
        end
      endcase
    end
  end

  assign critical_mask = critical_mask_reg; assign done = done_reg; assign error = error_reg;
endmodule