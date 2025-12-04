module date_validator(input [79:0] date_str, output valid);

  // Check dash positions
  wire dash2_ok = (date_str[23:16] == 8'h2D);
  wire dash5_ok = (date_str[47:40] == 8'h2D);
  wire format_ok = dash2_ok && dash5_ok;

  // Convert ASCII to decimal
  wire [7:0] month = (date_str[7:0] - 8'd48) * 8'd10 + (date_str[15:8] - 8'd48);
  wire [7:0] day = (date_str[31:24] - 8'd48) * 8'd10 + (date_str[39:32] - 8'd48);

  // Month validation
  wire month_valid = (month >= 8'd1) && (month <= 8'd12);

  // Day validation
  wire day_valid;
  always_comb begin
    case (month)
      8'd1,8'd3,8'd5,8'd7,8'd8,8'd10,8'd12: day_valid = (day <= 8'd31) && (day >= 8'd1);
      8'd4,8'd6,8'd9,8'd11: day_valid = (day <= 8'd30) && (day >= 8'd1);
      8'd2: day_valid = (day <= 8'd29) && (day >= 8'd1);
      default: day_valid = 1'b0;
    endcase
  end

  assign valid = format_ok && month_valid && day_valid;

endmodule