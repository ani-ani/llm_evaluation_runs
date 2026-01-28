module transportation_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [3:0] k,
    input wire [17:0] t [0:15],
    output reg [17:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] SORT      = 4'd1;
    localparam [3:0] BIN_SEARCH = 4'd2;
    localparam [3:0] FINISH    = 4'd3;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Binary search variables
    reg [17:0] low;
    reg [17:0] high;
    reg [17:0] mid;
    reg [17:0] best_time;
    reg [3:0] search_iter;
    localparam [3:0] MAX_ITER = 4'd9;

    // Sorted times array
    reg [17:0] sorted_t [0:15];

    // Sorting network for 16 elements
    reg [4:0] sort_i;
    reg [4:0] sort_j;
    reg [4:0] sort_k;

    // Feasibility check variables
    reg [17:0] total_capacity;
    reg [4:0] driver_idx;
    reg [17:0] round_trips;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 18'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            low <= 18'd0;
            high <= 18'd262143;
            mid <= 18'd0;
            best_time <= 18'd0;
            search_iter <= 4'd0;
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            sort_k <= 5'd0;
            driver_idx <= 5'd0;
            total_capacity <= 18'd0;
            round_trips <= 18'd0;
            // Initialize sorted array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                sorted_t[i] <= 18'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SORT;
                        // Initialize sorting
                        sort_i <= 5'd0;
                        sort_j <= 5'd0;
                        sort_k <= 5'd0;
                        // Copy input to sorted array
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            sorted_t[i] <= t[i];
                        end
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Bubble sort implementation
                    if (sort_i < 16) begin
                        if (sort_j < 15 - sort_i) begin
                            if (sorted_t[sort_j] > sorted_t[sort_j + 1]) begin
                                reg [17:0] temp;
                                temp <= sorted_t[sort_j];
                                sorted_t[sort_j] <= sorted_t[sort_j + 1];
                                sorted_t[sort_j + 1] <= temp;
                            end
                            sort_j <= sort_j + 5'd1;
                        end else begin
                            sort_j <= 5'd0;
                            sort_i <= sort_i + 5'd1;
                        end
                    end else begin
                        state <= BIN_SEARCH;
                        low <= 18'd0;
                        high <= 18'd262143;
                        search_iter <= 4'd0;
                        best_time <= 18'd262143;
                    end
                end

                BIN_SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (search_iter < MAX_ITER) begin
                        mid <= (low + high) >> 1;
                        // Check feasibility for mid
                        total_capacity <= 18'd0;
                        driver_idx <= 5'd0;
                        state <= BIN_SEARCH;
                    end else begin
                        result <= best_time;
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

    // Feasibility check combinational logic
    always @(*) begin
        if (state == BIN_SEARCH && search_iter < MAX_ITER) begin
            total_capacity = 18'd0;
            for (driver_idx = 0; driver_idx < k; driver_idx = driver_idx + 1) begin
                if (sorted_t[driver_idx] > 0) begin
                    round_trips = mid / (sorted_t[driver_idx] << 1);
                    total_capacity = total_capacity + 18'd1 + (18'd4 * round_trips);
                end
            end
            if (total_capacity >= n) begin
                best_time = mid;
                high = mid - 18'd1;
            end else begin
                low = mid + 18'd1;
            end
            search_iter = search_iter + 4'd1;
        end
    end

endmodule