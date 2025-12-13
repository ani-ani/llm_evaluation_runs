module bracket_nested_check(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [3:0]  length,
  input  logic [15:0] data,
  output logic        result,
  output logic        done
);

  logic [3:0] depth;
  logic       nested_flag;
  logic [3:0] cycle_cnt;
  logic [15:0] data_reg;
  logic [3:0] length_reg;
  logic       busy;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      depth       <= 4'd0;
      nested_flag <= 1'b0;
      cycle_cnt   <= 4'd0;
      data_reg    <= 16'd0;
      length_reg  <= 4'd0;
      result      <= 1'b0;
      done        <= 1'b0;
      busy        <= 1'b0;
    end else begin
      done <= 1'b0; // default

      if (start && !busy) begin
        // Initialize for new operation
        depth       <= 4'd0;
        nested_flag <= 1'b0;
        cycle_cnt   <= 4'd0;
        data_reg    <= data;
        length_reg  <= length;
        busy        <= 1'b1;
      end else if (busy) begin
        // Process current bit (LSB first)
        if (cycle_cnt < length_reg) begin
          if (data_reg[0] == 1'b0) begin
            // '[': increment depth (saturate at 15)
            if (depth < 4'd15)
              depth <= depth + 4'd1;
          end else begin
            // ']' processing
            if (depth >= 4'd2)
              nested_flag <= 1'b1;
            if (depth > 4'd0)
              depth <= depth - 4'd1;
          end

          // Shift to next bit and increment cycle count
          data_reg  <= data_reg >> 1;
          cycle_cnt <= cycle_cnt + 4'd1;

          // Check completion at next cycle
          if (cycle_cnt + 4'd1 == length_reg) begin
            result <= nested_flag;
            done   <= 1'b1;
            busy   <= 1'b0;
          end
        end else begin
          // Safety: if length_reg is zero or already reached
          result <= nested_flag;
          done   <= 1'b1;
          busy   <= 1'b0;
        end
      end
    end
  end

endmodule