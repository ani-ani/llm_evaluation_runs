module paren_grouper (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_array [0:15],
  output reg [3:0] group_start [0:3],
  output reg [3:0] group_end [0:3],
  output reg [1:0] group_count,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESSING, VALIDATE, DONE} state_t;
  state_t current_state;

  reg [3:0] position;
  reg signed [2:0] balance;
  reg [1:0] current_group;
  reg invalid_flag;
  reg [3:0] g_start_temp [0:3];
  reg [3:0] g_end_temp [0:3];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      group_count <= 2'b0;
      done <= 1'b0;
      for (int i = 0; i < 4; i++) begin
        group_start[i] <= 4'b0;
        group_end[i] <= 4'b0;
        g_start_temp[i] <= 4'b0;
        g_end_temp[i] <= 4'b0;
      end
    end
    else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_state <= PROCESSING;
            position <= 4'b0;
            balance <= 3'sb0;
            current_group <= 2'b0;
            invalid_flag <= 1'b0;
            for (int i = 0; i < 4; i++) begin
              g_start_temp[i] <= 4'b0;
              g_end_temp[i] <= 4'b0;
            end
          end
        end

        PROCESSING: begin
          if (char_array[position] != 8'h20) begin
            if (char_array[position] == 8'h28) begin  // '('
              if (balance == 3) invalid_flag <= 1'b1;  // Overflow
              balance <= balance + 1;
              if (balance == 0) begin  // Group start
                if (current_group < 4) g_start_temp[current_group] <= position;
              end
            end
            else if (char_array[position] == 8'h29) begin  // ')'
              if (balance == 0) invalid_flag <= 1'b1;  // Underflow
              balance <= balance - 1;
              if (balance == 1) begin  // Group end
                if (current_group < 4) begin
                  g_end_temp[current_group] <= position;
                  current_group <= current_group + 1;
                end
              end
            end
          end

          if (position == 4'd15 || current_group == 4) begin
            current_state <= VALIDATE;
          end
          else begin
            position <= position + 1;
          end
        end

        VALIDATE: begin
          if (invalid_flag || balance != 0) group_count <= 2'b0;
          else group_count <= current_group;

          group_start <= g_start_temp;
          group_end <= g_end_temp;
          current_state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          current_state <= IDLE;
        end
      endcase
    end
  end

endmodule