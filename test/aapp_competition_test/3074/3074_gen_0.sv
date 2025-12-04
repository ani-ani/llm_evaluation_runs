module crypto_subset_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [3:0] digit0,
  input [3:0] digit1,
  input [3:0] digit2,
  input [3:0] digit3,
  output reg [31:0] result,
  output reg done
);

  // Local parameters
  localparam MOD = 32'h3B9ACA07; // 1000000007

  // Internal registers
  reg [31:0] count;
  reg [4:0]  cycle_cnt;
  reg        running;

  // Combinational subset evaluation
  reg [31:0] valid_count_comb;
  reg [3:0]  d0, d1, d2, d3;

  always @* begin
    // Select active digits based on N
    // d0 is most significant, d{N-1} is least significant
    case (N)
      2'd1: begin
        d0 = digit0;
        d1 = 4'd0;
        d2 = 4'd0;
        d3 = 4'd0;
      end
      2'd2: begin
        d0 = digit0;
        d1 = digit1;
        d2 = 4'd0;
        d3 = 4'd0;
      end
      2'd3: begin
        d0 = digit0;
        d1 = digit1;
        d2 = digit2;
        d3 = 4'd0;
      end
      default: begin // N >= 4 treated as 4
        d0 = digit0;
        d1 = digit1;
        d2 = digit2;
        d3 = digit3;
      end
    endcase

    valid_count_comb = 32'd0;

    // Iterate over subsets via explicit enumeration by N
    case (N)
      2'd1: begin
        // Subsets: {d0}
        if (d0 != 4'd0 && (d0 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
      end

      2'd2: begin
        // Bits: [d0 d1]
        // Subset: {d0}
        if (d0 != 4'd0 && (d0 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        // Subset: {d1}
        if (d1 != 4'd0 && (d1 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        // Subset: {d0,d1}
        if (d0 != 4'd0) begin
          if (((d0 + d1) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
      end

      2'd3: begin
        // Bits: [d0 d1 d2]
        // {d0}
        if (d0 != 4'd0 && (d0 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        // {d1}
        if (d1 != 4'd0 && (d1 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        // {d2}
        if (d2 != 4'd0 && (d2 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        // {d0,d1}
        if (d0 != 4'd0) begin
          if (((d0 + d1) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d0,d2}
        if (d0 != 4'd0) begin
          if (((d0 + d2) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d1,d2}
        if (d1 != 4'd0) begin
          if (((d1 + d2) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d0,d1,d2}
        if (d0 != 4'd0) begin
          if (((d0 + d1 + d2) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
      end

      default: begin
        // N >= 4: use 4 digits [d0 d1 d2 d3]
        // Singletons
        if (d0 != 4'd0 && (d0 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        if (d1 != 4'd0 && (d1 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        if (d2 != 4'd0 && (d2 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;
        if (d3 != 4'd0 && (d3 % 3) == 0)
          valid_count_comb = valid_count_comb + 32'd1;

        // Pairs: leading digit of subset cannot be 0
        // {d0,d1}
        if (d0 != 4'd0) begin
          if (((d0 + d1) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d0,d2}
        if (d0 != 4'd0) begin
          if (((d0 + d2) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d0,d3}
        if (d0 != 4'd0) begin
          if (((d0 + d3) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d1,d2}
        if (d1 != 4'd0) begin
          if (((d1 + d2) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d1,d3}
        if (d1 != 4'd0) begin
          if (((d1 + d3) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d2,d3}
        if (d2 != 4'd0) begin
          if (((d2 + d3) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end

        // Triples
        // {d0,d1,d2}
        if (d0 != 4'd0) begin
          if (((d0 + d1 + d2) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d0,d1,d3}
        if (d0 != 4'd0) begin
          if (((d0 + d1 + d3) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d0,d2,d3}
        if (d0 != 4'd0) begin
          if (((d0 + d2 + d3) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
        // {d1,d2,d3}
        if (d1 != 4'd0) begin
          if (((d1 + d2 + d3) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end

        // Quadruple {d0,d1,d2,d3}
        if (d0 != 4'd0) begin
          if (((d0 + d1 + d2 + d3) % 3) == 0)
            valid_count_comb = valid_count_comb + 32'd1;
        end
      end
    endcase
  end

  // Sequential control to enforce latency and modulo operation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count      <= 32'd0;
      result     <= 32'd0;
      done       <= 1'b0;
      cycle_cnt  <= 5'd0;
      running    <= 1'b0;
    end else begin
      if (start && !running) begin
        // Start new operation
        running    <= 1'b1;
        cycle_cnt  <= 5'd0;
        count      <= valid_count_comb % MOD;
        done       <= 1'b0;
      end else if (running) begin
        cycle_cnt <= cycle_cnt + 5'd1;
        if (cycle_cnt == 5'd19) begin
          // 20th cycle (0..19)
          result  <= count;
          done    <= 1'b1;
          running <= 1'b0;
        end else begin
          done <= 1'b0;
        end
      end else begin
        // Idle
        done <= 1'b0;
      end
    end
  end

endmodule