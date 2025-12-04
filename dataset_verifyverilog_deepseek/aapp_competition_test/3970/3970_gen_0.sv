module k_multiple_free(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] k,
  input [9:0] elements [0:15],
  output reg [4:0] result,
  output reg done
);

  localparam [1:0] IDLE    = 2'b00;
  localparam [1:0] SORT    = 2'b01;
  localparam [1:0] PROCESS = 2'b10;
  localparam [1:0] DONE    = 2'b11;

  reg [1:0] state;
  reg [3:0] pass_cnt;
  reg [3:0] idx;
  reg [3:0] i;
  reg [9:0] elements_sorted [0:15];
  reg [9:0] included_set [0:15];
  reg [4:0] included_ptr;

  wire [25:0] product = elements_sorted[i] * k;

  reg match;
  integer j;
  always @(*) begin
    match = 1'b0;
    for (j = 0; j < 16; j = j + 1) begin
      if (j < included_ptr) begin
        if (product == {16'b0, included_set[j]}) match = 1'b1;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 5'b0;
      pass_cnt <= 4'b0;
      idx <= 4'b0;
      i <= 4'b0;
      included_ptr <= 5'b0;
      for (int x = 0; x < 16; x = x + 1)
        elements_sorted[x] <= 10'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            for (int x = 0; x < 16; x = x + 1)
              elements_sorted[x] <= elements[x];
            state <= SORT;
            pass_cnt <= 4'b0;
            idx <= 4'b0;
          end
        end

        SORT: begin
          if (pass_cnt < 16) begin
            if (idx < 15) begin
              if (elements_sorted[idx] < elements_sorted[idx + 1]) begin
                elements_sorted[idx] <= elements_sorted[idx + 1];
                elements_sorted[idx + 1] <= elements_sorted[idx];
              end
            end
            if (idx == 15) begin
              pass_cnt <= pass_cnt + 1;
              idx <= 4'b0;
            end else begin
              idx <= idx + 1;
            end
          end else begin
            state <= PROCESS;
            i <= 4'b0;
            included_ptr <= 5'b0;
          end
        end

        PROCESS: begin
          if (i < 16) begin
            if (i < n) begin
              if (!match) begin
                included_set[included_ptr] <= elements_sorted[i];
                included_ptr <= included_ptr + 1;
              end
            end
            i <= i + 1;
          end else begin
            result <= included_ptr;
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule