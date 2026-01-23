module dj_polygon_gigs (
    input clk,
    input rst_n,
    input start,
    input [4:0] total_gigs,
    input [4:0] total_venues,
    input [31:0] dist_matrix [0:63],
    input [2:0] gig_venue [0:15],
    input [31:0] gig_start [0:15],
    input [31:0] gig_end [0:15],
    input [15:0] gig_money [0:15],
    output reg [15:0] max_earnings,
    output reg done
);

    // Constants
    localparam IDLE = 3'b000;
    localparam SORT = 3'b001;
    localparam DP_INIT = 3'b010;
    localparam DP_OUTER = 3'b011;
    localparam DP_INNER = 3'b100;
    localparam DP_UPDATE = 3'b101;
    localparam DONE = 3'b110;

    // State register
    reg [2:0] state, next_state;

    // Gig sorting
    reg [4:0] sort_i, sort_j;
    reg [31:0] sorted_end [0:15];
    reg [2:0] sorted_venue [0:15];
    reg [31:0] sorted_start [0:15];
    reg [15:0] sorted_money [0:15];

    // DP arrays
    reg [15:0] dp [0:15];
    reg [4:0] dp_i, dp_j;
    reg [15:0] current_max;
    reg [31:0] travel_time;
    reg valid_transition;

    // Counters
    reg [4:0] i, j;
    reg [19:0] cycle_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_earnings <= 0;
            cycle_count <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SORT;
            end
            SORT: begin
                if (cycle_count >= 8) next_state = DP_INIT;
            end
            DP_INIT: begin
                if (i >= total_gigs) next_state = DP_OUTER;
            end
            DP_OUTER: begin
                if (dp_i >= total_gigs) next_state = DONE;
                else if (dp_j >= dp_i) next_state = DP_UPDATE;
                else next_state = DP_INNER;
            end
            DP_INNER: begin
                if (dp_j >= dp_i) next_state = DP_UPDATE;
            end
            DP_UPDATE: begin
                if (dp_j >= dp_i) next_state = DP_OUTER;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sorting logic (bubble sort for simplicity)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_i <= 0;
            sort_j <= 0;
            cycle_count <= 0;
        end else if (state == SORT) begin
            if (cycle_count < 8) begin
                // Bubble sort pass
                for (i = 0; i < total_gigs - 1; i = i + 1) begin
                    if (sorted_end[i] > sorted_end[i+1]) begin
                        // Swap
                        sorted_end[i] <= sorted_end[i+1];
                        sorted_end[i+1] <= sorted_end[i];
                        sorted_venue[i] <= sorted_venue[i+1];
                        sorted_venue[i+1] <= sorted_venue[i];
                        sorted_start[i] <= sorted_start[i+1];
                        sorted_start[i+1] <= sorted_start[i];
                        sorted_money[i] <= sorted_money[i+1];
                        sorted_money[i+1] <= sorted_money[i];
                    end
                end
                cycle_count <= cycle_count + 1;
            end
        end
    end

    // Initialize sorted arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                sorted_end[i] <= 0;
                sorted_venue[i] <= 0;
                sorted_start[i] <= 0;
                sorted_money[i] <= 0;
            end
        end else if (state == SORT && cycle_count == 0) begin
            for (i = 0; i < total_gigs; i = i + 1) begin
                sorted_end[i] <= gig_end[i];
                sorted_venue[i] <= gig_venue[i];
                sorted_start[i] <= gig_start[i];
                sorted_money[i] <= gig_money[i];
            end
        end
    end

    // DP initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            dp_i <= 0;
            dp_j <= 0;
            current_max <= 0;
        end else if (state == DP_INIT) begin
            if (i < total_gigs) begin
                dp[i] <= sorted_money[i];
                i <= i + 1;
            end
        end
    end

    // DP outer loop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_i <= 0;
        end else if (state == DP_OUTER) begin
            if (dp_i < total_gigs) begin
                dp_j <= 0;
                current_max <= 0;
            end
        end
    end

    // DP inner loop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_j <= 0;
        end else if (state == DP_INNER) begin
            if (dp_j < dp_i) begin
                // Calculate travel time
                travel_time = dist_matrix[sorted_venue[dp_j] * 8 + sorted_venue[dp_i]];
                // Check if transition is valid
                valid_transition = (sorted_end[dp_j] + travel_time <= sorted_start[dp_i]) &&
                                  (travel_time != 32'hFFFF_FFFF);
                if (valid_transition && dp[dp_j] > current_max) begin
                    current_max <= dp[dp_j];
                end
                dp_j <= dp_j + 1;
            end
        end
    end

    // DP update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_i <= 0;
        end else if (state == DP_UPDATE) begin
            if (dp_j >= dp_i) begin
                dp[dp_i] <= sorted_money[dp_i] + current_max;
                dp_i <= dp_i + 1;
            end
        end
    end

    // Final result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_earnings <= 0;
            done <= 0;
        end else if (state == DONE) begin
            max_earnings <= 0;
            for (i = 0; i < total_gigs; i = i + 1) begin
                if (dp[i] > max_earnings) begin
                    max_earnings <= dp[i];
                end
            end
            done <= 1;
        end else if (state == IDLE) begin
            done <= 0;
        end
    end

endmodule