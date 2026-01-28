module potato_price_minimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a [0:15],
    input wire [15:0] c [0:15],
    input wire [3:0] N,
    input wire [3:0] L,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] DP_PASS1 = 3'd2;
    localparam [2:0] DP_PASS2 = 3'd3;
    localparam [2:0] CALC    = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [7:0] total_bags;
    reg [15:0] total_price;
    reg [8:0] dp1 [0:511];  // Store1 DP array (min price for bags)
    reg [8:0] dp2 [0:511];  // Store2 DP array (min price for bags)
    reg [31:0] min_product;
    reg [7:0] current_bags;
    reg [15:0] current_price;
    reg [7:0] i_reg, j_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize DP arrays
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            total_bags <= 8'd0;
            total_price <= 16'd0;
            min_product <= 32'd0;
            current_bags <= 8'd0;
            current_price <= 16'd0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            cycle_count <= 8'd0;
            for (k = 0; k < 512; k = k + 1) begin
                dp1[k] <= 8'd0;
                dp2[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                // Compute total bags and total price
                total_bags = 8'd0;
                total_price = 16'd0;
                for (k = 0; k < 16; k = k + 1) begin
                    if (k < N) begin
                        total_bags = total_bags + a[k];
                        total_price = total_price + c[k];
                    end
                end
                next_state = DP_PASS1;
            end

            DP_PASS1: begin
                // Initialize DP array for store1
                for (k = 0; k < 512; k = k + 1) begin
                    dp1[k] = 8'd0;
                end
                dp1[0] = 8'd1;  // Base case: 0 bags with 0 price

                // Fill DP array for store1
                for (i_reg = 0; i_reg < N; i_reg = i_reg + 1) begin
                    for (j_reg = 511; j_reg >= a[i_reg]; j_reg = j_reg - 1) begin
                        if (dp1[j_reg - a[i_reg]]) begin
                            if (!dp1[j_reg] || (dp1[j_reg] > (c[i_reg] >> 8))) begin
                                dp1[j_reg] = c[i_reg] >> 8;
                            end
                        end
                    end
                end
                next_state = DP_PASS2;
            end

            DP_PASS2: begin
                // Initialize DP array for store2
                for (k = 0; k < 512; k = k + 1) begin
                    dp2[k] = 8'd0;
                end
                dp2[0] = 8'd1;  // Base case: 0 bags with 0 price

                // Fill DP array for store2
                for (i_reg = 0; i_reg < N; i_reg = i_reg + 1) begin
                    for (j_reg = 511; j_reg >= a[i_reg]; j_reg = j_reg - 1) begin
                        if (dp2[j_reg - a[i_reg]]) begin
                            if (!dp2[j_reg] || (dp2[j_reg] > (c[i_reg] >> 8))) begin
                                dp2[j_reg] = c[i_reg] >> 8;
                            end
                        end
                    end
                end
                next_state = CALC;
            end

            CALC: begin
                // Calculate minimum product
                min_product = 32'd0;
                for (i_reg = 1; i_reg < 512; i_reg = i_reg + 1) begin
                    if (dp1[i_reg] && (i_reg >= L)) begin
                        for (j_reg = 1; j_reg < 512; j_reg = j_reg + 1) begin
                            if (dp2[j_reg] && (j_reg >= L) && (i_reg + j_reg <= total_bags)) begin
                                // Calculate P1 = price1 / bags1
                                reg [31:0] p1;
                                p1 = (dp1[i_reg] << 16) / i_reg;

                                // Calculate P2 = price2 / bags2
                                reg [31:0] p2;
                                p2 = (dp2[j_reg] << 16) / j_reg;

                                // Calculate product = P1 * P2
                                reg [31:0] product;
                                product = p1 * p2;

                                // Track minimum product
                                if (!min_product || (product < min_product)) begin
                                    min_product = product;
                                end
                            end
                        end
                    end
                end
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done <= 1'b1;
                result <= min_product;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule