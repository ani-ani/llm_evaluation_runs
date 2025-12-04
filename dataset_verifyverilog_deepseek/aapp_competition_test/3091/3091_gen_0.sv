module kenken_section_solver (
  input [1:0] n,
  input [1:0] m,
  input [4:0] t,
  input [1:0] op,
  input [1:0] pos0_row, pos0_col,
  input [1:0] pos1_row, pos1_col,
  input [1:0] pos2_row, pos2_col,
  output reg [2:0] count
);

  reg [2:0] d0_reg, d1_reg, d2_reg;
  reg [4:0] temp;
  reg unique_positions;

  always_comb begin
    count = 0;

    // m=2 block
    if (m == 2) begin
      for (d0_reg = 1; d0_reg <= 4; d0_reg = d0_reg +1) begin
        for (d1_reg = 1; d1_reg <= 4; d1_reg = d1_reg +1) begin
          if (d0_reg != d1_reg) begin
            // Check position uniqueness
            unique_positions = !(pos0_row == pos1_row && pos0_col == pos1_col);
            if (unique_positions) begin
              case (op)
                2'b00: if ((d0_reg + d1_reg) == t) count = count + 1;
                2'b01: if ((d0_reg > d1_reg ? d0_reg - d1_reg : d1_reg - d0_reg) == t) count = count + 1;
                2'b10: if ((d0_reg * d1_reg) == t) count = count + 1;
                2'b11: begin
                  if ((d0_reg % d1_reg == 0 && d0_reg / d1_reg == t) || (d1_reg % d0_reg == 0 && d1_reg / d0_reg == t))
                    count = count + 1;
                end
              endcase
            end
          end
        end
      end
    end 
    
    // m=3 block
    else if (m == 3) begin
      for (d0_reg = 1; d0_reg <=4; d0_reg=d0_reg+1) begin
        for (d1_reg=1; d1_reg <=4; d1_reg=d1_reg+1) begin
          if (d1_reg != d0_reg) begin
            for (d2_reg=1; d2_reg <=4; d2_reg=d2_reg+1) begin
              if (d2_reg != d0_reg && d2_reg != d1_reg) begin
                // Check all positions are unique
                unique_positions = !( (pos0_row == pos1_row && pos0_col == pos1_col) ||
                                      (pos0_row == pos2_row && pos0_col == pos2_col) ||
                                      (pos1_row == pos2_row && pos1_col == pos2_col) );
                if (unique_positions) begin
                  case (op)
                    2'b00: if (d0_reg + d1_reg + d2_reg == t) count = count +1;
                    2'b01: if ($signed(d0_reg - d1_reg - d2_reg) == $signed(t)) count = count +1;
                    2'b10: if (d0_reg * d1_reg * d2_reg == t) count = count +1;
                    2'b11: begin
                      if (d1_reg != 0 && d2_reg != 0 &&
                          (d0_reg % d1_reg ==0) &&
                          ((d0_reg / d1_reg) % d2_reg ==0) &&
                          ( (d0_reg / d1_reg) / d2_reg == t ))
                        count = count +1;
                    end
                  endcase
                end
              end
            end
          end
        end
      end
    end
  end
endmodule