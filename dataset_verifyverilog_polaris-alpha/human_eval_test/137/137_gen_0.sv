module compare_numbers (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [39:0] a_str,
  input  logic [39:0] b_str,
  input  logic [1:0]  a_type,
  input  logic [1:0]  b_type,
  output logic [39:0] result_str,
  output logic [1:0]  result_type,
  output logic        done,
  output logic        none
);

  // Q8.8 fixed-point values (signed)
  logic signed [15:0] a_val_s1, b_val_s1;
  logic signed [15:0] a_val_s2, b_val_s2;
  logic signed [15:0] a_val_s3, b_val_s3;

  logic [39:0] a_str_s1, b_str_s1;
  logic [39:0] a_str_s2, b_str_s2;
  logic [39:0] a_str_s3, b_str_s3;
  logic [39:0] a_str_s4, b_str_s4;

  logic [1:0] a_type_s1, b_type_s1;
  logic [1:0] a_type_s2, b_type_s2;
  logic [1:0] a_type_s3, b_type_s3;
  logic [1:0] a_type_s4, b_type_s4;

  logic       start_s1, start_s2, start_s3, start_s4, start_s5;

  // ------------------------------------------------------------
  // Helper: ASCII digit check
  // ------------------------------------------------------------
  function automatic logic is_digit(input logic [7:0] c);
    return (c >= "0" && c <= "9");
  endfunction

  // ------------------------------------------------------------
  // Helper: parse 40-bit ASCII string into Q8.8
  // Requirements:
  //  - Max 3-digit integer, 2-digit fraction
  //  - Support optional leading '-'
  //  - Replace ',' with '.'
  //  - Invalid => zero
  //  - Q8.8 signed two's complement
  // ------------------------------------------------------------
  function automatic logic signed [15:0] parse_q8_8(input logic [39:0] str);
    // Interpret as 5 bytes: [39:32]=char4, [31:24]=char3, [23:16]=char2, [15:8]=char1, [7:0]=char0
    logic [7:0] c0, c1, c2, c3, c4;
    logic       neg;
    int         idx;
    logic [3:0] int_cnt;
    logic [2:0] frac_cnt;
    int         int_val;
    int         frac_val;
    logic       seen_dot;
    logic       invalid;
    logic [7:0] ch;
    int         tmp;
    logic signed [15:0] q;

    begin
      c4 = str[39:32];
      c3 = str[31:24];
      c2 = str[23:16];
      c1 = str[15:8];
      c0 = str[7:0];

      neg       = 1'b0;
      int_cnt   = '0;
      frac_cnt  = '0;
      int_val   = 0;
      frac_val  = 0;
      seen_dot  = 1'b0;
      invalid   = 1'b0;

      // Process characters from MSB to LSB
      for (idx = 4; idx >= 0; idx--) begin
        unique case (idx)
          4: ch = c4;
          3: ch = c3;
          2: ch = c2;
          1: ch = c1;
          default: ch = c0;
        endcase

        if (ch == 8'h20 || ch == 8'h00) begin
          // space or NUL => ignore
        end
        else if (ch == "-" && int_cnt == 0 && !seen_dot && !neg && frac_cnt == 0) begin
          neg = 1'b1;
        end
        else if (ch == "," || ch == ".") begin
          if (seen_dot) begin
            invalid = 1'b1;
          end else begin
            seen_dot = 1'b1;
          end
        end
        else if (is_digit(ch)) begin
          if (!seen_dot) begin
            if (int_cnt == 3) begin
              invalid = 1'b1;
            end else begin
              int_val = int_val * 10 + (ch - "0");
              int_cnt = int_cnt + 1;
            end
          end else begin
            if (frac_cnt == 2) begin
              // more than 2 fractional digits => invalid per spec
              invalid = 1'b1;
            end else begin
              frac_val = frac_val * 10 + (ch - "0");
              frac_cnt = frac_cnt + 1;
            end
          end
        end
        else begin
          invalid = 1'b1;
        end
      end

      if (invalid) begin
        q = 16'sd0;
      end else begin
        // Compute Q8.8: (int_val + frac_val/100) * 256
        // Limit range implicitly by signed 16-bit
        tmp = int_val * 256;
        // scale fraction: frac_val (0..99) * 256 / 100 with rounding
        tmp = tmp + ((frac_val * 256 + 50) / 100);
        if (neg) tmp = -tmp;
        // Truncate to 16-bit signed
        q = $signed(tmp[15:0]);
      end
      return q;
    end
  endfunction

  // ------------------------------------------------------------
  // Stage 1: latch inputs
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_s1  <= 1'b0;
      a_str_s1  <= '0;
      b_str_s1  <= '0;
      a_type_s1 <= 2'b0;
      b_type_s1 <= 2'b0;
    end else begin
      start_s1  <= start;
      a_str_s1  <= a_str;
      b_str_s1  <= b_str;
      a_type_s1 <= a_type;
      b_type_s1 <= b_type;
    end
  end

  // ------------------------------------------------------------
  // Stage 2: parse to Q8.8 (combinational from S1, registered to S2)
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_s2  <= 1'b0;
      a_val_s2  <= '0;
      b_val_s2  <= '0;
      a_str_s2  <= '0;
      b_str_s2  <= '0;
      a_type_s2 <= 2'b0;
      b_type_s2 <= 2'b0;
    end else begin
      start_s2  <= start_s1;
      a_val_s2  <= parse_q8_8(a_str_s1);
      b_val_s2  <= parse_q8_8(b_str_s1);
      a_str_s2  <= a_str_s1;
      b_str_s2  <= b_str_s1;
      a_type_s2 <= a_type_s1;
      b_type_s2 <= b_type_s1;
    end
  end

  // ------------------------------------------------------------
  // Stage 3: pipeline forward
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_s3  <= 1'b0;
      a_val_s3  <= '0;
      b_val_s3  <= '0;
      a_str_s3  <= '0;
      b_str_s3  <= '0;
      a_type_s3 <= 2'b0;
      b_type_s3 <= 2'b0;
    end else begin
      start_s3  <= start_s2;
      a_val_s3  <= a_val_s2;
      b_val_s3  <= b_val_s2;
      a_str_s3  <= a_str_s2;
      b_str_s3  <= b_str_s2;
      a_type_s3 <= a_type_s2;
      b_type_s3 <= b_type_s2;
    end
  end

  // ------------------------------------------------------------
  // Stage 4: compare values, select result (registered)
  // ------------------------------------------------------------
  logic [39:0] result_str_s4;
  logic [1:0]  result_type_s4;
  logic        none_s4;

  always_comb begin
    // default
    result_str_s4  = 40'b0;
    result_type_s4 = 2'b0;
    none_s4        = 1'b0;

    if (a_val_s3 > b_val_s3) begin
      result_str_s4  = a_str_s3;
      result_type_s4 = a_type_s3;
      none_s4        = 1'b0;
    end else if (b_val_s3 > a_val_s3) begin
      result_str_s4  = b_str_s3;
      result_type_s4 = b_type_s3;
      none_s4        = 1'b0;
    end else begin
      // equal
      result_str_s4  = 40'b0; // clear
      result_type_s4 = 2'b0;
      none_s4        = 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_s4     <= 1'b0;
      a_str_s4     <= '0;
      b_str_s4     <= '0;
      a_type_s4    <= 2'b0;
      b_type_s4    <= 2'b0;
    end else begin
      start_s4  <= start_s3;
      a_str_s4  <= a_str_s3;
      b_str_s4  <= b_str_s3;
      a_type_s4 <= a_type_s3;
      b_type_s4 <= b_type_s3;
    end
  end

  // ------------------------------------------------------------
  // Stage 5: register outputs, generate done
  // 5-cycle latency: start -> S1 -> S2 -> S3 -> S4 -> S5(done)
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_s5    <= 1'b0;
      result_str  <= 40'b0;
      result_type <= 2'b0;
      none        <= 1'b0;
      done        <= 1'b0;
    end else begin
      start_s5 <= start_s4;
      // latch comparison result from S4
      result_str  <= result_str_s4;
      result_type <= result_type_s4;
      none        <= none_s4;
      done        <= start_s4; // assert done corresponding to this operation
    end
  end

endmodule