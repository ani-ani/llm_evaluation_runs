module TravelCardOptimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [3:0] k,
    input wire [15:0] f,
    input wire [2:0] n,
    input wire [31:0] stop1,
    input wire [31:0] stop2,
    output reg [15:0] total_cost,
    output reg done
);

    // Internal memory for route table (max 8 routes)
    reg [31:0] route_start [0:7];
    reg [31:0] route_end [0:7];
    reg [15:0] route_cost [0:7];
    reg [2:0] route_count;

    // State machine states
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS_TRIP = 4'd1;
    localparam [3:0] UPDATE_ROUTES = 4'd2;
    localparam [3:0] SORT_INIT = 4'd3;
    localparam [3:0] SORT_COMPARE = 4'd4;
    localparam [3:0] SORT_SWAP = 4'd5;
    localparam [3:0] SORT_NEXT = 4'd6;
    localparam [3:0] APPLY_CARDS = 4'd7;
    localparam [3:0] FINISH = 4'd8;

    reg [3:0] state;
    reg [2:0] trip_idx;
    reg [31:0] last_end_stop;
    reg [31:0] curr_start, curr_end;
    reg [15:0] current_cost;
    reg [2:0] sort_i, sort_j;
    reg [2:0] card_idx;
    reg [15:0] temp_cost;
    reg [31:0] temp_start, temp_end;

    integer i;
    integer r;
    reg [2:0] route_idx;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            total_cost <= 16'd0;
            route_count <= 3'd0;
            trip_idx <= 3'd0;
            last_end_stop <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                route_cost[i] <= 16'd0;
                route_start[i] <= 32'd0;
                route_end[i] <= 32'd0;
            end
            curr_start <= 32'd0;
            curr_end <= 32'd0;
            current_cost <= 16'd0;
            sort_i <= 3'd0;
            sort_j <= 3'd0;
            card_idx <= 3'd0;
            temp_cost <= 16'd0;
            temp_start <= 32'd0;
            temp_end <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && n > 3'd0) begin
                        state <= PROCESS_TRIP;
                        trip_idx <= 3'd0;
                        route_count <= 3'd0;
                        last_end_stop <= 32'd0;
                        total_cost <= 16'd0;
                    end
                end

                PROCESS_TRIP: begin
                    curr_start <= stop1;
                    curr_end <= stop2;
                    if (stop1 == last_end_stop) begin
                        current_cost <= {8'd0, b};
                    end else begin
                        current_cost <= {8'd0, a};
                    end
                    state <= UPDATE_ROUTES;
                end

                UPDATE_ROUTES: begin
                    total_cost <= total_cost + current_cost;
                    
                    // Find existing route
                    found <= 1'b0;
                    for (r = 0; r < 8; r = r + 1) begin
                        if (r < route_count) begin
                            if ((route_start[r] == curr_start && route_end[r] == curr_end) ||
                                (route_start[r] == curr_end && route_end[r] == curr_start)) begin
                                found <= 1'b1;
                                route_idx <= r;
                            end
                        end
                    end
                    
                    if (found) begin
                        route_cost[route_idx] <= route_cost[route_idx] + current_cost;
                    end else if (route_count < 8) begin
                        if (curr_start < curr_end) begin
                            route_start[route_count] <= curr_start;
                            route_end[route_count] <= curr_end;
                        end else begin
                            route_start[route_count] <= curr_end;
                            route_end[route_count] <= curr_start;
                        end
                        route_cost[route_count] <= current_cost;
                        route_count <= route_count + 1;
                    end
                    
                    last_end_stop <= curr_end;
                    
                    if (trip_idx + 1 >= n) begin
                        state <= SORT_INIT;
                        sort_i <= 3'd0;
                        sort_j <= 3'd0;
                    end else begin
                        state <= PROCESS_TRIP;
                        trip_idx <= trip_idx + 1;
                    end
                end

                SORT_INIT: begin
                    sort_i <= 3'd0;
                    sort_j <= 3'd0;
                    state <= SORT_COMPARE;
                end

                SORT_COMPARE: begin
                    if (sort_j < route_count - sort_i - 1) begin
                        if (route_cost[sort_j] < route_cost[sort_j + 1]) begin
                            state <= SORT_SWAP;
                        end else begin
                            sort_j <= sort_j + 1;
                        end
                    end else begin
                        sort_i <= sort_i + 1;
                        sort_j <= 3'd0;
                        if (sort_i >= route_count - 1) begin
                            state <= APPLY_CARDS;
                            card_idx <= 3'd0;
                        end
                    end
                end

                SORT_SWAP: begin
                    temp_cost <= route_cost[sort_j];
                    temp_start <= route_start[sort_j];
                    temp_end <= route_end[sort_j];
                    
                    route_cost[sort_j] <= route_cost[sort_j + 1];
                    route_start[sort_j] <= route_start[sort_j + 1];
                    route_end[sort_j] <= route_end[sort_j + 1];
                    
                    route_cost[sort_j + 1] <= temp_cost;
                    route_start[sort_j + 1] <= temp_start;
                    route_end[sort_j + 1] <= temp_end;
                    
                    sort_j <= sort_j + 1;
                    state <= SORT_COMPARE;
                end

                APPLY_CARDS: begin
                    if (card_idx < route_count && card_idx < k) begin
                        if (route_cost[card_idx] > f) begin
                            total_cost <= total_cost - (route_cost[card_idx] - f);
                        end
                        card_idx <= card_idx + 1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule