module smart_sort #(
  parameter MAX_ELEMENTS = 8,
  parameter DATA_WIDTH   = 8,
  parameter CYCLES_MAX   = 50
) (
  input clk,
  input rst_n,
  input start,
  input [DATA_WIDTH-1:0] array_in [0:MAX_ELEMENTS-1],
  input [$clog2(MAX_ELEMENTS+1)-1:0] num_elements,
  output reg [DATA_WIDTH-1:0] sorted_array [0:MAX_ELEMENTS-1],
  output reg done
);

  localparam STATE_IDLE = 2'b00;
  localparam STATE_RUN  = 2'b01;
  localparam STATE_DONE = 2'b10;

  function integer clogb2 (input integer v);
    begin
      clogb2 = 0;
      while ((1 << clogb2) < v) clogb2 = clogb2 + 1;
    end
  endfunction

  reg [1:0] state;
  reg [clogb2(CYCLES_MAX+1)-1:0] cycle_cnt;
  reg [DATA_WIDTH-1:0] internal [0:MAX_ELEMENTS-1];
  reg [3:0] i; // up to 8
  reg [3:0] j; // up to 7
  reg [3:0] n;
  reg sum;
  reg [DATA_WIDTH:0] tmp_sum;
  reg [3:0] num_elements_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      cycle_cnt <= '0;
      done <= 1'b0;
      for (int k = 0; k < MAX_ELEMENTS; k++) begin
        sorted_array[k] <= 8'h0;
        internal[k]     <= 8'h0;
      end
      i <= 4'd0;
      j <= 4'd0;
      n <= 4'd0;
      sum <= 1'b0;
      num_elements_reg <= 4'd0;
    end else begin
      case (state)
        STATE_IDLE: begin
          done <= 1'b0;
          for (int k = 0; k < MAX_ELEMENTS; k++) begin
            sorted_array[k] <= 8'h0;
            internal[k]     <= 8'h0;
          end
          if (start) begin
            num_elements_reg <= num_elements;
            n <= (num_elements >= 1 && num_elements <= 8) ? num_elements : 1;
            for (int k = 0; k < MAX_ELEMENTS; k++) begin
              if (k < num_elements) internal[k] <= array_in[k];
              else                  internal[k] <= 8'h0;
            end
            tmp_sum = {1'b0, array_in[0]} + {1'b0, array_in[num_elements - 1]};
            sum <= tmp_sum[0];
            i   <= 4'd0;
            j   <= 4'd0;
            cycle_cnt <= '0;
            state <= STATE_RUN;
          end else begin
            state <= STATE_IDLE;
          end
        end

        STATE_RUN: begin
          cycle_cnt <= cycle_cnt + 1;
          if (i < n - 1) begin
            if (j < n - 1 - i) begin
              if (sum) begin
                if (internal[j] > internal[j+1]) begin
                  internal[j]   <= internal[j+1];
                  internal[j+1] <= internal[j];
                end
              end else begin
                if (internal[j] < internal[j+1]) begin
                  internal[j]   <= internal[j+1];
                  internal[j+1] <= internal[j];
                end
              end
              j <= j + 1;
            end else begin
              j <= 0;
              i <= i + 1;
            end
          end else begin
            for (int k = 0; k < MAX_ELEMENTS; k++) begin
              if (k < n) sorted_array[k] <= internal[k];
              else      sorted_array[k] <= 8'h0;
            end
            done  <= 1'b1;
            state <= STATE_DONE;
          end
        end

        STATE_DONE: begin
          done <= 1'b1;
          for (int k = 0; k < MAX_ELEMENTS; k++) begin
            if (k < n) sorted_array[k] <= internal[k];
            else      sorted_array[k] <= 8'h0;
          end
          if (!start) state <= STATE_IDLE;
        end
      endcase
    end
  end
endmodule

module tb_sort();
  reg clk;
  reg rst_n;
  reg start;
  reg [7:0] array_in [0:7];
  reg [2:0] num_elements;
  wire [7:0] sorted_array [0:7];
  wire done;

  reg [31:0] test_idx;
  integer mismatches;
  reg [7:0] exp_sorted [0:7];
  reg [7:0] exp_sorted_desc [0:7];
  reg [7:0] sorted_copy [0:7];
  reg [7:0] tmp;
  integer i, j, k;
  reg [7:0] sum;
  reg [7:0] sorted_by_sum;
  reg [7:0] ref [0:7];

  smart_sort dut (.*);

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_sort);

    rst_n = 0;
    start = 0;
    for (i = 0; i < 8; i++) array_in[i] = 0;
    num_elements = 0;

    repeat (3) @(posedge clk);
    rst_n = 1;

    test_idx = 0;
    for (i = 1; i <= 8; i++) begin
      for (j = 0; j < 200; j++) begin
        for (k = 0; k < 8; k++) array_in[k] = $random;
        num_elements = i;
        start = 1;
        @(posedge clk);
        start = 0;
        wait (done);
        @(posedge clk);
        check_result(i, array_in, num_elements, sorted_array, done);
        repeat (3) @(posedge clk);
      end
    end

    $display("All tests passed.");
    $finish;
  end

  task automatic check_result(
    input [3:0] n,
    input [7:0] arr [0:7],
    input [2:0] ne,
    input [7:0] out_arr [0:7],
    input done_sig
  );
    begin
      sum = arr[0] + arr[ne - 1];
      for (int ii = 0; ii < 8; ii++) ref[ii] = (ii < ne) ? arr[ii] : 8'h0;
      sorted_by_sum = sum[0] ? 1 : 0;

      for (int ii = 0; ii < ne; ii++) exp_sorted[ii] = ref[ii];
      for (int ii = 0; ii < ne; ii++) exp_sorted_desc[ii] = ref[ii];
      bubble_sort_asc(exp_sorted, ne);
      bubble_sort_desc(exp_sorted_desc, ne);

      if (sorted_by_sum) for (int ii = 0; ii < ne; ii++) ref[ii] = exp_sorted[ii];
      else               for (int ii = 0; ii < ne; ii++) ref[ii] = exp_sorted_desc[ii];

      mismatches = 0;
      for (int ii = 0; ii < ne; ii++) if (out_arr[ii] !== ref[ii]) mismatches++;
      for (int ii = ne; ii < 8; ii++)  if (out_arr[ii] !== 8'h0)   mismatches++;
      if (mismatches !== 0 || !done_sig) begin
        $display("FAIL at test %0d, n=%0d, sum=%0h (order=%s)", test_idx, ne, sum, sorted_by_sum ? "ASC" : "DESC");
        $display("  Input:  %p", arr);
        $display("  Expect: %p (first %0d valid)", ref, ne);
        $display("  Got:    %p", out_arr);
        $display("  done=%0b", done_sig);
        $finish;
      end
      test_idx++;
    end
  endtask

  task automatic bubble_sort_asc(input [7:0] arr [0:7], input [3:0] n);
    for (int p = 0; p < n - 1; p++) begin
      for (int q = 0; q < n - 1 - p; q++) begin
        if (arr[q] > arr[q+1]) begin
          tmp = arr[q];
          arr[q]   = arr[q+1];
          arr[q+1] = tmp;
        end
      end
    end
  endtask

  task automatic bubble_sort_desc(input [7:0] arr [0:7], input [3:0] n);
    for (int p = 0; p < n - 1; p++) begin
      for (int q = 0; q < n - 1 - p; q++) begin
        if (arr[q] < arr[q+1]) begin
          tmp = arr[q];
          arr[q]   = arr[q+1];
          arr[q+1] = tmp;
        end
      end
    end
  endtask
endmodule