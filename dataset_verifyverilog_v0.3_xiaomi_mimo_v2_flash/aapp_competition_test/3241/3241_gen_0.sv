module ham_distribution (
    input [7:0] A0,
    input [7:0] A1,
    input [7:0] A2,
    input [7:0] B0,
    input [7:0] B1,
    input [7:0] B2,
    output real result
);

    real S;
    real lower_bound;
    real upper_bound;
    real deltaA;
    real deltaB;
    real bound;

    always @(*) begin
        S = B0 + B1 + B2;
        lower_bound = 0.0;
        upper_bound = 10000000.0; // 10 million

        // Pair (0,1)
        deltaA = A0 - A1;
        deltaB = B0 - B1;
        if (deltaB == 0.0) begin
            if (deltaA < 0.0) begin
                lower_bound = 100000000.0;
                upper_bound = -100000000.0;
            end
        end else begin
            bound = (-S * deltaA) / deltaB;
            if (deltaB > 0.0) begin
                if (bound > lower_bound) lower_bound = bound;
            end else begin
                if (bound < upper_bound) upper_bound = bound;
            end
        end

        // Pair (1,2)
        deltaA = A1 - A2;
        deltaB = B1 - B2;
        if (deltaB == 0.0) begin
            if (deltaA < 0.0) begin
                lower_bound = 100000000.0;
                upper_bound = -100000000.0;
            end
        end else begin
            bound = (-S * deltaA) / deltaB;
            if (deltaB > 0.0) begin
                if (bound > lower_bound) lower_bound = bound;
            end else begin
                if (bound < upper_bound) upper_bound = bound;
            end
        end

        // Finalize
        if (lower_bound < 0.0) lower_bound = 0.0;
        if (lower_bound > upper_bound || lower_bound > 10000000.0 || upper_bound < 0.0) begin
            result = -1.0;
        end else begin
            result = lower_bound;
        end
    end

endmodule