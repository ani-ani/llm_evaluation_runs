module power_substring_counter(
  input [15:0] n,
  input [3:0] e,
  output reg [15:0] count
);

  // Compute power = 2^e
  reg [15:0] power;
  always @(*) begin
    case (e)
      4'd0:  power = 16'd1;
      4'd1:  power = 16'd2;
      4'd2:  power = 16'd4;
      4'd3:  power = 16'd8;
      4'd4:  power = 16'd16;
      4'd5:  power = 16'd32;
      4'd6:  power = 16'd64;
      4'd7:  power = 16'd128;
      4'd8:  power = 16'd256;
      4'd9:  power = 16'd512;
      4'd10: power = 16'd1024;
      4'd11: power = 16'd2048;
      4'd12: power = 16'd4096;
      4'd13: power = 16'd8192;
      4'd14: power = 16'd16384;
      4'd15: power = 16'd32768;
      default: power = 16'd1;
    endcase
  end

  // Extract digits of power (max 5 digits for 32768)
  reg [3:0] power_digits [0:4];
  reg [3:0] power_digit_count;
  always @(*) begin
    reg [15:0] temp = power;
    reg [3:0] i;
    for (i = 0; i < 5; i = i + 1) begin
      power_digits[i] = temp % 10;
      temp = temp / 10;
      if (temp == 0) begin
        power_digit_count = i + 1;
        break;
      end
    end
    if (i == 5) power_digit_count = 5;
  end

  // Main counting logic
  reg [15:0] k;
  reg [15:0] total_count;
  always @(*) begin
    total_count = 0;
    for (k = 0; k <= n; k = k + 1) begin
      // Extract digits of k (max 5 digits for 65535)
      reg [3:0] k_digits [0:4];
      reg [3:0] k_digit_count;
      reg [15:0] temp_k = k;
      reg [3:0] j;
      for (j = 0; j < 5; j = j + 1) begin
        k_digits[j] = temp_k % 10;
        temp_k = temp_k / 10;
        if (temp_k == 0) begin
          k_digit_count = j + 1;
          break;
        end
      end
      if (j == 5) k_digit_count = 5;

      // Check for substring match
      reg match;
      match = 0;
      if (power_digit_count <= k_digit_count) begin
        reg [3:0] pos;
        for (pos = 0; pos <= k_digit_count - power_digit_count; pos = pos + 1) begin
          reg [3:0] offset;
          reg all_match;
          all_match = 1;
          for (offset = 0; offset < power_digit_count; offset = offset + 1) begin
            if (k_digits[pos + offset] != power_digits[offset]) begin
              all_match = 0;
              break;
            end
          end
          if (all_match) begin
            match = 1;
            break;
          end
        end
      end

      if (match) total_count = total_count + 1;
    end
  end

  assign count = total_count;

endmodule