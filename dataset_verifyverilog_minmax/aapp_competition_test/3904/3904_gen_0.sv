module bracket_correction(
  input clk,
  input rst_n,
  input start,
  input [3:0] seq_len,
  input [15:0] bracket_seq,
  output reg [4:0] result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam CHECK = 2'b01;
  localparam PROCESS = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state;
  reg [3:0] seq_len_reg;
  reg [15:0] bracket_seq_reg;
  reg is_valid;
  reg [4:0] i;
  reg signed [4:0] bal;
  reg [4:0] total_time;
  reg in_bad;

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 5'b0;
      i <= 5'b0;
      bal <= 5'b0;
      total_time <= 5'b0;
      in_bad <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            seq_len_reg <= seq_len;
            bracket_seq_reg <= bracket_seq;
            state <= CHECK;
          end
        end

        CHECK: begin
          reg [4:0] count;
          integer j;
          count = 0;
          for (j = 0; j < seq_len_reg; j = j+1) begin
            if (bracket_seq_reg[j]) 
              count = count + 1;
          end
          if (seq_len_reg[0] == 1) begin
            is_valid <= 1'b0;
          end else begin
            if (count == (seq_len_reg >> 1))
              is_valid <= 1'b1;
            else
              is_valid <= 1'b0;
          end
          state <= is_valid ? PROCESS : DONE;
        end

        PROCESS: begin
          if (i == 0) begin
            bal <= 0;
            total_time <= 0;
            in_bad <= 0;
          end
          
          if (i < seq_len_reg) begin
            if (bracket_seq_reg[i]) 
              bal <= bal + 1;
            else 
              bal <= bal - 1;
            
            if (bal < 0) 
              in_bad <= 1;
            else 
              in_bad <= 0;
            
            if (in_bad) 
              total_time <= total_time + 1;
            
            i <= i + 1;
            
            if (i + 1 == seq_len_reg) begin
              state <= DONE;
            end
          end
        end

        DONE: begin
          if (state == CHECK) begin
            // This condition should not occur, but included for safety
            result <= 5'b11111;
            done <= 1'b1;
          end else begin
            if (is_valid) 
              result <= total_time;
            else 
              result <= 5'b11111;
            done <= 1'b1;
          end
          state <= IDLE;
        end
      endcase
    end
  end

endmodule