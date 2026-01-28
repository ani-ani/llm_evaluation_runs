module SquareCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] x_in,
    input wire signed [31:0] y_in,
    input wire [3:0] idx,
    input wire valid_in,
    output reg done,
    output reg busy,
    output reg signed [31:0] side_len
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] point_count;
    reg [3:0] current_idx;
    reg [3:0] ignore_idx;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Point storage (16 points, each with x, y, valid)
    reg signed [31:0] x_reg [0:15];
    reg signed [31:0] y_reg [0:15];
    reg valid_reg [0:15];

    // Intermediate calculation registers
    reg signed [32:0] min_x_temp, max_x_temp;
    reg signed [32:0] min_y_temp, max_y_temp;
    reg signed [32:0] width_temp, height_temp;
    reg signed [32:0] side_temp;
    reg signed [32:0] min_side_temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            point_count <= 4'd0;
            current_idx <= 4'd0;
            ignore_idx <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            side_len <= 32'd0;

            // Initialize point storage
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                x_reg[i] <= 32'd0;
                y_reg[i] <= 32'd0;
                valid_reg[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= STORE;
                        busy <= 1'b1;
                        point_count <= 4'd0;
                        current_idx <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                STORE: begin
                    if (valid_in && (current_idx < 16)) begin
                        x_reg[current_idx] <= x_in;
                        y_reg[current_idx] <= y_in;
                        valid_reg[current_idx] <= 1'b1;
                        point_count <= point_count + 4'd1;
                    end
                    current_idx <= current_idx + 4'd1;
                    if (current_idx >= 16) begin
                        next_state <= COMPUTE;
                        ignore_idx <= 4'd0;
                        cycle_count <= 8'd0;
                        min_side_temp <= 32'd0;
                    end else begin
                        next_state <= STORE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        // Initialize min/max for current ignore_idx
                        min_x_temp <= 32'd0;
                        max_x_temp <= 32'd0;
                        min_y_temp <= 32'd0;
                        max_y_temp <= 32'd0;

                        // Find min/max excluding ignore_idx
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (valid_reg[i] && (i != ignore_idx)) begin
                                if (i == 0) begin
                                    min_x_temp <= x_reg[i];
                                    max_x_temp <= x_reg[i];
                                    min_y_temp <= y_reg[i];
                                    max_y_temp <= y_reg[i];
                                end else begin
                                    if (x_reg[i] < min_x_temp) min_x_temp <= x_reg[i];
                                    if (x_reg[i] > max_x_temp) max_x_temp <= x_reg[i];
                                    if (y_reg[i] < min_y_temp) min_y_temp <= y_reg[i];
                                    if (y_reg[i] > max_y_temp) max_y_temp <= y_reg[i];
                                end
                            end
                        end

                        // Calculate side length
                        width_temp <= max_x_temp - min_x_temp;
                        height_temp <= max_y_temp - min_y_temp;
                        side_temp <= (width_temp > height_temp) ? width_temp : height_temp;

                        // Update minimum side length
                        if (ignore_idx == 0) begin
                            min_side_temp <= side_temp;
                        end else begin
                            if (side_temp < min_side_temp) min_side_temp <= side_temp;
                        end

                        // Move to next ignore_idx
                        ignore_idx <= ignore_idx + 4'd1;
                        if (ignore_idx >= point_count) begin
                            next_state <= FINISH;
                        end else begin
                            next_state <= COMPUTE;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    side_len <= min_side_temp;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Busy signal logic
    always @(*) begin
        if (state == IDLE) begin
            busy = 1'b0;
        end else begin
            busy = 1'b1;
        end
    end

endmodule