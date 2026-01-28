module IconMinimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] icon_r [0:15],
    input wire [15:0] icon_c [0:15],
    input wire icon_type [0:15],
    input wire icon_valid [0:15],
    output reg [7:0] min_moves,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP_SUBSETS = 3'd2;
    localparam [2:0] CALC_BOUNDS = 3'd3;
    localparam [2:0] CHECK_KEEP = 3'd4;
    localparam [2:0] CHECK_REM_DELETE = 3'd5;
    localparam [2:0] UPDATE_MIN = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state, next_state;

    // Loop counters and variables
    reg [15:0] subset_counter;
    reg [3:0] icon_index;
    reg [15:0] min_r, max_r, min_c, max_c;
    reg [7:0] current_cost;
    reg [7:0] best_cost;
    reg [15:0] temp_r, temp_c;
    reg first_valid;

    // Count number of delete icons
    reg [3:0] num_delete_icons;
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_counter <= 16'd0;
            icon_index <= 4'd0;
            min_r <= 16'd0;
            max_r <= 16'd0;
            min_c <= 16'd0;
            max_c <= 16'd0;
            current_cost <= 8'd0;
            best_cost <= 8'd255;
            temp_r <= 16'd0;
            temp_c <= 16'd0;
            first_valid <= 1'b0;
            num_delete_icons <= 4'd0;
            i <= 4'd0;
            min_moves <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Count number of delete icons
                num_delete_icons = 4'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    if (icon_valid[i] && icon_type[i]) begin
                        num_delete_icons = num_delete_icons + 1;
                    end
                end
                subset_counter = 16'd0;
                best_cost = 8'd255;
                next_state = LOOP_SUBSETS;
            end

            LOOP_SUBSETS: begin
                if (subset_counter < (1 << num_delete_icons)) begin
                    // Initialize bounds
                    min_r = 16'd65535;
                    max_r = 16'd0;
                    min_c = 16'd65535;
                    max_c = 16'd0;
                    first_valid = 1'b0;
                    icon_index = 4'd0;
                    next_state = CALC_BOUNDS;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            CALC_BOUNDS: begin
                if (icon_index < 16) begin
                    if (icon_valid[icon_index] && icon_type[icon_index]) begin
                        // Check if this icon is in the current subset
                        reg [3:0] delete_index;
                        reg [3:0] count;
                        count = 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (icon_valid[i] && icon_type[i]) begin
                                if (i == icon_index) begin
                                    delete_index = count;
                                end
                                count = count + 1;
                            end
                        end
                        if (subset_counter[delete_index]) begin
                            // Calculate center
                            temp_r = icon_r[icon_index] + 16'd7;
                            temp_c = icon_c[icon_index] + 16'd4;
                            if (!first_valid) begin
                                min_r = temp_r;
                                max_r = temp_r;
                                min_c = temp_c;
                                max_c = temp_c;
                                first_valid = 1'b1;
                            end else begin
                                if (temp_r < min_r) min_r = temp_r;
                                if (temp_r > max_r) max_r = temp_r;
                                if (temp_c < min_c) min_c = temp_c;
                                if (temp_c > max_c) max_c = temp_c;
                            end
                        end
                    end
                    icon_index = icon_index + 1;
                end else begin
                    if (first_valid && (max_r > min_r) && (max_c > min_c)) begin
                        current_cost = 8'd0;
                        icon_index = 4'd0;
                        next_state = CHECK_KEEP;
                    end else begin
                        icon_index = 4'd0;
                        next_state = LOOP_SUBSETS;
                        subset_counter = subset_counter + 1;
                    end
                end
            end

            CHECK_KEEP: begin
                if (icon_index < 16) begin
                    if (icon_valid[icon_index] && !icon_type[icon_index]) begin
                        // Check if keep icon is inside bounds
                        temp_r = icon_r[icon_index] + 16'd7;
                        temp_c = icon_c[icon_index] + 16'd4;
                        if (temp_r >= min_r && temp_r <= max_r && temp_c >= min_c && temp_c <= max_c) begin
                            current_cost = current_cost + 1;
                        end
                    end
                    icon_index = icon_index + 1;
                end else begin
                    icon_index = 4'd0;
                    next_state = CHECK_REM_DELETE;
                end
            end

            CHECK_REM_DELETE: begin
                if (icon_index < 16) begin
                    if (icon_valid[icon_index] && icon_type[icon_index]) begin
                        // Check if delete icon is not in subset
                        reg [3:0] delete_index;
                        reg [3:0] count;
                        count = 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (icon_valid[i] && icon_type[i]) begin
                                if (i == icon_index) begin
                                    delete_index = count;
                                end
                                count = count + 1;
                            end
                        end
                        if (!subset_counter[delete_index]) begin
                            current_cost = current_cost + 1;
                        end
                    end
                    icon_index = icon_index + 1;
                end else begin
                    next_state = UPDATE_MIN;
                end
            end

            UPDATE_MIN: begin
                if (current_cost < best_cost) begin
                    best_cost = current_cost;
                end
                subset_counter = subset_counter + 1;
                next_state = LOOP_SUBSETS;
            end

            DONE_STATE: begin
                min_moves = best_cost;
                done <= 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule