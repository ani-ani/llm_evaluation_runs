module sticker_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] message_len,
    input [15:0][7:0] message_chars,
    input [7:0] num_stickers,
    input [7:0] sticker_len [0:7],
    input [19:0][7:0] sticker_chars [0:7],
    input [19:0] sticker_price [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        INITIALIZE,
        DP_LOOP,
        FIND_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // DP state storage (simplified for synthesis)
    reg [31:0] dp_cost [0:255]; // Using mask as index (max 16 bits)
    reg [15:0] dp_mask [0:255]; // Track covered positions
    reg [15:0] dp_overlap1 [0:255]; // Overlap subset 1
    reg [15:0] dp_overlap2 [0:255]; // Overlap subset 2

    // Internal counters and registers
    reg [7:0] pos_counter;
    reg [7:0] sticker_counter;
    reg [7:0] mask_counter;
    reg [7:0] dp_index;
    reg [31:0] current_cost;
    reg [15:0] current_mask;
    reg [15:0] current_overlap1;
    reg [15:0] current_overlap2;

    // Temporary registers for computation
    reg [15:0] new_mask;
    reg [15:0] new_overlap1;
    reg [15:0] new_overlap2;
    reg [31:0] new_cost;
    reg sticker_fits;
    reg overlap_valid;

    // Initialize all DP states to impossible
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 32'hFFFFFFFF;
            for (i = 0; i < 256; i = i + 1) begin
                dp_cost[i] <= 32'hFFFFFFFF;
                dp_mask[i] <= 16'h0;
                dp_overlap1[i] <= 16'h0;
                dp_overlap2[i] <= 16'h0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = INITIALIZE;
            end
            INITIALIZE: begin
                next_state = DP_LOOP;
            end
            DP_LOOP: begin
                if (pos_counter == message_len - 1 && sticker_counter == num_stickers - 1 && mask_counter == 255) begin
                    next_state = FIND_RESULT;
                end
            end
            FIND_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // State-specific logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_counter <= 0;
            sticker_counter <= 0;
            mask_counter <= 0;
            dp_index <= 0;
            current_cost <= 0;
            current_mask <= 0;
            current_overlap1 <= 0;
            current_overlap2 <= 0;
        end else begin
            case (current_state)
                LOAD: begin
                    // Initialize DP for empty mask
                    dp_cost[0] <= 0;
                    dp_mask[0] <= 0;
                    dp_overlap1[0] <= 0;
                    dp_overlap2[0] <= 0;
                    next_state = INITIALIZE;
                end
                INITIALIZE: begin
                    pos_counter <= 0;
                    sticker_counter <= 0;
                    mask_counter <= 0;
                    next_state = DP_LOOP;
                end
                DP_LOOP: begin
                    // Iterate through positions, stickers, and masks
                    if (mask_counter < 256) begin
                        current_mask = dp_mask[mask_counter];
                        current_cost = dp_cost[mask_counter];
                        current_overlap1 = dp_overlap1[mask_counter];
                        current_overlap2 = dp_overlap2[mask_counter];

                        // Try placing each sticker at current position
                        if (sticker_counter < num_stickers) begin
                            // Check if sticker fits at current position
                            sticker_fits = check_sticker_fit(pos_counter, sticker_counter, current_mask);
                            overlap_valid = check_overlap_valid(pos_counter, sticker_counter, current_overlap1, current_overlap2);

                            if (sticker_fits && overlap_valid) begin
                                // Compute new state
                                compute_new_state(pos_counter, sticker_counter, current_mask, current_overlap1, current_overlap2, new_mask, new_overlap1, new_overlap2);
                                new_cost = current_cost + sticker_price[sticker_counter];

                                // Update DP if better cost
                                if (new_cost < dp_cost[new_mask]) begin
                                    dp_cost[new_mask] <= new_cost;
                                    dp_mask[new_mask] <= new_mask;
                                    dp_overlap1[new_mask] <= new_overlap1;
                                    dp_overlap2[new_mask] <= new_overlap2;
                                end
                            end

                            sticker_counter <= sticker_counter + 1;
                        end else begin
                            sticker_counter <= 0;
                            mask_counter <= mask_counter + 1;
                        end
                    end else begin
                        pos_counter <= pos_counter + 1;
                        mask_counter <= 0;
                        if (pos_counter == message_len) begin
                            next_state = FIND_RESULT;
                        end
                    end
                end
                FIND_RESULT: begin
                    // Find minimal cost for full mask
                    result <= find_minimal_cost();
                    done <= 1;
                end
                DONE: begin
                    done <= 0;
                end
            endcase
        end
    end

    // Helper function to check if sticker fits at position
    function reg [15:0] check_sticker_fit;
        input [7:0] pos;
        input [7:0] sticker_idx;
        input [15:0] mask;
        reg [15:0] fits;
        integer j;
        begin
            fits = 1;
            for (j = 0; j < sticker_len[sticker_idx]; j = j + 1) begin
                if (pos + j >= message_len || (mask & (1 << (pos + j))) && (sticker_chars[sticker_idx][j] != message_chars[pos + j])) begin
                    fits = 0;
                end
            end
            check_sticker_fit = fits;
        end
    endfunction

    // Helper function to check overlap constraints
    function reg check_overlap_valid;
        input [7:0] pos;
        input [7:0] sticker_idx;
        input [15:0] overlap1;
        input [15:0] overlap2;
        reg valid;
        integer j;
        begin
            valid = 1;
            for (j = 0; j < sticker_len[sticker_idx]; j = j + 1) begin
                if (pos + j < 16) begin
                    if ((overlap1 & (1 << (pos + j))) && (overlap2 & (1 << (pos + j)))) begin
                        valid = 0;
                    end
                end
            end
            check_overlap_valid = valid;
        end
    endfunction

    // Helper function to compute new state
    task compute_new_state;
        input [7:0] pos;
        input [7:0] sticker_idx;
        input [15:0] current_mask;
        input [15:0] current_overlap1;
        input [15:0] current_overlap2;
        output [15:0] new_mask;
        output [15:0] new_overlap1;
        output [15:0] new_overlap2;
        integer j;
        begin
            new_mask = current_mask;
            new_overlap1 = current_overlap1;
            new_overlap2 = current_overlap2;
            for (j = 0; j < sticker_len[sticker_idx]; j = j + 1) begin
                if (pos + j < 16) begin
                    new_mask = new_mask | (1 << (pos + j));
                    if (current_overlap1 & (1 << (pos + j))) begin
                        new_overlap2 = new_overlap2 | (1 << (pos + j));
                        new_overlap1 = new_overlap1 & ~(1 << (pos + j));
                    end else if (current_overlap2 & (1 << (pos + j))) begin
                        // Already has 2 overlaps, invalid
                    end else begin
                        new_overlap1 = new_overlap1 | (1 << (pos + j));
                    end
                end
            end
        end
    endtask

    // Helper function to find minimal cost
    function [31:0] find_minimal_cost;
        integer i;
        reg [31:0] min_cost;
        begin
            min_cost = 32'hFFFFFFFF;
            for (i = 0; i < 256; i = i + 1) begin
                if (dp_mask[i] == (1 << message_len) - 1 && dp_cost[i] < min_cost) begin
                    min_cost = dp_cost[i];
                end
            end
            if (min_cost == 32'hFFFFFFFF) begin
                find_minimal_cost = 32'hFFFFFFFF;
            end else begin
                find_minimal_cost = min_cost;
            end
        end
    endfunction

endmodule