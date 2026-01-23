module mad_calculator (
    input clk,
    input rst_n,
    input start,
    input [15:0] grid_data,
    input grid_valid,
    output reg [31:0] result,
    output reg done,
    output reg [5:0] state_out
);

    // Parameters
    localparam IDLE = 6'd0;
    localparam LOAD = 6'd1;
    localparam CALC_DENSITIES = 6'd2;
    localparam SORT = 6'd3;
    localparam MEDIAN = 6'd4;
    localparam DONE = 6'd5;

    // Grid storage
    reg [15:0] grid [0:3][0:3];
    reg [3:0] grid_row;
    reg [3:0] grid_col;
    reg [3:0] grid_count;

    // Density calculation
    reg [31:0] densities [0:47];
    reg [5:0] density_count;
    reg [3:0] r1, c1, r2, c2;
    reg [31:0] sum;
    reg [31:0] area;
    reg [31:0] density;

    // Sorting
    reg [5:0] i, j;
    reg [31:0] temp;

    // Median calculation
    reg [31:0] median;

    // State machine
    reg [5:0] state;
    reg [5:0] next_state;

    // Control signals
    reg load_complete;
    reg calc_complete;
    reg sort_complete;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            state_out <= IDLE;
        end else begin
            state <= next_state;
            state_out <= state;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            LOAD: begin
                if (load_complete) begin
                    next_state = CALC_DENSITIES;
                end else begin
                    next_state = LOAD;
                end
            end
            CALC_DENSITIES: begin
                if (calc_complete) begin
                    next_state = SORT;
                end else begin
                    next_state = CALC_DENSITIES;
                end
            end
            SORT: begin
                if (sort_complete) begin
                    next_state = MEDIAN;
                end else begin
                    next_state = SORT;
                end
            end
            MEDIAN: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Load grid data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grid_row <= 0;
            grid_col <= 0;
            grid_count <= 0;
            load_complete <= 0;
        end else begin
            if (state == LOAD) begin
                if (grid_valid) begin
                    grid[grid_row][grid_col] <= grid_data;
                    grid_col <= grid_col + 1;
                    if (grid_col == 4) begin
                        grid_col <= 0;
                        grid_row <= grid_row + 1;
                    end
                    grid_count <= grid_count + 1;
                    if (grid_count == 15) begin
                        load_complete <= 1;
                    end
                end
            end else begin
                load_complete <= 0;
            end
        end
    end

    // Calculate densities
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r1 <= 0;
            c1 <= 0;
            r2 <= 0;
            c2 <= 0;
            density_count <= 0;
            calc_complete <= 0;
        end else begin
            if (state == CALC_DENSITIES) begin
                if (density_count < 48) begin
                    // Calculate sum and area
                    sum = 0;
                    area = (r2 - r1 + 1) * (c2 - c1 + 1);
                    if (area >= 1 && area <= 8) begin
                        for (int i = r1; i <= r2; i = i + 1) begin
                            for (int j = c1; j <= c2; j = j + 1) begin
                                sum = sum + grid[i][j];
                            end
                        end
                        density = (sum << 16) / area;
                        densities[density_count] = density;
                        density_count = density_count + 1;
                    end
                    // Move to next rectangle
                    c2 = c2 + 1;
                    if (c2 == 4) begin
                        c2 = c1;
                        r2 = r2 + 1;
                        if (r2 == 4) begin
                            r2 = r1;
                            c1 = c1 + 1;
                            if (c1 == 4) begin
                                c1 = 0;
                                r1 = r1 + 1;
                                if (r1 == 4) begin
                                    calc_complete = 1;
                                end
                            end
                        end
                    end
                end
            end else begin
                calc_complete <= 0;
            end
        end
    end

    // Sort densities using bubble sort
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            j <= 0;
            sort_complete <= 0;
        end else begin
            if (state == SORT) begin
                if (i < density_count - 1) begin
                    if (j < density_count - i - 1) begin
                        if (densities[j] > densities[j + 1]) begin
                            temp = densities[j];
                            densities[j] = densities[j + 1];
                            densities[j + 1] = temp;
                        end
                        j = j + 1;
                    end else begin
                        j = 0;
                        i = i + 1;
                    end
                end else begin
                    sort_complete = 1;
                end
            end else begin
                sort_complete <= 0;
            end
        end
    end

    // Calculate median
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            median <= 0;
        end else begin
            if (state == MEDIAN) begin
                if (density_count % 2 == 1) begin
                    median = densities[density_count / 2];
                end else begin
                    median = (densities[density_count / 2 - 1] + densities[density_count / 2]) >> 1;
                end
                result <= median;
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end

endmodule