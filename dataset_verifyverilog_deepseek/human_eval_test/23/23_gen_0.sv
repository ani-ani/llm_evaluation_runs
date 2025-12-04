module string_length (
  input reg [127:0] string_bytes,
  output reg [4:0] length
);
  logic [15:0] is_zero;
  logic [15:0] first_zero_flag;
  logic all_non_zero_so_far;

  always_comb begin
    for (int i=0; i<16; i++) begin
      is_zero[i] = (string_bytes[i*8 +:8] == 8'b0);
    end

    all_non_zero_so_far = 1'b1;
    first_zero_flag = 16'b0;

    for (int i=0; i<16; i++) begin
      if (all_non_zero_so_far && is_zero[i]) begin
        first_zero_flag[i] = 1'b1;
        all_non_zero_so_far = 1'b0;
      end else begin
        first_zero_flag[i] = 1'b0;
        if (all_non_zero_so_far) begin
          all_non_zero_so_far = !is_zero[i];
        end
      end
    end

    case (1'b1)
      first_zero_flag[0]: length = 5'd0;
      first_zero_flag[1]: length = 5'd1;
      first_zero_flag[2]: length = 5'd2;
      first_zero_flag[3]: length = 5'd3;
      first_zero_flag[4]: length = 5'd4;
      first_zero_flag[5]: length = 5'd5;
      first_zero_flag[6]: length = 5'd6;
      first_zero_flag[7]: length = 5'd7;
      first_zero_flag[8]: length = 5'd8;
      first_zero_flag[9]: length = 5'd9;
      first_zero_flag[10]: length = 5'd10;
      first_zero_flag[11]: length = 5'd11;
      first_zero_flag[12]: length = 5'd12;
      first_zero_flag[13]: length = 5'd13;
      first_zero_flag[14]: length = 5'd14;
      first_zero_flag[15]: length = 5'd15;
      default: length = 5'd16;
    endcase
  end
endmodule