module event_duration (
  input [4:0] start_month, start_day,
  input [4:0] end_month, end_day,
  input [7:0] F1,
  output reg signed [9:0] result,
  output reg valid
);
  
  function [8:0] compute_doy;
    input [4:0] month, day;
    begin
      case (month)
        5'd1:  compute_doy = day;
        5'd2:  compute_doy = 31 + day;
        5'd3:  compute_doy = 59 + day;
        5'd4:  compute_doy = 90 + day;
        5'd5:  compute_doy = 120 + day;
        5'd6:  compute_doy = 151 + day;
        5'd7:  compute_doy = 181 + day;
        5'd8:  compute_doy = 212 + day;
        5'd9:  compute_doy = 243 + day;
        5'd10: compute_doy = 273 + day;
        5'd11: compute_doy = 304 + day;
        5'd12: compute_doy = 334 + day;
        default: compute_doy = 9'd0;
      endcase
    end
  endfunction

  reg [8:0] start_doy;
  reg [8:0] end_doy;
  
  always @* begin
    start_doy = compute_doy(start_month, start_day);
    end_doy = compute_doy(end_month, end_day);
  end

  always @* begin
    reg found;
    reg [9:0] res;
    found = 1'b0;
    res = 10'd0;
    
    if (end_doy >= start_doy) begin
      if (F1 == 8'd0) begin
        if (end_doy - start_doy == 9'd0) begin
          found = 1'b1;
          res = 10'd1;
        end
      end else begin
        if ((end_doy - start_doy) % F1 == 8'd0) begin
          integer q;
          q = (end_doy - start_doy) / F1;
          if (q >= 1 && q <= 365) begin
            found = 1'b1;
            res = q;
          end
        end
      end
    end
    
    if (!found) begin
      if (F1 == 8'd0) begin
        if (365 - start_doy + end_doy == 9'd0) begin
          found = 1'b1;
          res = 10'd1;
        end
      end else begin
        if ((365 - start_doy + end_doy) % F1 == 8'd0) begin
          integer q;
          q = (365 - start_doy + end_doy) / F1;
          if (q >= 1 && q <= 365) begin
            found = 1'b1;
            res = q;
          end
        end
      end
    end
    
    if (found) begin
      result = res;
      valid = 1'b1;
    end else begin
      result = -10'd1;
      valid = 1'b0;
    end
  end
endmodule