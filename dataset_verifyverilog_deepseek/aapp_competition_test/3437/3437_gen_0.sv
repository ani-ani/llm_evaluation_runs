module max_tube_pairs (
  input clk,
  input rst_n,
  input start,
  input [13:0] L1,
  input [13:0] L2,
  input [7:0][13:0] tubes,
  output reg [15:0] max_total,
  output reg impossible,
  output reg done
);

  // Internal storage for pipelining
  reg [13:0] L1_reg, L2_reg;
  reg [7:0][13:0] tubes_reg;
  reg [15:0] best_total;
  reg found;

  // Pipeline control
  reg [1:0] stage;
  always @(posedge klk or negedge rst_n) begin
    if (!rst_n) begin
      stage <= 2'b00;
      tubes_reg <= '0;
      L1_reg <= '0;
      L2_reg <= '0;
      max_total <= '0;
      impossible <= 1'b0;
      done <= 1'b0;
      best_total <= '0;
      found <= 1'b0;
    end else begin
      done <= 1'b0;

      case (stage)
        2'b00: begin // IDLE
          if (start) begin
            tubes_reg <= tubes;
            L1_reg <= L1;
            L2_reg <= L2;
            best_total <= '0;
            found <= 1'b0;
            stage <= 2'b01;
          end
        end

        2'b01: stage <= 2'b10; // STAGE 1: Comparison pipeline
        
        2'b10: begin // STAGE 2: Comparison results
          stage <= 2'b00;
          done <= 1'b1;
          max_total <= (found) ? best_total : 16'd0;
          impossible <= !found;
        end
      endcase
    end
  end

  // Combinational processing during stage 1
  generate
    genvar i, j, k, l;
    for (i=0; i<5; i=i+1) begin : gi
      for (j=i+1; j<6; j=j+1) begin : gj
        for (k=j+1; k<7; k=k+1) begin : gk
          for (l=k+1; l<8; l=l+1) begin : gl
            always @(*) begin
              if (stage == 2'b01) begin
                integer valid_split;
                reg [15:0] total;
                
                // Compute all 3 splits
                reg [14:0] split1_p1 = tubes_reg[i] + tubes_reg[j];
                reg [14:0] split1_p2 = tubes_reg[k] + tubes_reg[l];
                reg [14:0] split2_p1 = tubes_reg[i] + tubes_reg[k];
                reg [14:0] split2_p2 = tubes_reg[j] + tubes_reg[l];
                reg [14:0] split3_p1 = tubes_reg[i] + tubes_reg[l];
                reg [14:0] split3_p2 = tubes_reg[j] + tubes_reg[k];
                
         
                valid_split = (split1_p1 <= L1_reg && split1_p2 <= L2_reg) ||
                             (split2_p1 <= L1_reg && split2_p2 <= L2_reg) ||
                             (split3_p1 <= L1_reg && split3_p2 <= L2_reg);

 
                total = tubes_reg[i] + tubes_reg[j] + tubes_reg[k] + tubes_reg[l];

                // Update best solution
                if (valid_split && total > best_total) begin
                  best_total <= total;
                  found <= 1'b1;
                end
              end
            end
          end
        end
      end
    end
  endgenerate
endmodule