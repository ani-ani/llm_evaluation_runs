module rearrange_neg_pos (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0][7:0] arr_in,
  output reg [15:0][7:0] arr_out,
  output reg done
);

  reg [3:0] cnt;
  reg [4:0] neg_ptr, pos_ptr;
  reg [7:0] neg_array [0:15];
  reg [7:0] pos_array [0:15];
  reg processing;

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 4'd0;
      done <= 1'b0;
      neg_ptr <= 5'd0;
      pos_ptr <= 5'd0;
      processing <= 1'b0;
    end else begin
      if (start && !processing) begin
        processing <= 1'b1;
        cnt <= 4'd0;
        neg_ptr <= 5'd0;
        pos_ptr <= 5'd0;
        done <= 1'b0;
      end else if (processing) begin
        if (cnt < n) begin
          if (arr_in[cnt][7]) begin
            neg_array[neg_ptr] <= arr_in[cnt];
            neg_ptr <= neg_ptr + 5'd1;
          end else begin
            pos_array[pos_ptr] <= arr_in[cnt];
            pos_ptr <= pos_ptr + 5'd1;
          end
        end
        cnt <= cnt + 4'd1;

        if (cnt == 4'd15) begin
          processing <= 1'b0;
          done <= 1'b1;
          for (int i=0; i<neg_ptr; i=i+1) arr_out[i] <= neg_array[i];
          for (int i=0; i<pos_ptr; i=i+1) arr_out[neg_ptr+i] <= pos_array[i];
          for (int i=n; i<16; i=i+1) arr_out[i] <= arr_in[i];
        end else begin
          done <= 1'b0;
        end
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule