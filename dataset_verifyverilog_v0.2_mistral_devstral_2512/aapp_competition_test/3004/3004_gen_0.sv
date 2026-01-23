module fence_painter (
    input clk,
    input rst_n,
    input start,
    input [1:0] offer_color,
    input [4:0] offer_start,
    input [4:0] offer_end,
    input [1:0] offer_index,
    input offer_valid,
    output reg [2:0] result,
    output reg done,
    output reg possible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        SORT,
        PROCESS,
        DONE
    } state_t;

    state_t state;

    // Internal registers
    reg [1:0] offers [0:3][0:0]; // 4 offers, each with 2-bit color
    reg [4:0] offers_start [0:3]; // 4 offers, each with 5-bit start
    reg [4:0] offers_end [0:3];   // 4 offers, each with 5-bit end
    reg [1:0] sorted_offers [0:3][0:0]; // Sorted offers
    reg [4:0] sorted_offers_start [0:3];
    reg [4:0] sorted_offers_end [0:3];
    reg [4:0] current_position;
    reg [3:0] used_colors;
    reg [2:0] offer_count;
    reg [1:0] load_index;
    reg [1:0] sort_i;
    reg [1:0] sort_j;
    reg [1:0] process_i;
    reg [1:0] best_offer;
    reg [4:0] best_end;
    reg [3:0] temp_colors;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            possible <= 0;
            load_index <= 0;
            sort_i <= 0;
            sort_j <= 0;
            process_i <= 0;
            offer_count <= 0;
            current_position <= 1;
            used_colors <= 0;
            best_offer <= 0;
            best_end <= 0;
            temp_colors <= 0;
            for (int i = 0; i < 4; i++) begin
                offers[i][0] <= 0;
                offers_start[i] <= 0;
                offers_end[i] <= 0;
                sorted_offers[i][0] <= 0;
                sorted_offers_start[i] <= 0;
                sorted_offers_end[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        load_index <= 0;
                        offer_count <= 0;
                        current_position <= 1;
                        used_colors <= 0;
                        possible <= 1;
                        done <= 0;
                    end
                end
                LOAD: begin
                    if (offer_valid) begin
                        offers[load_index][0] <= offer_color;
                        offers_start[load_index] <= offer_start;
                        offers_end[load_index] <= offer_end;
                        load_index <= load_index + 1;
                        if (load_index == 3) begin
                            state <= SORT;
                            sort_i <= 0;
                            sort_j <= 0;
                        end
                    end
                end
                SORT: begin
                    // Bubble sort implementation
                    if (sort_i < 3) begin
                        if (sort_j < 3 - sort_i) begin
                            if (offers_start[sort_j] > offers_start[sort_j + 1]) begin
                                // Swap offers
                                reg [1:0] temp_color;
                                reg [4:0] temp_start;
                                reg [4:0] temp_end;
                                temp_color = offers[sort_j][0];
                                temp_start = offers_start[sort_j];
                                temp_end = offers_end[sort_j];
                                offers[sort_j][0] <= offers[sort_j + 1][0];
                                offers_start[sort_j] <= offers_start[sort_j + 1];
                                offers_end[sort_j] <= offers_end[sort_j + 1];
                                offers[sort_j + 1][0] <= temp_color;
                                offers_start[sort_j + 1] <= temp_start;
                                offers_end[sort_j + 1] <= temp_end;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_j <= 0;
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        // Copy to sorted_offers
                        for (int i = 0; i < 4; i++) begin
                            sorted_offers[i][0] <= offers[i][0];
                            sorted_offers_start[i] <= offers_start[i];
                            sorted_offers_end[i] <= offers_end[i];
                        end
                        state <= PROCESS;
                        process_i <= 0;
                        best_offer <= 0;
                        best_end <= 0;
                    end
                end
                PROCESS: begin
                    if (current_position > 16) begin
                        state <= DONE;
                        result <= offer_count;
                        done <= 1;
                    end else begin
                        if (process_i < 4) begin
                            // Check if offer covers current position and color is allowed
                            if (sorted_offers_start[process_i] <= current_position && 
                                sorted_offers_end[process_i] >= current_position) begin
                                // Check color count
                                temp_colors <= used_colors;
                                if (sorted_offers[process_i][0] == 0) begin
                                    if (temp_colors[0] == 0) temp_colors[0] <= 1;
                                end else if (sorted_offers[process_i][0] == 1) begin
                                    if (temp_colors[1] == 0) temp_colors[1] <= 1;
                                end else if (sorted_offers[process_i][0] == 2) begin
                                    if (temp_colors[2] == 0) temp_colors[2] <= 1;
                                end else begin
                                    if (temp_colors[3] == 0) temp_colors[3] <= 1;
                                end
                                // Count set bits in temp_colors
                                reg [1:0] color_count = 0;
                                if (temp_colors[0]) color_count = color_count + 1;
                                if (temp_colors[1]) color_count = color_count + 1;
                                if (temp_colors[2]) color_count = color_count + 1;
                                if (temp_colors[3]) color_count = color_count + 1;
                                if (color_count <= 3) begin
                                    if (sorted_offers_end[process_i] > best_end) begin
                                        best_offer <= process_i;
                                        best_end <= sorted_offers_end[process_i];
                                    end
                                end
                            end
                            process_i <= process_i + 1;
                        end else begin
                            if (best_end > 0) begin
                                // Update state
                                current_position <= best_end + 1;
                                offer_count <= offer_count + 1;
                                // Update used_colors
                                if (sorted_offers[best_offer][0] == 0) begin
                                    used_colors[0] <= 1;
                                end else if (sorted_offers[best_offer][0] == 1) begin
                                    used_colors[1] <= 1;
                                end else if (sorted_offers[best_offer][0] == 2) begin
                                    used_colors[2] <= 1;
                                end else begin
                                    used_colors[3] <= 1;
                                end
                                process_i <= 0;
                                best_offer <= 0;
                                best_end <= 0;
                            end else begin
                                // No valid offer found
                                possible <= 0;
                                state <= DONE;
                                result <= 0;
                                done <= 1;
                            end
                        end
                    end
                end
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule