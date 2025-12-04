module clock_corrector(input [3:0] hour_tens, input [3:0] hour_units, input [3:0] min_tens, input [3:0] min_units, input is_24h_format, output reg [3:0] corr_hour_tens, output reg [3:0] corr_hour_units, output reg [3:0] corr_min_tens, output reg [3:0] corr_min_units);
  always_comb begin
    // Correct minutes
    corr_min_tens = (min_tens > 5) ? 4'd5 : min_tens;
    corr_min_units = (min_units > 9) ? 4'd0 : min_units;
    
    // Correct hours
    if (is_24h_format) begin
      // 24-hour adjustments
      if (hour_tens > 2) begin
        corr_hour_tens = (hour_units > 3) ? 4'd0 : 4'd1;
        corr_hour_units = hour_units;
      end else if (hour_tens == 2 && hour_units > 3) begin
        corr_hour_tens = 4'd1;
        corr_hour_units = hour_units;
      end else begin
        corr_hour_tens = hour_tens;
        corr_hour_units = hour_units;
      end
    end else begin
      // 12-hour adjustments
      if (hour_tens == 0 && hour_units == 0) begin // 00 -> 01
        corr_hour_tens = 4'd0;
        corr_hour_units = 4'd1;
      end else if (hour_tens >= 2 || (hour_tens == 1 && hour_units >= 3)) begin
        if (hour_tens == 2) begin
          if (hour_units < 3) begin
            corr_hour_tens = 4'd1;
            corr_hour_units = hour_units;
          end else begin
            corr_hour_tens = 4'd1;
            corr_hour_units = 4'd0;
          end
        end else begin
          corr_hour_tens = 4'd0;
          corr_hour_units = 4'd1;
        end
      end else begin
        corr_hour_tens = hour_tens;
        corr_hour_units = hour_units;
      end
    end
  end
endmodule