module fence_painter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_offers,
    input wire [1:0] offer_color [0:11],
    input wire [3:0] offer_start [0:11],
    input wire [3:0] offer_end [0:11],
    output reg [3:0] min_offers,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE_SUBSET = 3'd1;
    localparam [2:0] CHECK_COLORS = 3'd2;
    localparam [2:0] CHECK_COVERAGE = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [11:0] subset_index;      // 0 to 4095
    reg [3:0] current_size;       // Popcount of subset
    reg [3:0] unique_colors;      // Count of distinct colors
    reg [15:0] cover_mask;        // 16-bit coverage mask
    reg [3:0] color_used [0:3];   // Track used colors (0=Red, 1=Blue, 2=Green, 3=Yellow)
    reg [3:0] i_counter;          // Loop counter for offers
    reg [3:0] bit_counter;        // Loop counter for bits
    reg [1:0] current_color;
    reg [3:0] start_sec, end_sec;
    reg [3:0] max_offers_limit;
    reg [15:0] temp_mask;
    reg [3:0] found_colors;
    reg valid_subset;
    reg [3:0] min_offers_reg;
    reg done_pulse;

    // Function to check if bit is set in subset_index
    function automatic bit is_bit_set;
        input [11:0] mask;
        input [3:0] bit_pos;
        begin
            is_bit_set = mask[bit_pos];
        end
    endfunction

    // Function to generate coverage mask for an offer
    function automatic [15:0] generate_mask;
        input [3:0] start_bit;
        input [3:0] end_bit;
        reg [15:0] mask_temp;
        integer j;
        begin
            mask_temp = 16'd0;
            for (j = start_bit; j <= end_bit; j = j + 1) begin
                mask_temp = mask_temp | (16'd1 << j);
            end
            generate_mask = mask_temp;
        end
    endfunction

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? GENERATE_SUBSET : IDLE;
            GENERATE_SUBSET: next_state = CHECK_COLORS;
            CHECK_COLORS: next_state = CHECK_COVERAGE;
            CHECK_COVERAGE: next_state = valid_subset ? UPDATE_MIN : GENERATE_SUBSET;
            UPDATE_MIN: next_state = GENERATE_SUBSET;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_index <= 12'd0;
            current_size <= 4'd0;
            unique_colors <= 4'd0;
            cover_mask <= 16'd0;
            i_counter <= 4'd0;
            bit_counter <= 4'd0;
            min_offers_reg <= 4'd12;
            impossible <= 1'b0;
            done <= 1'b0;
            done_pulse <= 1'b0;
            // Initialize color_used array
            color_used[0] <= 4'd0;
            color_used[1] <= 4'd0;
            color_used[2] <= 4'd0;
            color_used[3] <= 4'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        subset_index <= 12'd0;
                        min_offers_reg <= 4'd12;
                        impossible <= 1'b0;
                        max_offers_limit <= (num_offers > 4'd12) ? 4'd12 : num_offers;
                    end
                end

                GENERATE_SUBSET: begin
                    // Check if subset has valid offer count (<= num_offers and <= current min)
                    if (subset_index < 12'd4096) begin
                        // Count bits (popcount)
                        current_size <= 4'd0;
                        for (integer b = 0; b < 12; b = b + 1) begin
                            if (subset_index[b] && b < max_offers_limit) begin
                                current_size <= current_size + 4'd1;
                            end
                        end
                    end
                end

                CHECK_COLORS: begin
                    // Reset color tracking
                    color_used[0] <= 4'd0;
                    color_used[1] <= 4'd0;
                    color_used[2] <= 4'd0;
                    color_used[3] <= 4'd0;
                    unique_colors <= 4'd0;
                    
                    // Check colors for subset (only consider offers < num_offers)
                    for (integer c = 0; c < 12; c = c + 1) begin
                        if (subset_index[c] && c < max_offers_limit) begin
                            color_used[offer_color[c]] <= 4'd1;
                        end
                    end
                    // Count unique colors
                    unique_colors <= color_used[0] + color_used[1] + color_used[2] + color_used[3];
                end

                CHECK_COVERAGE: begin
                    cover_mask <= 16'd0;
                    valid_subset <= 1'b0;
                    
                    // Only check if colors <= 3 and size < current min
                    if (unique_colors <= 3 && current_size < min_offers_reg && current_size > 0) begin
                        // Generate coverage mask
                        temp_mask <= 16'd0;
                        for (integer offer_idx = 0; offer_idx < 12; offer_idx = offer_idx + 1) begin
                            if (subset_index[offer_idx] && offer_idx < max_offers_limit) begin
                                temp_mask <= temp_mask | generate_mask(offer_start[offer_idx], offer_end[offer_idx]);
                            end
                        end
                        // Check if fully covered (0-15 all bits set)
                        if (temp_mask == 16'hFFFF) begin
                            valid_subset <= 1'b1;
                        end
                    end
                end

                UPDATE_MIN: begin
                    if (valid_subset) begin
                        min_offers_reg <= current_size;
                    end
                    // Move to next subset
                    subset_index <= subset_index + 12'd1;
                    // Check for completion
                    if (subset_index == 12'd4095) begin
                        // Done iterating all subsets
                        if (min_offers_reg == 4'd12) begin
                            // No valid subset found
                            impossible <= 1'b1;
                            min_offers <= 4'd0;
                        end else begin
                            min_offers <= min_offers_reg;
                            impossible <= 1'b0;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // State transition
            if (state != FINISH) begin
                state <= next_state;
            end
            
            // Special handling for end of update state
            if (state == UPDATE_MIN && subset_index == 12'd4095) begin
                state <= FINISH;
            end
        end
    end

endmodule