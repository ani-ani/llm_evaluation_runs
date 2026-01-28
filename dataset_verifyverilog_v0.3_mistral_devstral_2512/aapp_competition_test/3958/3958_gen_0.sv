module zebra_divider (
  input clk,
  input rst_n,
  input start,
  input [15:0] s,
  input [3:0] length,
  output reg valid,
  output reg [3:0] k,
  output reg [3:0] zebra_length [0:15],
  output reg [4:0] zebra_indices [0:15][0:15],
  output reg done
);

  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] PROCESS = 2'd1;
  localparam [1:0] DONE = 2'd2;

  reg [1:0] state;
  reg [4:0] pos;
  reg [3:0] num_zebras;
  reg [3:0] stack0 [0:15];
  reg [3:0] stack1 [0:15];
  reg [4:0] stack0_ptr;
  reg [4:0] stack1_ptr;
  reg [4:0] zebras [0:15][0:15];
  reg [4:0] zebra_length_reg [0:15];
  integer i;
  integer j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pos <= 5'd0;
      num_zebras <= 4'd0;
      stack0_ptr <= 5'd0;
      stack1_ptr <= 5'd0;
      valid <= 1'b0;
      done <= 1'b0;
      k <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        zebra_length_reg[i] <= 5'd0;
        zebra_length[i] <= 4'd0;
        for (j = 0; j < 16; j = j + 1) begin
          zebras[i][j] <= 5'd0;
          zebra_indices[i][j] <= 5'd0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS;
            pos <= 5'd0;
            num_zebras <= 4'd0;
            stack0_ptr <= 5'd0;
            stack1_ptr <= 5'd0;
            valid <= 1'b0;
            done <= 1'b0;
            k <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
              zebra_length_reg[i] <= 5'd0;
              zebra_length[i] <= 4'd0;
              for (j = 0; j < 16; j = j + 1) begin
                zebras[i][j] <= 5'd0;
                zebra_indices[i][j] <= 5'd0;
              end
            end
          end
        end

        PROCESS: begin
          if (pos < length) begin
            if (s[pos] == 1'b0) begin
              if (stack1_ptr > 0) begin
                stack1_ptr <= stack1_ptr - 5'd1;
                zebras[stack1[stack1_ptr]][zebra_length_reg[stack1[stack1_ptr]]] <= pos + 5'd1;
                zebra_length_reg[stack1[stack1_ptr]] <= zebra_length_reg[stack1[stack1_ptr]] + 5'd1;
                stack0[stack0_ptr] <= stack1[stack1_ptr];
                stack0_ptr <= stack0_ptr + 5'd1;
              end else begin
                zebras[num_zebras][0] <= pos + 5'd1;
                zebra_length_reg[num_zebras] <= 5'd1;
                stack0[stack0_ptr] <= num_zebras;
                stack0_ptr <= stack0_ptr + 5'd1;
                num_zebras <= num_zebras + 4'd1;
              end
            end else begin
              if (stack0_ptr == 0) begin
                state <= DONE;
                valid <= 1'b0;
                done <= 1'b1;
              end else begin
                stack0_ptr <= stack0_ptr - 5'd1;
                zebras[stack0[stack0_ptr]][zebra_length_reg[stack0[stack0_ptr]]] <= pos + 5'd1;
                zebra_length_reg[stack0[stack0_ptr]] <= zebra_length_reg[stack0[stack0_ptr]] + 5'd1;
                stack1[stack1_ptr] <= stack0[stack0_ptr];
                stack1_ptr <= stack1_ptr + 5'd1;
              end
            end
            pos <= pos + 5'd1;
          end else begin
            state <= DONE;
            done <= 1'b1;
            if (stack1_ptr == 0) begin
              valid <= 1'b1;
              k <= num_zebras;
              for (i = 0; i < 16; i = i + 1) begin
                zebra_length[i] <= zebra_length_reg[i];
                for (j = 0; j < 16; j = j + 1) begin
                  zebra_indices[i][j] <= zebras[i][j];
                end
              end
            end else begin
              valid <= 1'b0;
            end
          end
        end

        DONE: begin
          // Stay in done state until reset
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule