module hanabi_min_hints (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire input_valid,
    input wire [7:0] input_card,
    input wire [4:0] n_in,
    output reg done,
    output reg [3:0] answer
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] READ       = 3'd1;
    localparam [2:0] INIT_MASK  = 3'd2;
    localparam [2:0] CHECK_MASK = 3'd3;
    localparam [2:0] NEXT_MASK  = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] card_count;
    reg [4:0] n_reg;
    reg [9:0] distinct_cards [0:7];  // Store up to 8 cards
    reg [9:0] card_reg;
    reg [9:0] mask_reg;
    reg [9:0] signature_reg;
    reg [9:0] computed_mask;
    reg [3:0] min_hints;
    reg [3:0] popcount_val;
    reg [7:0] mask_idx;
    reg [2:0] i;
    reg [2:0] j;
    reg conflict_detected;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Helper function to convert card to pattern
    function automatic [9:0] card_to_pattern(input [7:0] card);
        reg [3:0] color;
        reg [3:0] value;
        begin
            color = card[7:4];
            value = card[3:0];
            card_to_pattern = (10'd1 << color) | (10'd1 << (5 + value));
        end
    endfunction

    // Helper function to check if signatures are distinct
    function automatic [0:0] check_distinct(input [9:0] sig [0:7], input [4:0] count);
        reg [0:0] found_dup;
        integer k, l;
        begin
            found_dup = 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                if (k < count) begin
                    for (l = k + 1; l < 8; l = l + 1) begin
                        if (l < count) begin
                            if (sig[k] == sig[l]) begin
                                found_dup = 1'b1;
                            end
                        end
                    end
                end
            end
            check_distinct = ~found_dup;
        end
    endfunction

    // Helper function to count set bits
    function automatic [3:0] popcount(input [9:0] value);
        reg [3:0] count;
        integer k;
        begin
            count = 4'd0;
            for (k = 0; k < 10; k = k + 1) begin
                if (value[k]) begin
                    count = count + 4'd1;
                end
            end
            popcount = count;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            answer <= 4'd0;
            card_count <= 5'd0;
            n_reg <= 5'd0;
            mask_reg <= 10'd0;
            computed_mask <= 10'd0;
            min_hints <= 4'd10;
            popcount_val <= 4'd0;
            mask_idx <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            cycle_counter <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                distinct_cards[i] <= 10'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    card_count <= 5'd0;
                    mask_idx <= 8'd0;
                    min_hints <= 4'd10;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        n_reg <= n_in;
                    end
                end

                READ: begin
                    if (input_valid && card_count < n_reg && card_count < 8) begin
                        distinct_cards[card_count] <= card_to_pattern(input_card);
                        card_count <= card_count + 5'd1;
                    end
                end

                INIT_MASK: begin
                    mask_idx <= 8'd0;
                    mask_reg <= {mask_idx[1:0], mask_idx[2], mask_idx[3], mask_idx[4], 
                                 mask_idx[5], mask_idx[6], mask_idx[7], mask_idx[0], 1'b0, 1'b0};
                    i <= 3'd0;
                    j <= 3'd0;
                end

                CHECK_MASK: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Compute signature for card i
                    if (i == 3'd0) begin
                        computed_mask <= distinct_cards[0] & mask_reg;
                    end
                    
                    // Check for conflicts
                    conflict_detected <= 1'b0;
                    if (i < card_count && j < card_count) begin
                        if (i != j && computed_mask == (distinct_cards[j] & mask_reg)) begin
                            conflict_detected <= 1'b1;
                        end
                    end
                end

                NEXT_MASK: begin
                    // Update min_hints if no conflict and mask_idx < 1024
                    if (!conflict_detected && mask_idx < 8'd128) begin
                        popcount_val <= popcount(mask_reg);
                        if (popcount_val < min_hints) begin
                            min_hints <= popcount_val;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    answer <= min_hints;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n_in > 5'd0 && n_in <= 5'd8) begin
                        next_state = READ;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end
            end

            READ: begin
                if (card_count >= n_reg || card_count >= 8) begin
                    if (card_count == 5'd0) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = INIT_MASK;
                    end
                end
            end

            INIT_MASK: begin
                if (mask_idx < 8'd128) begin
                    next_state = CHECK_MASK;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            CHECK_MASK: begin
                if (i >= card_count) begin
                    next_state = NEXT_MASK;
                end else if (conflict_detected) begin
                    next_state = NEXT_MASK;
                end else begin
                    next_state = CHECK_MASK;
                end
            end

            NEXT_MASK: begin
                if (cycle_counter >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    if (mask_idx < 8'd127) begin
                        mask_idx = mask_idx + 8'd1;
                        next_state = INIT_MASK;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule