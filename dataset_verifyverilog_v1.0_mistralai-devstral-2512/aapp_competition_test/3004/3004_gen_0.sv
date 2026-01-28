module fence_painting(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_offers,
    input [1:0] offer_color [0:11],
    input [3:0] offer_start [0:11],
    input [3:0] offer_end [0:11],
    output reg [3:0] min_offers,
    output reg impossible,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE_SUBSET = 3'd1;
    localparam [2:0] CHECK_SUBSET = 3'd2;
    localparam [2:0] UPDATE_MIN = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [11:0] subset_mask;
    reg [3:0] current_min;
    reg [3:0] subset_size;
    reg [3:0] unique_colors;
    reg [15:0] cover_mask;
    reg [3:0] color_mask;
    reg [15:0] offer_cover;
    reg [3:0] i, j;
    reg found_solution;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_mask <= 12'd0;
            current_min <= 4'd13;
            subset_size <= 4'd0;
            unique_colors <= 4'd0;
            cover_mask <= 16'd0;
            color_mask <= 4'd0;
            offer_cover <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            found_solution <= 1'b0;
            min_offers <= 4'd0;
            impossible <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GENERATE_SUBSET;
                    subset_mask = 12'd0;
                    current_min = 4'd13;
                    found_solution = 1'b0;
                end
            end

            GENERATE_SUBSET: begin
                if (subset_mask == 12'd4095) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_SUBSET;
                end
            end

            CHECK_SUBSET: begin
                next_state = UPDATE_MIN;
            end

            UPDATE_MIN: begin
                next_state = GENERATE_SUBSET;
            end

            FINISH: begin
                if (found_solution) begin
                    min_offers = current_min;
                    impossible = 1'b0;
                end else begin
                    impossible = 1'b1;
                end
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        if (state == GENERATE_SUBSET) begin
            subset_mask = subset_mask + 12'd1;
        end
    end

    always @(*) begin
        if (state == CHECK_SUBSET) begin
            // Count subset size
            subset_size = 4'd0;
            for (i = 0; i < 12; i = i + 1) begin
                if (subset_mask[i])
                    subset_size = subset_size + 4'd1;
            end

            // Early exit if size >= current_min
            if (subset_size >= current_min) begin
                next_state = GENERATE_SUBSET;
            end else begin
                // Check unique colors
                color_mask = 4'd0;
                unique_colors = 4'd0;
                for (i = 0; i < 12; i = i + 1) begin
                    if (subset_mask[i]) begin
                        if (!color_mask[offer_color[i]]) begin
                            color_mask[offer_color[i]] = 1'b1;
                            unique_colors = unique_colors + 4'd1;
                        end
                    end
                end

                // Check color constraint
                if (unique_colors > 3) begin
                    next_state = GENERATE_SUBSET;
                end else begin
                    // Check coverage
                    cover_mask = 16'd0;
                    for (i = 0; i < 12; i = i + 1) begin
                        if (subset_mask[i]) begin
                            offer_cover = 16'd0;
                            for (j = offer_start[i]; j <= offer_end[i]; j = j + 1) begin
                                offer_cover[j] = 1'b1;
                            end
                            cover_mask = cover_mask | offer_cover;
                        end
                    end

                    if (cover_mask == 16'hFFFF) begin
                        next_state = UPDATE_MIN;
                    end else begin
                        next_state = GENERATE_SUBSET;
                    end
                end
            end
        end
    end

    always @(*) begin
        if (state == UPDATE_MIN) begin
            current_min = subset_size;
            found_solution = 1'b1;
        end
    end

endmodule