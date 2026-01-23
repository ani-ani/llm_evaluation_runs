module true_false_hints (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] m,
  input [2:0] hint_l [0:19],
  input [2:0] hint_r [0:19],
  input hint_type [0:19],
  output reg [31:0] result,
  output reg done,
  output reg error
);

  parameter MOD = 1000000007;
  parameter IDLE = 3'b000;
  parameter INIT = 3'b001;
  parameter GENERATE = 3'b010;
  parameter VALIDATE = 3'b011;
  parameter DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [7:0] current_assignment = 0;
  reg [7:0] hint_index = 0;
  reg [31:0] count = 0;
  reg [7:0] i = 0;
  reg [7:0] j = 0;
  reg [7:0] k = 0;
  reg valid = 0;
  reg single_element_error = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_assignment <= 0;
      hint_index <= 0;
      count <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      valid <= 0;
      single_element_error <= 0;
      result <= 0;
      done <= 0;
      error <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            single_element_error <= 0;
            for (i = 0; i < m; i = i + 1) begin
              if (hint_type[i] && (hint_l[i] == hint_r[i])) begin
                single_element_error <= 1;
              end
            end
            if (single_element_error) begin
              error <= 1;
              done <= 1;
            end else begin
              error <= 0;
              done <= 0;
              count <= 0;
              current_assignment <= 0;
              state <= GENERATE;
            end
          end
        end
        INIT: begin
          state <= GENERATE;
        end
        GENERATE: begin
          if (current_assignment == (1 << n) - 1) begin
            state <= DONE;
            result <= count % MOD;
            done <= 1;
          end else begin
            state <= VALIDATE;
            hint_index <= 0;
            valid <= 1;
          end
        end
        VALIDATE: begin
          if (hint_index == m) begin
            if (valid) begin
              count <= count + 1;
            end
            current_assignment <= current_assignment + 1;
            state <= GENERATE;
          end else begin
            if (hint_type[hint_index]) begin
              // Different hint
              if (hint_l[hint_index] == hint_r[hint_index]) begin
                valid <= 0;
              end else begin
                reg all_equal = 1;
                for (i = hint_l[hint_index]; i <= hint_r[hint_index]; i = i + 1) begin
                  for (j = i + 1; j <= hint_r[hint_index]; j = j + 1) begin
                    if (current_assignment[i] != current_assignment[j]) begin
                      all_equal = 0;
                    end
                  end
                end
                if (all_equal) begin
                  valid <= 0;
                end
              end
            end else begin
              // Same hint
              for (i = hint_l[hint_index]; i <= hint_r[hint_index]; i = i + 1) begin
                for (j = i + 1; j <= hint_r[hint_index]; j = j + 1) begin
                  if (current_assignment[i] != current_assignment[j]) begin
                    valid <= 0;
                  end
                end
              end
            end
            hint_index <= hint_index + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule