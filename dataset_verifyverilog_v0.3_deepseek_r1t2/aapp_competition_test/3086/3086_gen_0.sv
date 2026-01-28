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
                5'd1: compute_doy = 9'd0 + day;
                5'd2: compute_doy = 9'd31 + day;
                5'd3: compute_doy = 9'd59 + day;
                5'd4: compute_doy = 9'd90 + day;
                5'd5: compute_doy = 9'd120 + day;
                5'd6: compute_doy = 9'd151 + day;
                5'd7: compute_doy = 9'd181 + day;
                5'd8: compute_doy = 9'd212 + day;
                5'd9: compute_doy = 9'd243 + day;
                5'd10: compute_doy = 9'd273 + day;
                5'd11: compute_doy = 9'd304 + day;
                5'd12: compute_doy = 9'd334 + day;
                default: compute_doy = 9'd0;
            endcase
        end
    endfunction

    wire [8:0] start_doy = compute_doy(start_month, start_day);
    wire [8:0] end_doy = compute_doy(end_month, end_day);

    // Possible lengths
    wire [8:0] L_same = (end_doy >= start_doy) ? (end_doy - start_doy) : 9'd0;
    wire [8:0] L_cross = 9'd365 - start_doy + end_doy;

    always @* begin
        reg found;
        reg [9:0] res;
        
        found = 1'b0;
        res = 10'sb1111111111;  // -1

        // Try non-crossing interpretation first
        if (end_doy >= start_doy) begin
            if (F1 == 8'd0) begin
                if (L_same == 9'd0) begin
                    found = 1'b1;
                    res = 10'sd1;
                end
            end else begin
                if (L_same % F1 == 8'd0) begin
                    integer q = L_same / F1;
                    if (q >= 9'd1 && q <= 9'd365) begin
                        found = 1'b1;
                        res = q;
                    end
                end
            end
        end

        // If not found, try crossing interpretation
        if (!found) begin
            if (F1 == 8'd0) begin
                if (L_cross == 9'd0) begin
                    found = 1'b1;
                    res = 10'sd1;
                end
            end else begin
                if (L_cross % F1 == 8'd0) begin
                    integer q = L_cross / F1;
                    if (q >= 9'd1 && q <= 9'd365) begin
                        found = 1'b1;
                        res = q;
                    end
                end
            end
        end

        result = res;
        valid = found;
    end
endmodule