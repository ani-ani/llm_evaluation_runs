module lifespan_max (
    input [31:0] n,
    input [31:0] c,
    input [31:0] p,
    input [31:0] t_0, input [31:0] x_0, input [31:0] y_0,
    input [31:0] t_1, input [31:0] x_1, input [31:0] y_1,
    input [31:0] t_2, input [31:0] x_2, input [31:0] y_2,
    input [31:0] t_3, input [31:0] x_3, input [31:0] y_3,
    input [31:0] t_4, input [31:0] x_4, input [31:0] y_4,
    input [31:0] t_5, input [31:0] x_5, input [31:0] y_5,
    input [31:0] t_6, input [31:0] x_6, input [31:0] y_6,
    input [31:0] t_7, input [31:0] x_7, input [31:0] y_7,
    output real result
);

    real dp [0:7];
    real r [0:7];
    real t [0:7];
    real max_lifespan;
    integer i;
    integer j;

    always @(*) begin
        // Initialize arrays
        for (i = 0; i < 8; i = i + 1) begin
            dp[i] = 0.0;
            r[i] = 0.0;
            t[i] = 0.0;
        end
        
        // Process inputs based on p value
        if (p > 32'd0) begin t[0] = t_0; r[0] = (1.0 * y_0) / x_0; end
        if (p > 32'd1) begin t[1] = t_1; r[1] = (1.0 * y_1) / x_1; end
        if (p > 32'd2) begin t[2] = t_2; r[2] = (1.0 * y_2) / x_2; end
        if (p > 32'd3) begin t[3] = t_3; r[3] = (1.0 * y_3) / x_3; end
        if (p > 32'd4) begin t[4] = t_4; r[4] = (1.0 * y_4) / x_4; end
        if (p > 32'd5) begin t[5] = t_5; r[5] = (1.0 * y_5) / x_5; end
        if (p > 32'd6) begin t[6] = t_6; r[6] = (1.0 * y_6) / x_6; end
        if (p > 32'd7) begin t[7] = t_7; r[7] = (1.0 * y_7) / x_7; end
        
        // Dynamic programming calculation
        for (i = 0; i < p; i = i + 1) begin
            real candidate;
            candidate = t[i] + c;
            for (j = 0; j < i; j = j + 1) begin
                real temp;
                temp = dp[j] + (t[i] - t[j]) * r[j] + c;
                if (temp < candidate) candidate = temp;
            end
            dp[i] = candidate;
        end
        
        // Compute maximum lifespan
        max_lifespan = n;
        for (i = 0; i < p; i = i + 1) begin
            real lifespan;
            lifespan = t[i] + (n - dp[i]) / r[i];
            if (lifespan > max_lifespan) max_lifespan = lifespan;
        end
    end

    assign result = max_lifespan;

endmodule