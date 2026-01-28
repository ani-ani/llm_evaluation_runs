module ConvexHullAreaCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire points_valid,
    input wire [2:0] point_idx,
    input wire [7:0] point_x,
    input wire [7:0] point_y,
    input wire [1:0] op,
    output reg [15:0] area_out,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] REMOVE    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Point storage (8 points, each with x, y, and valid bit)
    reg [7:0] point_x_mem [0:7];
    reg [7:0] point_y_mem [0:7];
    reg [7:0] valid_mask;

    // Counters and temporary registers
    reg [2:0] load_counter;
    reg [2:0] removal_counter;
    reg [2:0] current_idx;
    reg [7:0] min_x, max_x, min_y, max_y;
    reg [2:0] min_x_idx, max_x_idx, min_y_idx, max_y_idx;

    // Fixed-point arithmetic registers
    reg signed [23:0] shoelace_sum;
    reg [15:0] area_temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            load_counter <= 3'd0;
            removal_counter <= 3'd0;
            current_idx <= 3'd0;
            valid_mask <= 8'd0;
            min_x <= 8'd0;
            max_x <= 8'd0;
            min_y <= 8'd0;
            max_y <= 8'd0;
            min_x_idx <= 3'd0;
            max_x_idx <= 3'd0;
            min_y_idx <= 3'd0;
            max_y_idx <= 3'd0;
            shoelace_sum <= 24'd0;
            area_temp <= 16'd0;
            area_out <= 16'd0;
            done <= 1'b0;
            ready <= 1'b0;

            // Initialize point memory
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                point_x_mem[i] <= 8'd0;
                point_y_mem[i] <= 8'd0;
            end
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
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (load_counter == 3'd7) begin
                    next_state = CALCULATE;
                end
            end

            CALCULATE: begin
                if (current_idx == 3'd7) begin
                    next_state = REMOVE;
                end
            end

            REMOVE: begin
                next_state = CALCULATE;
            end

            DONE_STATE: begin
                if (removal_counter == 3'd4) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Load points
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in main reset
        end else begin
            if (state == LOAD && points_valid) begin
                point_x_mem[point_idx] <= point_x;
                point_y_mem[point_idx] <= point_y;
                valid_mask[point_idx] <= 1'b1;
                load_counter <= load_counter + 3'd1;
                ready <= 1'b1;
            end else begin
                ready <= 1'b0;
            end
        end
    end

    // Calculate extremes and area
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in main reset
        end else begin
            if (state == CALCULATE) begin
                // Find extremes
                if (current_idx == 3'd0) begin
                    min_x = 8'd255;
                    max_x = 8'd0;
                    min_y = 8'd255;
                    max_y = 8'd0;
                    shoelace_sum = 24'd0;
                end

                if (valid_mask[current_idx]) begin
                    // Update min/max x
                    if (point_x_mem[current_idx] < min_x) begin
                        min_x = point_x_mem[current_idx];
                        min_x_idx = current_idx;
                    end
                    if (point_x_mem[current_idx] > max_x) begin
                        max_x = point_x_mem[current_idx];
                        max_x_idx = current_idx;
                    end

                    // Update min/max y
                    if (point_y_mem[current_idx] < min_y) begin
                        min_y = point_y_mem[current_idx];
                        min_y_idx = current_idx;
                    end
                    if (point_y_mem[current_idx] > max_y) begin
                        max_y = point_y_mem[current_idx];
                        max_y_idx = current_idx;
                    end

                    // Shoelace formula: sum(x_i * y_{i+1} - x_{i+1} * y_i)
                    reg [2:0] next_idx;
                    if (current_idx == 3'd7) begin
                        next_idx = 3'd0;
                    end else begin
                        next_idx = current_idx + 3'd1;
                    end

                    if (valid_mask[next_idx]) begin
                        reg signed [15:0] term1;
                        reg signed [15:0] term2;
                        term1 = $signed(point_x_mem[current_idx]) * $signed(point_y_mem[next_idx]);
                        term2 = $signed(point_x_mem[next_idx]) * $signed(point_y_mem[current_idx]);
                        shoelace_sum = shoelace_sum + (term1 - term2);
                    end

                    current_idx <= current_idx + 3'd1;
                end else begin
                    current_idx <= current_idx + 3'd1;
                end

                // After processing all points
                if (current_idx == 3'd7) begin
                    area_temp = shoelace_sum[23:8]; // Take upper 16 bits
                    area_out = area_temp >>> 1; // Divide by 2 (shift right 1)
                    done <= 1'b1;
                    next_state = REMOVE;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Remove extreme point
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in main reset
        end else begin
            if (state == REMOVE) begin
                case (op)
                    2'd0: valid_mask[min_x_idx] <= 1'b0; // Remove leftmost
                    2'd1: valid_mask[max_x_idx] <= 1'b0; // Remove rightmost
                    2'd2: valid_mask[max_y_idx] <= 1'b0; // Remove topmost
                    2'd3: valid_mask[min_y_idx] <= 1'b0; // Remove bottommost
                    default: ;
                endcase
                removal_counter <= removal_counter + 3'd1;
                current_idx <= 3'd0;
                next_state = CALCULATE;
            end
        end
    end

endmodule