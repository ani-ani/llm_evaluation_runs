module app_installation_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] app_d_i,
    input wire [7:0] app_s_i,
    input wire [3:0] app_idx_i,
    input wire app_valid_i,
    input wire app_done_i,
    output reg [4:0] result_count,
    output reg [3:0] result_order_0,
    output reg [3:0] result_order_1,
    output reg [3:0] result_order_2,
    output reg [3:0] result_order_3,
    output reg [3:0] result_order_4,
    output reg [3:0] result_order_5,
    output reg [3:0] result_order_6,
    output reg [3:0] result_order_7,
    output reg [3:0] result_order_8,
    output reg [3:0] result_order_9,
    output reg [3:0] result_order_10,
    output reg [3:0] result_order_11,
    output reg [3:0] result_order_12,
    output reg [3:0] result_order_13,
    output reg [3:0] result_order_14,
    output reg [3:0] result_order_15,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INPUT_WAIT = 4'd1;
    localparam [3:0] SORT = 4'd2;
    localparam [3:0] DP_INIT = 4'd3;
    localparam [3:0] DP_FILL = 4'd4;
    localparam [3:0] FIND_OPT = 4'd5;
    localparam [3:0] RECONSTRUCT = 4'd6;
    localparam [3:0] OUTPUT = 4'd7;

    // Internal registers
    reg [3:0] state;
    reg [3:0] app_count;
    reg [7:0] app_req [0:15];
    reg [3:0] app_idx [0:15];
    reg [3:0] sorted_idx [0:15];
    reg [7:0] dp_capacity;
    reg [3:0] dp_count;
    reg [3:0] current_app;
    reg [7:0] current_capacity;
    reg [3:0] current_count;
    reg [3:0] best_count;
    reg [7:0] best_capacity;
    reg [3:0] reconstruct_count;
    reg [7:0] reconstruct_capacity;
    reg [3:0] reconstruct_idx;
    reg [3:0] temp_idx;
    reg [7:0] temp_req;
    reg [7:0] temp_req_next;
    reg [3:0] temp_idx_next;
    reg [7:0] max_req;
    reg [3:0] max_idx;
    reg [7:0] req_i;
    reg [7:0] req_j;
    reg [3:0] idx_i;
    reg [3:0] idx_j;
    reg [7:0] new_capacity;
    reg [3:0] new_count;
    reg [7:0] prev_capacity;
    reg [3:0] prev_count;
    reg [3:0] prev_app_idx;
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] k;
    reg [7:0] m;
    reg [7:0] n;
    reg [7:0] p;
    reg [7:0] q;
    reg [7:0] r;
    reg [7:0] s;
    reg [7:0] t;
    reg [7:0] u;
    reg [7:0] v;
    reg [7:0] w;
    reg [7:0] x;
    reg [7:0] y;
    reg [7:0] z;

    // DP table: dp[capacity][count]
    reg dp [0:255][0:16];
    // prev table: prev[capacity][count]
    reg [3:0] prev [0:255][0:16];

    // Installation order storage
    reg [3:0] installation_order [0:15];

    // Cycle counters for sorting and DP
    reg [7:0] sort_cycle;
    reg [7:0] dp_cycle;
    reg [7:0] find_cycle;
    reg [7:0] reconstruct_cycle;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            app_count <= 4'd0;
            done <= 1'b0;
            busy <= 1'b0;
            result_count <= 5'd0;
            result_order_0 <= 4'd0;
            result_order_1 <= 4'd0;
            result_order_2 <= 4'd0;
            result_order_3 <= 4'd0;
            result_order_4 <= 4'd0;
            result_order_5 <= 4'd0;
            result_order_6 <= 4'd0;
            result_order_7 <= 4'd0;
            result_order_8 <= 4'd0;
            result_order_9 <= 4'd0;
            result_order_10 <= 4'd0;
            result_order_11 <= 4'd0;
            result_order_12 <= 4'd0;
            result_order_13 <= 4'd0;
            result_order_14 <= 4'd0;
            result_order_15 <= 4'd0;

            // Initialize DP and prev tables
            for (i = 0; i < 256; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    dp[i][j] <= 1'b0;
                    prev[i][j] <= 4'd0;
                end
            end

            // Initialize app storage
            for (i = 0; i < 16; i = i + 1) begin
                app_req[i] <= 8'd0;
                app_idx[i] <= 4'd0;
                sorted_idx[i] <= 4'd0;
            end

            // Initialize installation order
            for (i = 0; i < 16; i = i + 1) begin
                installation_order[i] <= 4'd0;
            end

            // Initialize cycle counters
            sort_cycle <= 8'd0;
            dp_cycle <= 8'd0;
            find_cycle <= 8'd0;
            reconstruct_cycle <= 8'd0;

            // Initialize DP state variables
            dp_capacity <= 8'd0;
            dp_count <= 4'd0;
            current_app <= 4'd0;
            current_capacity <= 8'd0;
            current_count <= 4'd0;
            best_count <= 4'd0;
            best_capacity <= 8'd0;
            reconstruct_count <= 4'd0;
            reconstruct_capacity <= 8'd0;
            reconstruct_idx <= 4'd0;

            // Initialize temporary variables
            temp_idx <= 4'd0;
            temp_req <= 8'd0;
            temp_req_next <= 8'd0;
            temp_idx_next <= 4'd0;
            max_req <= 8'd0;
            max_idx <= 4'd0;
            req_i <= 8'd0;
            req_j <= 8'd0;
            idx_i <= 4'd0;
            idx_j <= 4'd0;
            new_capacity <= 8'd0;
            new_count <= 4'd0;
            prev_capacity <= 8'd0;
            prev_count <= 4'd0;
            prev_app_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= INPUT_WAIT;
                        busy <= 1'b1;
                        app_count <= 4'd0;
                    end
                end

                INPUT_WAIT: begin
                    if (app_valid_i) begin
                        // Store app data
                        app_req[app_count] <= (app_d_i > app_s_i) ? app_d_i : app_s_i;
                        app_idx[app_count] <= app_idx_i;
                        app_count <= app_count + 4'd1;
                    end
                    if (app_done_i) begin
                        state <= SORT;
                        sort_cycle <= 8'd0;
                    end
                end

                SORT: begin
                    // Bubble sort implementation
                    if (sort_cycle < 8'd240) begin
                        // Outer loop: sort_cycle / 16
                        i <= sort_cycle[7:4];
                        // Inner loop: sort_cycle % 16
                        j <= sort_cycle[3:0];

                        if (j < 15) begin
                            req_i <= app_req[j];
                            req_j <= app_req[j + 1];
                            idx_i <= app_idx[j];
                            idx_j <= app_idx[j + 1];

                            if (req_i > req_j) begin
                                // Swap
                                app_req[j] <= req_j;
                                app_req[j + 1] <= req_i;
                                app_idx[j] <= idx_j;
                                app_idx[j + 1] <= idx_i;
                            end
                        end

                        sort_cycle <= sort_cycle + 8'd1;
                    end else begin
                        // Copy sorted indices
                        for (k = 0; k < 16; k = k + 1) begin
                            sorted_idx[k] <= app_idx[k];
                        end
                        state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    // Initialize DP table
                    dp[0][0] <= 1'b1;
                    for (i = 1; i < 16; i = i + 1) begin
                        dp[0][i] <= 1'b0;
                    end
                    for (i = 1; i < 256; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            dp[i][j] <= 1'b0;
                        end
                    end

                    // Initialize prev table
                    for (i = 0; i < 256; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            prev[i][j] <= 4'd0;
                        end
                    end

                    state <= DP_FILL;
                    current_app <= 4'd0;
                    dp_cycle <= 8'd0;
                end

                DP_FILL: begin
                    if (current_app < app_count) begin
                        if (dp_cycle < 8'd256) begin
                            current_capacity <= 255 - dp_cycle[7:0];
                            if (dp[current_capacity][dp_count]) begin
                                new_capacity <= current_capacity + app_req[current_app];
                                new_count <= dp_count + 4'd1;
                                if (new_capacity <= 255 && new_count <= 15) begin
                                    dp[new_capacity][new_count] <= 1'b1;
                                    prev[new_capacity][new_count] <= current_app;
                                end
                            end
                            dp_cycle <= dp_cycle + 8'd1;
                        end else begin
                            dp_cycle <= 8'd0;
                            current_app <= current_app + 4'd1;
                        end
                    end else begin
                        state <= FIND_OPT;
                        find_cycle <= 8'd0;
                        best_count <= 4'd0;
                        best_capacity <= 8'd0;
                    end
                end

                FIND_OPT: begin
                    if (find_cycle < 8'd256) begin
                        current_capacity <= 255 - find_cycle[7:0];
                        for (i = 15; i >= 1; i = i - 1) begin
                            if (dp[current_capacity][i] && i > best_count) begin
                                best_count <= i;
                                best_capacity <= current_capacity;
                            end
                        end
                        find_cycle <= find_cycle + 8'd1;
                    end else begin
                        state <= RECONSTRUCT;
                        reconstruct_count <= best_count;
                        reconstruct_capacity <= best_capacity;
                        reconstruct_idx <= 4'd0;
                        reconstruct_cycle <= 8'd0;
                    end
                end

                RECONSTRUCT: begin
                    if (reconstruct_count > 0) begin
                        prev_app_idx <= prev[reconstruct_capacity][reconstruct_count];
                        installation_order[reconstruct_idx] <= sorted_idx[prev_app_idx];
                        reconstruct_idx <= reconstruct_idx + 4'd1;
                        reconstruct_capacity <= reconstruct_capacity - app_req[prev_app_idx];
                        reconstruct_count <= reconstruct_count - 4'd1;
                    end else begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_count <= best_count;
                    result_order_0 <= installation_order[0];
                    result_order_1 <= installation_order[1];
                    result_order_2 <= installation_order[2];
                    result_order_3 <= installation_order[3];
                    result_order_4 <= installation_order[4];
                    result_order_5 <= installation_order[5];
                    result_order_6 <= installation_order[6];
                    result_order_7 <= installation_order[7];
                    result_order_8 <= installation_order[8];
                    result_order_9 <= installation_order[9];
                    result_order_10 <= installation_order[10];
                    result_order_11 <= installation_order[11];
                    result_order_12 <= installation_order[12];
                    result_order_13 <= installation_order[13];
                    result_order_14 <= installation_order[14];
                    result_order_15 <= installation_order[15];
                    done <= 1'b1;
                    state <= IDLE;
                    busy <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule