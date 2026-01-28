module BulkheadCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] min_area,
    input wire [15:0] vertex_x,
    input wire [15:0] vertex_y,
    input wire vertex_valid,
    input wire vertex_done,
    output reg busy,
    output reg [7:0] max_sections,
    output reg [31:0] result,
    output reg result_valid,
    output reg result_done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_VERTICES = 3'd1;
    localparam [2:0] COMPUTE_AREA = 3'd2;
    localparam [2:0] DETERMINE_M = 3'd3;
    localparam [2:0] SWEEP_X = 3'd4;
    localparam [2:0] OUTPUT_RESULTS = 3'd5;
    localparam [2:0] DONE = 3'd6;

    reg [2:0] state, next_state;

    // Vertex storage (16 vertices max)
    reg [15:0] x [0:15];
    reg [15:0] y [0:15];
    reg [3:0] vertex_count;

    // Area calculation
    reg signed [63:0] area_accum;
    reg signed [31:0] total_area;

    // Section calculation
    reg [7:0] M;
    reg signed [31:0] section_area;

    // Sweep variables
    reg [15:0] min_x, max_x;
    reg [15:0] current_x;
    reg signed [31:0] accumulated_area;
    reg [7:0] section_index;
    reg [15:0] edge_start_x, edge_end_x;
    reg [15:0] edge_start_y, edge_end_y;
    reg [3:0] edge_index;

    // Result output
    reg [31:0] bulkhead_x [0:99];
    reg [7:0] bulkhead_count;

    // Cycle counter for safety
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd5000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            busy <= 1'b0;
            max_sections <= 8'd0;
            result <= 32'd0;
            result_valid <= 1'b0;
            result_done <= 1'b0;
            vertex_count <= 4'd0;
            area_accum <= 64'd0;
            total_area <= 32'd0;
            M <= 8'd0;
            section_area <= 32'd0;
            min_x <= 16'd0;
            max_x <= 16'd0;
            current_x <= 16'd0;
            accumulated_area <= 32'd0;
            section_index <= 8'd0;
            edge_start_x <= 16'd0;
            edge_end_x <= 16'd0;
            edge_start_y <= 16'd0;
            edge_end_y <= 16'd0;
            edge_index <= 4'd0;
            bulkhead_count <= 8'd0;
            cycle_count <= 13'd0;

            // Initialize vertex arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                x[i] <= 16'd0;
                y[i] <= 16'd0;
            end

            // Initialize bulkhead array
            for (i = 0; i < 100; i = i + 1) begin
                bulkhead_x[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 13'd1;

            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                busy <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = STORE_VERTICES;
                    busy = 1'b1;
                end
            end

            STORE_VERTICES: begin
                if (vertex_done) begin
                    next_state = COMPUTE_AREA;
                end
            end

            COMPUTE_AREA: begin
                next_state = DETERMINE_M;
            end

            DETERMINE_M: begin
                next_state = SWEEP_X;
            end

            SWEEP_X: begin
                if (section_index >= M - 1) begin
                    next_state = OUTPUT_RESULTS;
                end
            end

            OUTPUT_RESULTS: begin
                if (result_done) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
                busy = 1'b0;
            end

            default: next_state = IDLE;
        endcase
    end

    // Vertex storage
    always @(posedge clk) begin
        if (state == STORE_VERTICES && vertex_valid) begin
            if (vertex_count < 16) begin
                x[vertex_count] <= vertex_x;
                y[vertex_count] <= vertex_y;
                vertex_count <= vertex_count + 4'd1;
            end
        end
    end

    // Area calculation
    always @(posedge clk) begin
        if (state == COMPUTE_AREA) begin
            integer i;
            area_accum <= 64'd0;

            for (i = 0; i < vertex_count - 1; i = i + 1) begin
                area_accum <= area_accum + ($signed(x[i]) * $signed(y[i+1])) - ($signed(x[i+1]) * $signed(y[i]));
            end

            // Close the polygon
            area_accum <= area_accum + ($signed(x[vertex_count-1]) * $signed(y[0])) - ($signed(x[0]) * $signed(y[vertex_count-1]));

            // Divide by 2 (fixed-point)
            total_area <= area_accum[31:0] / 2;

            // Find min and max x
            min_x <= x[0];
            max_x <= x[0];
            for (i = 1; i < vertex_count; i = i + 1) begin
                if ($signed(x[i]) < $signed(min_x)) begin
                    min_x <= x[i];
                end
                if ($signed(x[i]) > $signed(max_x)) begin
                    max_x <= x[i];
                end
            end
        end
    end

    // Determine M
    always @(posedge clk) begin
        if (state == DETERMINE_M) begin
            integer m;
            for (m = 100; m >= 1; m = m - 1) begin
                if ($signed(total_area) / $signed(m) >= $signed(min_area)) begin
                    M <= m;
                    break;
                end
            end

            if (M == 0) begin
                M <= 1;
            end

            max_sections <= M;
            section_area <= $signed(total_area) / $signed(M);
        end
    end

    // Sweep X and find bulkheads
    always @(posedge clk) begin
        if (state == SWEEP_X) begin
            if (section_index < M - 1) begin
                integer i;
                accumulated_area <= 32'd0;
                current_x <= min_x;

                // Find the section we're targeting
                reg signed [31:0] target_area;
                target_area <= $signed(section_index + 1) * $signed(section_area);

                // Sweep through edges
                for (i = 0; i < vertex_count - 1; i = i + 1) begin
                    edge_start_x <= x[i];
                    edge_end_x <= x[i+1];
                    edge_start_y <= y[i];
                    edge_end_y <= y[i+1];

                    // Calculate area contribution
                    reg signed [31:0] edge_area;
                    edge_area <= 32'd0;

                    // Simple trapezoid approximation
                    if ($signed(edge_start_x) != $signed(edge_end_x)) begin
                        reg signed [31:0] dx, dy;
                        dx <= $signed(edge_end_x) - $signed(edge_start_x);
                        dy <= $signed(edge_end_y) - $signed(edge_start_y);

                        // Area of trapezoid
                        edge_area <= ($signed(edge_start_y) + $signed(edge_end_y)) * dx / 2;
                    end

                    // Check if we've reached the target
                    if ($signed(accumulated_area) + $signed(edge_area) >= $signed(target_area)) begin
                        // Linear interpolation to find exact x
                        reg signed [31:0] remaining_area;
                        remaining_area <= $signed(target_area) - $signed(accumulated_area);

                        reg signed [31:0] fraction;
                        fraction <= $signed(remaining_area) * $signed(dx) / $signed(edge_area);

                        bulkhead_x[section_index] <= $signed(edge_start_x) + fraction;
                        section_index <= section_index + 8'd1;
                        break;
                    end else begin
                        accumulated_area <= accumulated_area + edge_area;
                    end
                end
            end
        end
    end

    // Output results
    always @(posedge clk) begin
        if (state == OUTPUT_RESULTS) begin
            static integer output_index = 0;
            if (output_index < bulkhead_count) begin
                result <= bulkhead_x[output_index];
                result_valid <= 1'b1;
                output_index <= output_index + 1;
            end else begin
                result_valid <= 1'b0;
                result_done <= 1'b1;
                output_index <= 0;
            end
        end else begin
            result_valid <= 1'b0;
            result_done <= 1'b0;
        end
    end

    // Initialize bulkhead count
    always @(posedge clk) begin
        if (state == SWEEP_X && section_index == M - 1) begin
            bulkhead_count <= M - 1;
        end
    end

endmodule