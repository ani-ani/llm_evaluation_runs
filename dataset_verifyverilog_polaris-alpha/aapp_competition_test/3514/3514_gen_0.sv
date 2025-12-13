module max_bombs_disarmed (
  input        clk,
  input        rst_n,
  input        start,
  input  [63:0] grid_data,
  output reg [2:0] max_count,
  output reg       done
);

  // Internal registers
  reg [63:0] grid_reg;
  reg [7:0]  row_armed;
  reg [7:0]  col_armed;
  reg [6:0]  total_armed;      // 0-64
  reg        has_both;         // any building with both row & col armed

  reg        start_d1;
  reg        start_d2;

  integer i;

  // Sequential pipeline
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      grid_reg     <= 64'd0;
      row_armed    <= 8'd0;
      col_armed    <= 8'd0;
      total_armed  <= 7'd0;
      has_both     <= 1'b0;
      start_d1     <= 1'b0;
      start_d2     <= 1'b0;
      max_count    <= 3'd0;
      done         <= 1'b0;
    end else begin
      // Pipeline start detection
      start_d1 <= start;
      start_d2 <= start_d1;

      // Default done low; will assert for one cycle when result ready
      done <= 1'b0;

      // Stage 0: capture input on start pulse
      if (start) begin
        grid_reg <= grid_data;
      end

      // Stage 1: compute row_armed, col_armed, total_armed, has_both
      if (start_d1) begin
        row_armed   <= 8'd0;
        col_armed   <= 8'd0;
        total_armed <= 7'd0;
        has_both    <= 1'b0;

        for (i = 0; i < 64; i = i + 1) begin
          if (grid_reg[i]) begin
            // increment total armed
            total_armed <= total_armed + 1'b1;
          end
        end

        // Determine row_armed
        for (i = 0; i < 8; i = i + 1) begin
          row_armed[i] <= |grid_reg[i*8 +: 8];
        end

        // Determine col_armed
        for (i = 0; i < 8; i = i + 1) begin
          col_armed[i] <= (|{ grid_reg[0*8 + i],
                              grid_reg[1*8 + i],
                              grid_reg[2*8 + i],
                              grid_reg[3*8 + i],
                              grid_reg[4*8 + i],
                              grid_reg[5*8 + i],
                              grid_reg[6*8 + i],
                              grid_reg[7*8 + i] });
        end

        // Check for any cell with both row_armed and col_armed
        // (Uses current grid_reg and the row/col_armed that are being assigned)
        // Since non-blocking assignments update at end of block, we derive using
        // combinational expressions directly from grid_reg.
        begin : HAS_BOTH_CALC
          integer r, c;
          reg local_has_both;
          local_has_both = 1'b0;
          for (r = 0; r < 8; r = r + 1) begin
            for (c = 0; c < 8; c = c + 1) begin
              if (grid_reg[r*8 + c]) begin
                if ((|grid_reg[r*8 +: 8]) &&
                    (|{ grid_reg[0*8 + c],
                        grid_reg[1*8 + c],
                        grid_reg[2*8 + c],
                        grid_reg[3*8 + c],
                        grid_reg[4*8 + c],
                        grid_reg[5*8 + c],
                        grid_reg[6*8 + c],
                        grid_reg[7*8 + c] })) begin
                  local_has_both = 1'b1;
                end
              end
            end
          end
          has_both <= local_has_both;
        end
      end

      // Stage 2: compute max_count and assert done
      if (start_d2) begin
        if (total_armed == 7'd0) begin
          max_count <= 3'd0;
        end else if (has_both) begin
          // max_count = min(total_armed, 7)
          if (total_armed[6:3] != 4'd0)
            max_count <= 3'd7;
          else
            max_count <= total_armed[2:0];
        end else begin
          // max_count = min(total_armed - 1, 7)
          if (total_armed <= 7'd1) begin
            max_count <= 3'd0;
          end else begin
            if ((total_armed - 1'b1)[6:3] != 4'd0)
              max_count <= 3'd7;
            else
              max_count <= (total_armed - 1'b1)[2:0];
          end
        end
        done <= 1'b1;
      end
    end
  end

endmodule