module sort_even (
  input clk,
  input rst_n,
  input start,
  input signed [7:0][7:0] data_in,
  output reg signed [7:0][7:0] data_out,
  output reg done
);

  reg signed [7:0][7:0] data_reg;
  reg signed [7:0] temp [0:3];
  reg signed [7:0] stage1 [0:3];
  reg signed [7:0] stage2 [0:3];
  reg signed [7:0] stage3 [0:3];
  reg [2:0] cycle_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 3'b0;
      done <= 1'b0;
      data_out <= 64'b0;
    end else begin
      done <= 1'b0;

      case (cycle_count)
        3'd0: begin
          if (start) begin
            data_reg <= data_in;
            temp[0] <= data_in[7];
            temp[1] <= data_in[5];
            temp[2] <= data_in[3];
            temp[3] <= data_in[1];
            cycle_count <= cycle_count + 1;
          end
        end
        3'd1: begin
          stage1[0] <= (temp[0] <= temp[1]) ? temp[0] : temp[1];
          stage1[1] <= (temp[0] <= temp[1]) ? temp[1] : temp[0];
          stage1[2] <= (temp[2] <= temp[3]) ? temp[2] : temp[3];
          stage1[3] <= (temp[2] <= temp[3]) ? temp[3] : temp[2];
          cycle_count <= cycle_count + 1;
        end
        3'd2: begin
          stage2[0] <= (stage1[0] <= stage1[2]) ? stage1[0] : stage1[2];
          stage2[2] <= (stage1[0] <= stage1[2]) ? stage1[2] : stage1[0];
          stage2[1] <= (stage1[1] <= stage1[3]) ? stage1[1] : stage1[3];
          stage2[3] <= (stage1[1] <= stage1[3]) ? stage1[3] : stage1[1];
          cycle_count <= cycle_count + 1;
        end
        3'd3: begin
          stage3[0] <= stage2[0];
          stage3[1] <= (stage2[1] <= stage2[2]) ? stage2[1] : stage2[2];
          stage3[2] <= (stage2[1] <= stage2[2]) ? stage2[2] : stage2[1];
          stage3[3] <= stage2[3];
          cycle_count <= cycle_count + 1;
        end
        3'd4: begin
          data_out[7] <= stage3[0];
          data_out[5] <= stage3[1];
          data_out[3] <= stage3[2];
          data_out[1] <= stage3[3];
          data_out[6] <= data_reg[6];
          data_out[4] <= data_reg[4];
          data_out[2] <= data_reg[2];
          data_out[0] <= data_reg[0];
          done <= 1'b1;
          cycle_count <= 3'd0;
        end
        default: cycle_count <= 3'd0;
      endcase
    end
  end

endmodule