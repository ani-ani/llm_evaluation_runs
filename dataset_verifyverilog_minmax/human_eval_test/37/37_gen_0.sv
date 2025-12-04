module sort_even (
  input clk,
  input rst_n,
  input [7:0][7:0] data_in,
  input start,
  output reg [7:0][7:0] data_out,
  output reg done
);

logic [2:0] cnt;
reg [7:0] even_reg [0:3];

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    cnt <= 0;
    done <= 0;
    for (int i = 0; i < 4; i++) even_reg[i] <= 8'b0;
    for (int j = 0; j < 8; j++) data_out[j] <= 8'b0;
  end else begin
    if (start && cnt == 0) begin
      cnt <= 1;
      done <= 0;
    end else if (cnt > 0 && cnt < 5) begin
      cnt <= cnt + 1;
      done <= 0;
    end else if (cnt == 5) begin
      cnt <= 0;
      done <= 1;
    end else begin
      cnt <= 0;
      done <= 0;
    end

    case (cnt)
      1: begin
        even_reg[0] <= data_in[0];
        even_reg[1] <= data_in[2];
        even_reg[2] <= data_in[4];
        even_reg[3] <= data_in[6];
      end
      2: begin
        if ($signed(even_reg[0]) > $signed(even_reg[1])) begin
          even_reg[0] <= even_reg[1];
          even_reg[1] <= even_reg[0];
        end
        if ($signed(even_reg[2]) > $signed(even_reg[3])) begin
          even_reg[2] <= even_reg[3];
          even_reg[3] <= even_reg[2];
        end
      end
      3: begin
        if ($signed(even_reg[0]) > $signed(even_reg[2])) begin
          even_reg[0] <= even_reg[2];
          even_reg[2] <= even_reg[0];
        end
        if ($signed(even_reg[1]) > $signed(even_reg[3])) begin
          even_reg[1] <= even_reg[3];
          even_reg[3] <= even_reg[1];
        end
      end
      4: begin
        if ($signed(even_reg[1]) > $signed(even_reg[2])) begin
          even_reg[1] <= even_reg[2];
          even_reg[2] <= even_reg[1];
        end
      end
      5: begin
        data_out[0] <= even_reg[0];
        data_out[1] <= data_in[1];
        data_out[2] <= even_reg[1];
        data_out[3] <= data_in[3];
        data_out[4] <= even_reg[2];
        data_out[5] <= data_in[5];
        data_out[6] <= even_reg[3];
        data_out[7] <= data_in[7];
      end
    endcase
  end
end

endmodule