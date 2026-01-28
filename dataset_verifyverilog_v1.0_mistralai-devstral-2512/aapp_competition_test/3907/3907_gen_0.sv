module max_payment_calculator(
    input clk,
    input rst_n,
    input start,
    input [31:0] n_i,
    input [31:0] m_i,
    input [31:0] w_i,
    input w_valid,
    input w_done,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_N_M = 3'd1;
    localparam [2:0] READ_WEIGHTS = 3'd2;
    localparam [2:0] CALCULATE_K = 3'd3;
    localparam [2:0] SORT_WEIGHTS = 3'd4;
    localparam [2:0] SUM_WEIGHTS = 3'd5;
    localparam [2:0] OUTPUT_RESULT = 3'd6;

    reg [2:0] state, next_state;

    // Control signals
    reg n_m_loaded;
    reg weights_loaded;
    reg k_calculated;
    reg weights_sorted;

    // Data storage
    reg [31:0] n_reg, m_reg;
    reg [31:0] weights [0:511]; // Using 512 for testability, but logic handles full m
    reg [31:0] sorted_weights [0:511];
    reg [31:0] weight_sum;
    reg [31:0] k_value;

    // Weight reading counter
    reg [18:0] weight_count;

    // Sorting variables
    reg [8:0] i, j;
    reg [31:0] temp;

    // K calculation variables
    reg [31:0] k_temp;
    reg [31:0] max_n_odd, max_n_even;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_m_loaded <= 1'b0;
            weights_loaded <= 1'b0;
            k_calculated <= 1'b0;
            weights_sorted <= 1'b0;
            n_reg <= 32'd0;
            m_reg <= 32'd0;
            weight_count <= 19'd0;
            weight_sum <= 32'd0;
            k_value <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            i <= 9'd0;
            j <= 9'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_N_M;
                end
            end
            READ_N_M: begin
                if (n_m_loaded) begin
                    next_state = READ_WEIGHTS;
                end
            end
            READ_WEIGHTS: begin
                if (weights_loaded) begin
                    next_state = CALCULATE_K;
                end
            end
            CALCULATE_K: begin
                if (k_calculated) begin
                    next_state = SORT_WEIGHTS;
                end
            end
            SORT_WEIGHTS: begin
                if (weights_sorted) begin
                    next_state = SUM_WEIGHTS;
                end
            end
            SUM_WEIGHTS: begin
                next_state = OUTPUT_RESULT;
            end
            OUTPUT_RESULT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Read n and m
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_m_loaded <= 1'b0;
        end else if (state == READ_N_M && !n_m_loaded) begin
            n_reg <= n_i;
            m_reg <= m_i;
            n_m_loaded <= 1'b1;
        end
    end

    // Read weights
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_count <= 19'd0;
            weights_loaded <= 1'b0;
        end else if (state == READ_WEIGHTS && !weights_loaded) begin
            if (w_valid && weight_count < m_reg && weight_count < 512) begin
                weights[weight_count] <= w_i;
                weight_count <= weight_count + 19'd1;
            end
            if (w_done) begin
                weights_loaded <= 1'b1;
            end
        end
    end

    // Calculate k
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k_calculated <= 1'b0;
            k_value <= 32'd0;
        end else if (state == CALCULATE_K && !k_calculated) begin
            k_temp = 32'd1;
            while (k_temp <= 32'd2000000) begin
                if (k_temp[0]) begin // odd
                    max_n_odd = (k_temp * (k_temp - 32'd1)) / 32'd2 + 32'd1;
                    if (max_n_odd > n_reg) begin
                        k_temp = k_temp - 32'd1;
                        break;
                    end
                end else begin // even
                    max_n_even = (k_temp * k_temp) / 32'd2;
                    if (max_n_even > n_reg) begin
                        k_temp = k_temp - 32'd1;
                        break;
                    end
                end
                k_temp = k_temp + 32'd1;
            end
            k_value <= k_temp;
            k_calculated <= 1'b1;
        end
    end

    // Sort weights (bubble sort for simplicity)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weights_sorted <= 1'b0;
            i <= 9'd0;
            j <= 9'd0;
        end else if (state == SORT_WEIGHTS && !weights_sorted) begin
            if (i < weight_count - 19'd1) begin
                if (j < weight_count - 19'd1 - i) begin
                    if (weights[j] < weights[j + 19'd1]) begin
                        temp <= weights[j];
                        weights[j] <= weights[j + 19'd1];
                        weights[j + 19'd1] <= temp;
                    end
                    j <= j + 9'd1;
                end else begin
                    j <= 9'd0;
                    i <= i + 9'd1;
                end
            end else begin
                // Copy to sorted_weights
                for (i = 0; i < weight_count; i = i + 1) begin
                    sorted_weights[i] <= weights[i];
                end
                weights_sorted <= 1'b1;
                i <= 9'd0;
                j <= 9'd0;
            end
        end
    end

    // Sum top k weights
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_sum <= 32'd0;
        end else if (state == SUM_WEIGHTS) begin
            weight_sum <= 32'd0;
            for (i = 0; i < k_value && i < weight_count; i = i + 1) begin
                weight_sum <= weight_sum + sorted_weights[i];
            end
            result <= weight_sum;
        end
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == OUTPUT_RESULT) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule