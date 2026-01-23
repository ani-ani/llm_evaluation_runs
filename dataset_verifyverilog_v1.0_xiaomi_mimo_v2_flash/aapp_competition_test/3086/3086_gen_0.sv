module event_duration (
    input [4:0] start_month,
    input [4:0] start_day,
    input [4:0] end_month,
    input [4:0] end_day,
    input [7:0] F1,
    output reg signed [9:0] result,
    output reg valid
);

    // Function to compute day of year (1-365)
    function [8:0] compute_doy;
        input [4:0] month;
        input [4:0] day;
        begin
            case (month)
                5'd1: compute_doy = day;
                5'd2: compute_doy = 31 + day;
                5'd3: compute_doy = 59 + day;
                5'd4: compute_doy = 90 + day;
                5'd5: compute_doy = 120 + day;
                5'd6: compute_doy = 151 + day;
                5'd7: compute_doy = 181 + day;
                5'd8: compute_doy = 212 + day;
                5'd9: compute_doy = 243 + day;
                5'd10: compute_doy = 273 + day;
                5'd11: compute_doy = 304 + day;
                5'd12: compute_doy = 334 + day;
                default: compute_doy = 9'd0;
            endcase
        end
    endfunction

    wire [8:0] start_doy = compute_doy(start_month, start_day);
    wire [8:0] end_doy = compute_doy(end_month, end_day);

    // Possible lengths
    wire [8:0] L_same = (end_doy >= start_doy) ? (end_doy - start_doy) : 9'd0;
    wire [8:0] L_cross = 365 - start_doy + end_doy;

    // Intermediate calculations
    reg [8:0] L_temp;
    reg [8:0] q_temp;
    reg found_temp;
    reg [9:0] res_temp;
    integer q;

    always @* begin
        found_temp = 0;
        res_temp = -10'sd1;

        // Try non-crossing interpretation
        if (end_doy >= start_doy) begin
            if (F1 == 8'd0) begin
                if (L_same == 9'd0) begin
                    found_temp = 1;
                    res_temp = 10'sd1;
                end
            end else begin
                if (L_same % F1 == 9'd0) begin
                    q = L_same / F1;
                    if (q >= 1 && q <= 365) begin
                        found_temp = 1;
                        res_temp = q;
                    end
                end
            end
        end

        // If not found, try crossing interpretation
        if (!found_temp) begin
            if (F1 == 8'd0) begin
                if (L_cross == 9'd0) begin
                    found_temp = 1;
                    res_temp = 10'sd1;
                end
            end else begin
                if (L_cross % F1 == 9'd0) begin
                    q = L_cross / F1;
                    if (q >= 1 && q <= 365) begin
                        found_temp = 1;
                        res_temp = q;
                    end
                end
            end
        end

        if (found_temp) begin
            result = res_temp;
            valid = 1'b1;
        end else begin
            result = -10'sd1;
            valid = 1'b0;
        end
    end

endmodule