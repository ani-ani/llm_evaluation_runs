module rotate_right (
  input [2:0] rotate_amount,
  input [7:0] data_in [0:7],
  output [7:0] data_out [0:7]
);

  always @* begin
    case (rotate_amount)
      3'd0: begin
        data_out[0] = data_in[0];
        data_out[1] = data_in[1];
        data_out[2] = data_in[2];
        data_out[3] = data_in[3];
        data_out[4] = data_in[4];
        data_out[5] = data_in[5];
        data_out[6] = data_in[6];
        data_out[7] = data_in[7];
      end
      3'd1: begin
        data_out[0] = data_in[7];
        data_out[1] = data_in[0];
        data_out[2] = data_in[1];
        data_out[3] = data_in[2];
        data_out[4] = data_in[3];
        data_out[5] = data_in[4];
        data_out[6] = data_in[5];
        data_out[7] = data_in[6];
      end
      3'd2: begin
        data_out[0] = data_in[6];
        data_out[1] = data_in[7];
        data_out[2] = data_in[0];
        data_out[3] = data_in[1];
        data_out[4] = data_in[2];
        data_out[5] = data_in[3];
        data_out[6] = data_in[4];
        data_out[7] = data_in[5];
      end
      3'd3: begin
        data_out[0] = data_in[5];
        data_out[1] = data_in[6];
        data_out[2] = data_in[7];
        data_out[3] = data_in[0];
        data_out[4] = data_in[1];
        data_out[5] = data_in[2];
        data_out[6] = data_in[3];
        data_out[7] = data_in[4];
      end
      3'd4: begin
        data_out[0] = data_in[4];
        data_out[1] = data_in[5];
        data_out[2] = data_in[6];
        data_out[3] = data_in[7];
        data_out[4] = data_in[0];
        data_out[5] = data_in[1];
        data_out[6] = data_in[2];
        data_out[7] = data_in[3];
      end
      3'd5: begin
        data_out[0] = data_in[3];
        data_out[1] = data_in[4];
        data_out[2] = data_in[5];
        data_out[3] = data_in[6];
        data_out[4] = data_in[7];
        data_out[5] = data_in[0];
        data_out[6] = data_in[1];
        data_out[7] = data_in[2];
      end
      3'd6: begin
        data_out[0] = data_in[2];
        data_out[1] = data_in[3];
        data_out[2] = data_in[4];
        data_out[3] = data_in[5];
        data_out[4] = data_in[6];
        data_out[5] = data_in[7];
        data_out[6] = data_in[0];
        data_out[7] = data_in[1];
      end
      3'd7: begin
        data_out[0] = data_in[1];
        data_out[1] = data_in[2];
        data_out[2] = data_in[3];
        data_out[3] = data_in[4];
        data_out[4] = data_in[5];
        data_out[5] = data_in[6];
        data_out[6] = data_in[7];
        data_out[7] = data_in[0];
      end
    endcase
  end

endmodule