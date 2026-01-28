module antique_shopping(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] antique_a [0:7],
    input wire [31:0] antique_p [0:7],
    input wire [2:0] antique_b [0:7],
    input wire [31:0] antique_q [0:7],
    input wire [2:0] k_limit,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SETUP = 4'd1;
    localparam [3:0] ANTIQUE_LOOP = 4'd2;
    localparam [3:0] MASK_LOOP = 4'd3;
    localparam [3:0] UPDATE = 4'd4;
    localparam [3:0] STORE = 4'd5;
    localparam [3:0] CHECK_RESULT = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;

    // Counters
    reg [2:0] antique_idx;
    reg [7:0] mask_idx;
    reg [7:0] result_mask;

    // DP tables (256 entries each)
    reg [31:0] dp_current [0:255];
    reg [31:0] dp_next [0:255];

    // Current antique data
    reg [2:0] current_a;
    reg [31:0] current_p;
    reg [2:0] current_b;
    reg [31:0] current_q;

    // Temporary variables
    reg [31:0] temp_cost;
    reg [7:0] temp_mask;
    reg [7:0] popcount;
    reg [31:0] min_cost;

    // Cycle counter for safety
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2000;

    // Popcount calculation
    function [3:0] calculate_popcount;
        input [7:0] mask;
        reg [3:0] count;
        integer i;
        begin
            count = 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                if (mask[i])
                    count = count + 4'd1;
            end
            calculate_popcount = count;
        end
    endfunction

    // Initialize DP tables
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            antique_idx <= 3'd0;
            mask_idx <= 8'd0;
            result_mask <= 8'd0;
            current_a <= 3'd0;
            current_p <= 32'd0;
            current_b <= 3'd0;
            current_q <= 32'd0;
            temp_cost <= 32'd0;
            temp_mask <= 8'd0;
            popcount <= 4'd0;
            min_cost <= 32'd0;
            cycle_count <= 12'd0;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // FSM logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end
            end

            SETUP: begin
                next_state = ANTIQUE_LOOP;
            end

            ANTIQUE_LOOP: begin
                if (antique_idx == 3'd7) begin
                    next_state = CHECK_RESULT;
                end else begin
                    next_state = MASK_LOOP;
                end
            end

            MASK_LOOP: begin
                if (mask_idx == 8'd255) begin
                    next_state = ANTIQUE_LOOP;
                end else begin
                    next_state = UPDATE;
                end
            end

            UPDATE: begin
                next_state = STORE;
            end

            STORE: begin
                if (mask_idx == 8'd255) begin
                    next_state = ANTIQUE_LOOP;
                end else begin
                    next_state = MASK_LOOP;
                end
            end

            CHECK_RESULT: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // DP table initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                dp_current[i] <= 32'd4294967295; // Initialize to max value (0xFFFFFFFF)
                dp_next[i] <= 32'd4294967295;
            end
            dp_current[0] <= 32'd0; // dp[0][0] = 0
        end else if (state == SETUP) begin
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                dp_current[i] <= 32'd4294967295;
                dp_next[i] <= 32'd4294967295;
            end
            dp_current[0] <= 32'd0;
        end
    end

    // Load current antique data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_a <= 3'd0;
            current_p <= 32'd0;
            current_b <= 3'd0;
            current_q <= 32'd0;
        end else if (state == ANTIQUE_LOOP) begin
            current_a <= antique_a[antique_idx];
            current_p <= antique_p[antique_idx];
            current_b <= antique_b[antique_idx];
            current_q <= antique_q[antique_idx];
        end
    end

    // Update DP table
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_cost <= 32'd0;
            temp_mask <= 8'd0;
        end else if (state == UPDATE) begin
            // Option 1: Buy original
            temp_mask = mask_idx | (1 << current_a);
            if (dp_current[mask_idx] != 32'd4294967295) begin
                temp_cost = dp_current[mask_idx] + current_p;
                if (temp_cost < dp_next[temp_mask]) begin
                    dp_next[temp_mask] <= temp_cost;
                end
            end

            // Option 2: Buy knockoff
            temp_mask = mask_idx | (1 << current_b);
            if (dp_current[mask_idx] != 32'd4294967295) begin
                temp_cost = dp_current[mask_idx] + current_q;
                if (temp_cost < dp_next[temp_mask]) begin
                    dp_next[temp_mask] <= temp_cost;
                end
            end
        end
    end

    // Store back to dp_current
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset
        end else if (state == STORE) begin
            dp_current[mask_idx] <= dp_next[mask_idx];
        end
    end

    // Check result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_cost <= 32'd0;
            result_mask <= 8'd0;
        end else if (state == CHECK_RESULT) begin
            min_cost = 32'd4294967295;
            result_mask = 8'd0;
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                popcount = calculate_popcount(i);
                if (popcount <= k_limit && dp_current[i] < min_cost) begin
                    min_cost = dp_current[i];
                    result_mask = i;
                end
            end
            if (min_cost == 32'd4294967295) begin
                result <= 32'd4294967295; // -1 if no solution
            end else begin
                result <= min_cost;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 12'd0;
        end else if (cycle_count >= MAX_CYCLES) begin
            cycle_count <= 12'd0;
            state <= IDLE;
        end else begin
            cycle_count <= cycle_count + 12'd1;
        end
    end

    // Antique index counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            antique_idx <= 3'd0;
        end else if (state == ANTIQUE_LOOP && next_state == MASK_LOOP) begin
            antique_idx <= antique_idx + 3'd1;
        end else if (state == SETUP) begin
            antique_idx <= 3'd0;
        end
    end

    // Mask index counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask_idx <= 8'd0;
        end else if (state == MASK_LOOP && next_state == UPDATE) begin
            mask_idx <= mask_idx + 8'd1;
        end else if (state == STORE && next_state == MASK_LOOP) begin
            mask_idx <= mask_idx + 8'd1;
        end else if (state == ANTIQUE_LOOP || state == SETUP) begin
            mask_idx <= 8'd0;
        end
    end

endmodule