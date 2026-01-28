module TicketPurchaser(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] trip_zone,
    input wire [31:0] trip_time,
    input wire trip_valid,
    input wire trip_done,
    output reg ready,
    output reg [15:0] min_cost,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FETCH     = 3'd1;
    localparam [2:0] CALC      = 3'd2;
    localparam [2:0] WRITE     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // DP table dimensions
    localparam [3:0] NUM_ZONES = 4'd11;
    localparam [3:0] MAX_TRIPS = 4'd1000;

    // State registers
    reg [2:0] state, next_state;
    reg [3:0] current_zone;
    reg [31:0] current_time;
    reg [9:0] trip_counter;
    reg [3:0] prev_zone;

    // DP tables (ping-pong buffers)
    reg [15:0] dp_table_0 [0:10][0:10];
    reg [15:0] dp_table_1 [0:10][0:10];
    reg [15:0] dp_table_2 [0:10][0:10];
    reg [15:0] dp_table_3 [0:10][0:10];
    reg [15:0] dp_table_4 [0:10][0:10];
    reg [15:0] dp_table_5 [0:10][0:10];
    reg [15:0] dp_table_6 [0:10][0:10];
    reg [15:0] dp_table_7 [0:10][0:10];
    reg [15:0] dp_table_8 [0:10][0:10];
    reg [15:0] dp_table_9 [0:10][0:10];
    reg [15:0] dp_table_10 [0:10][0:10];

    reg [1:0] current_table;
    reg [1:0] next_table;

    // Ticket validity tracking
    reg [31:0] last_ticket_time [0:10];

    // Ticket cost LUT
    reg [15:0] ticket_cost [0:10][0:10];

    // Temporary registers for computation
    reg [15:0] min_temp;
    reg [15:0] cost_temp;
    reg [15:0] new_cost;
    reg [3:0] i;
    reg [3:0] j;

    // Initialize ticket cost LUT
    integer k, l;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 11; k = k + 1) begin
                for (l = 0; l < 11; l = l + 1) begin
                    ticket_cost[k][l] <= 2 + (k > l ? (k - l) : (l - k));
                end
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            ready <= 1'b0;
            done <= 1'b0;
            min_cost <= 16'd0;
            trip_counter <= 10'd0;
            current_table <= 2'd0;
            next_table <= 2'd1;

            // Initialize DP tables
            for (i = 0; i < 11; i = i + 1) begin
                for (j = 0; j < 11; j = j + 1) begin
                    case (current_table)
                        2'd0: dp_table_0[i][j] <= 16'd0;
                        2'd1: dp_table_1[i][j] <= 16'd0;
                        2'd2: dp_table_2[i][j] <= 16'd0;
                        2'd3: dp_table_3[i][j] <= 16'd0;
                        2'd4: dp_table_4[i][j] <= 16'd0;
                        2'd5: dp_table_5[i][j] <= 16'd0;
                        2'd6: dp_table_6[i][j] <= 16'd0;
                        2'd7: dp_table_7[i][j] <= 16'd0;
                        2'd8: dp_table_8[i][j] <= 16'd0;
                        2'd9: dp_table_9[i][j] <= 16'd0;
                        2'd10: dp_table_10[i][j] <= 16'd0;
                    endcase
                end
            end

            // Initialize last ticket times
            for (i = 0; i < 11; i = i + 1) begin
                last_ticket_time[i] <= 32'd0;
            end

        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FETCH;
                end else begin
                    next_state = IDLE;
                end
            end

            FETCH: begin
                if (trip_valid) begin
                    next_state = CALC;
                end else begin
                    next_state = FETCH;
                end
            end

            CALC: begin
                next_state = WRITE;
            end

            WRITE: begin
                if (trip_done) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = FETCH;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Ready signal
    always @(*) begin
        case (state)
            IDLE: ready = 1'b1;
            FETCH: ready = 1'b0;
            CALC: ready = 1'b0;
            WRITE: ready = 1'b1;
            DONE_STATE: ready = 1'b1;
            default: ready = 1'b0;
        endcase
    end

    // Fetch trip data
    always @(posedge clk) begin
        if (state == FETCH && trip_valid) begin
            current_zone <= trip_zone;
            current_time <= trip_time;
            trip_counter <= trip_counter + 10'd1;
        end
    end

    // Calculate new DP row
    always @(posedge clk) begin
        if (state == CALC) begin
            // Initialize min_temp to maximum value
            min_temp <= 16'hFFFF;

            // Find minimum cost from previous zones
            for (i = 0; i < 11; i = i + 1) begin
                // Get cost from previous table
                case (current_table)
                    2'd0: cost_temp = dp_table_0[i][current_zone];
                    2'd1: cost_temp = dp_table_1[i][current_zone];
                    2'd2: cost_temp = dp_table_2[i][current_zone];
                    2'd3: cost_temp = dp_table_3[i][current_zone];
                    2'd4: cost_temp = dp_table_4[i][current_zone];
                    2'd5: cost_temp = dp_table_5[i][current_zone];
                    2'd6: cost_temp = dp_table_6[i][current_zone];
                    2'd7: cost_temp = dp_table_7[i][current_zone];
                    2'd8: cost_temp = dp_table_8[i][current_zone];
                    2'd9: cost_temp = dp_table_9[i][current_zone];
                    2'd10: cost_temp = dp_table_10[i][current_zone];
                endcase

                // Check ticket validity
                if (current_time - last_ticket_time[i] < 32'd10000) begin
                    // Ticket still valid, no additional cost
                    new_cost = cost_temp;
                end else begin
                    // Need to buy new ticket
                    new_cost = cost_temp + ticket_cost[i][current_zone];
                end

                // Update minimum
                if (new_cost < min_temp) begin
                    min_temp <= new_cost;
                    prev_zone <= i;
                end
            end
        end
    end

    // Write to DP table
    always @(posedge clk) begin
        if (state == WRITE) begin
            // Update the new DP table
            case (next_table)
                2'd0: dp_table_0[prev_zone][current_zone] <= min_temp;
                2'd1: dp_table_1[prev_zone][current_zone] <= min_temp;
                2'd2: dp_table_2[prev_zone][current_zone] <= min_temp;
                2'd3: dp_table_3[prev_zone][current_zone] <= min_temp;
                2'd4: dp_table_4[prev_zone][current_zone] <= min_temp;
                2'd5: dp_table_5[prev_zone][current_zone] <= min_temp;
                2'd6: dp_table_6[prev_zone][current_zone] <= min_temp;
                2'd7: dp_table_7[prev_zone][current_zone] <= min_temp;
                2'd8: dp_table_8[prev_zone][current_zone] <= min_temp;
                2'd9: dp_table_9[prev_zone][current_zone] <= min_temp;
                2'd10: dp_table_10[prev_zone][current_zone] <= min_temp;
            endcase

            // Update last ticket time for current zone
            last_ticket_time[current_zone] <= current_time;

            // Swap tables
            current_table <= next_table;
            next_table <= next_table + 2'd1;
            if (next_table == 2'd11) begin
                next_table <= 2'd0;
            end
        end
    end

    // Final cost calculation
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            // Find minimum cost in final DP table
            min_temp <= 16'hFFFF;
            for (i = 0; i < 11; i = i + 1) begin
                case (current_table)
                    2'd0: cost_temp = dp_table_0[i][current_zone];
                    2'd1: cost_temp = dp_table_1[i][current_zone];
                    2'd2: cost_temp = dp_table_2[i][current_zone];
                    2'd3: cost_temp = dp_table_3[i][current_zone];
                    2'd4: cost_temp = dp_table_4[i][current_zone];
                    2'd5: cost_temp = dp_table_5[i][current_zone];
                    2'd6: cost_temp = dp_table_6[i][current_zone];
                    2'd7: cost_temp = dp_table_7[i][current_zone];
                    2'd8: cost_temp = dp_table_8[i][current_zone];
                    2'd9: cost_temp = dp_table_9[i][current_zone];
                    2'd10: cost_temp = dp_table_10[i][current_zone];
                endcase

                if (cost_temp < min_temp) begin
                    min_temp <= cost_temp;
                end
            end

            min_cost <= min_temp;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule