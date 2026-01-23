module domino_coloring (
  input clk,
  input rst_n,
  input start,
  input [3:0] s1 [0:15],
  input [3:0] s2 [0:15],
  output reg [31:0] result,
  output reg done
);

  parameter MOD = 1000000007;
  parameter N = 16;
  parameter IDLE = 2'b00;
  parameter PARSE = 2'b01;
  parameter CALCULATE = 2'b10;
  parameter DONE = 2'b11;

  reg [1:0] state = IDLE;
  reg [4:0] i = 0;
  reg [31:0] ans = 0;
  reg [31:0] temp_ans = 0;
  reg [1:0] prev_type = 0;
  reg [1:0] curr_type = 0;
  reg [1:0] type_seq [0:N-1];
  reg [4:0] cycle_count = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      ans <= 0;
      temp_ans <= 0;
      prev_type <= 0;
      curr_type <= 0;
      cycle_count <= 0;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PARSE;
            i <= 0;
            cycle_count <= 0;
            done <= 0;
          end
        end
        PARSE: begin
          if (i < N) begin
            if (s1[i] == s2[i]) begin
              type_seq[i] <= 2'b00; // 'V'
            end else begin
              type_seq[i] <= 2'b01; // 'H'
            end
            i <= i + 1;
          end else begin
            state <= CALCULATE;
            i <= 0;
            if (type_seq[0] == 2'b00) begin
              temp_ans <= 3;
            end else begin
              temp_ans <= 6;
            end
            prev_type <= type_seq[0];
          end
        end
        CALCULATE: begin
          if (i < N-1) begin
            curr_type <= type_seq[i+1];
            case (prev_type)
              2'b00: begin // Prev V
                if (curr_type == 2'b00) begin // Curr V
                  temp_ans <= (temp_ans * 2) % MOD;
                end else begin // Curr H
                  temp_ans <= (temp_ans * 2) % MOD;
                end
              end
              2'b01: begin // Prev H
                if (curr_type == 2'b00) begin // Curr V
                  temp_ans <= (temp_ans * 1) % MOD;
                end else begin // Curr H
                  temp_ans <= (temp_ans * 3) % MOD;
                end
              end
            endcase
            prev_type <= curr_type;
            i <= i + 1;
          end else begin
            state <= DONE;
            ans <= temp_ans;
          end
        end
        DONE: begin
          if (cycle_count < 20) begin
            cycle_count <= cycle_count + 1;
          end else begin
            done <= 1;
            result <= ans;
          end
        end
      endcase
    end
  end

endmodule