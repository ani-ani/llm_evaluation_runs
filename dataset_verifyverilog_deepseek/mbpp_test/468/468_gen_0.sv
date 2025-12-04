module max_inc_subseq_product (
  input clk,
  input rst_n,
  input start,
  input [7:0] arr [0:7],
  output reg [31:0] max_product,
  output reg done
);

  reg [3:0] cycle_cnt;
  reg [31:0] mpis [0:7];
  reg computing;
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 4\'b0;
      for (i = 0; i < 8; i = i+1) mpis[i] <= 32\'b0;
      max_product <= 32\'b0;
      done <= 1\'b0;
      computing <= 1\'b0;
    end else begin
      if (computing) begin
        case (cycle_cnt)
          4\'d0: begin /* Initialize */
            for (i = 0; i < 8; i = i+1)
              mpis[i] <= {24\'d0, arr[i]};
            cycle_cnt <= cycle_cnt + 1;
          end
          
          4\'d1,4\'d2,4\'d3,4\'d4,4\'d5,4\'d6,4\'d7: begin /* Process pairs */
            automatic int idx = cycle_cnt - 1;
            if (arr[idx] < arr[idx+1])
              if ((mpis[idx] * {24\'d0, arr[idx+1]}) > mpis[idx+1])
                mpis[idx+1] <= mpis[idx] * {24\'d0, arr[idx+1]};
            cycle_cnt <= cycle_cnt + 1;
          end
          
          4\'d8: begin /* Finalize */
            automatic logic [31:0] max_val = 32\'d0;
            for (i = 0; i < 8; i = i+1)
              if (mpis[i] > max_val) max_val = mpis[i];
            max_product <= max_val;
            done <= 1\'b1;
            computing <= 1\'b0;
          end
          
          default: cycle_cnt <= 4\'b0;
        endcase
      end else begin
        /* Idle state */
        done <= 1\'b0;
        if (start) begin
          computing <= 1\'b1;
          cycle_cnt <= 4\'b0;
        end
      end
    end
  end

endmodule