module bus_expenses(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] config_a,
    input wire [7:0] config_b,
    input wire [7:0] config_f,
    input wire [4:0] config_k,
    input wire [11:0] trip_data,
    input wire [15:0] accum_rdata,
    output reg [4:0] accum_addr,
    output reg [15:0] accum_wdata,
    output reg accum_we,
    output reg req_route,
    output reg [15:0] total_cost,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_TRIPS = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    reg [2:0] state, next_state;

    // Trip data parsing
    reg [3:0] src_id, dst_id;
    reg is_trans;

    // Route memory management
    reg [4:0] route_addr;
    reg [15:0] route_costs [0:255];
    reg [7:0] trip_count;
    reg [4:0] k;

    // Sorting variables
    reg [15:0] top_costs [0:299];
    reg [4:0] top_indices [0:299];
    reg [7:0] sort_count;
    reg [7:0] find_count;
    reg [7:0] max_index;
    reg [15:0] max_cost;

    // Previous trip tracking
    reg [3:0] prev_dst;
    reg first_trip;

    // Cost calculation
    reg [15:0] sum_top_k;
    reg [15:0] final_cost;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            trip_count <= 8'd0;
            k <= 5'd0;
            sort_count <= 8'd0;
            find_count <= 8'd0;
            first_trip <= 1'b1;
            sum_top_k <= 16'd0;
            final_cost <= 16'd0;
            req_route <= 1'b0;
            accum_we <= 1'b0;
            accum_addr <= 5'd0;
            accum_wdata <= 16'd0;
            total_cost <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialization handled above
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= READ_TRIPS;
                        trip_count <= 8'd0;
                        k <= config_k;
                        first_trip <= 1'b1;
                        req_route <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ_TRIPS: begin
                    if (req_route) begin
                        // Parse trip data
                        src_id <= trip_data[11:8];
                        dst_id <= trip_data[7:4];
                        is_trans <= trip_data[3];

                        // Determine cost
                        if (first_trip) begin
                            first_trip <= 1'b0;
                        end else begin
                            if (prev_dst == src_id) begin
                                // Transshipment cost
                                route_costs[route_addr] <= route_costs[route_addr] + config_b;
                            end else begin
                                // Regular cost
                                route_costs[route_addr] <= route_costs[route_addr] + config_a;
                            end
                        end

                        // Update route memory
                        if (src_id < dst_id) begin
                            route_addr <= {src_id, dst_id};
                        end else begin
                            route_addr <= {dst_id, src_id};
                        end

                        accum_addr <= route_addr;
                        accum_wdata <= route_costs[route_addr];
                        accum_we <= 1'b1;

                        // Prepare for next trip
                        prev_dst <= dst_id;
                        trip_count <= trip_count + 8'd1;

                        if (trip_count == 8'd299) begin
                            req_route <= 1'b0;
                            next_state <= CALCULATE;
                            sort_count <= 8'd0;
                            find_count <= 8'd0;
                        end
                    end
                end

                CALCULATE: begin
                    // Find top K costs
                    if (find_count < k) begin
                        max_cost <= 16'd0;
                        max_index <= 5'd0;
                        for (integer i = 0; i < 256; i = i + 1) begin
                            if (route_costs[i] > max_cost) begin
                                max_cost <= route_costs[i];
                                max_index <= i;
                            end
                        end

                        top_costs[find_count] <= max_cost;
                        top_indices[find_count] <= max_index;
                        route_costs[max_index] <= 16'd0;
                        find_count <= find_count + 8'd1;
                    end else begin
                        // Calculate final cost
                        for (integer i = 0; i < k; i = i + 1) begin
                            if (top_costs[i] > config_f) begin
                                sum_top_k <= sum_top_k + (top_costs[i] - config_f);
                            end
                        end
                        final_cost <= sum_top_k + (k * config_f);
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    total_cost <= final_cost;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Memory read/write handling
    always @(posedge clk) begin
        if (state == READ_TRIPS && req_route) begin
            accum_addr <= route_addr;
            accum_wdata <= route_costs[route_addr];
            accum_we <= 1'b1;
        end else begin
            accum_we <= 1'b0;
        end
    end

endmodule