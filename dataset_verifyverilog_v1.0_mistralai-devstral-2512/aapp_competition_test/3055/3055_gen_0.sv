module ThoreHusfeldtPrefixFinder(
    input clk,
    input rst_n,
    input start,
    input [7:0] name_char,
    input name_valid,
    input [6:0] name_index,
    output reg [7:0] result_char,
    output reg result_valid,
    output reg done,
    output reg is_first,
    output reg has_thoreh_above,
    output reg has_thore_above
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_NAMES = 3'd1;
    localparam [2:0] FIND_INDEX = 3'd2;
    localparam [2:0] COMPARE_PREFIX = 3'd3;
    localparam [2:0] OUTPUT_RESULT = 3'd4;

    // Constants
    localparam [6:0] MAX_NAMES = 7'd100;
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [3:0] MAX_PREFIX_LEN = 4'd14;

    // Reference name "ThoreHusfeldt"
    localparam [7:0] REF_NAME [0:13] = '{ 
        8'h54, 8'h68, 8'h6f, 8'h72, 8'h65, 8'h48, 8'h75, 8'h73,
        8'h66, 8'h65, 8'h6c, 8'h64, 8'h74
    };

    // Result messages
    localparam [7:0] MSG_AWESOME [0:6] = '{ 
        8'h54, 8'h68, 8'h6f, 8'h72, 8'h65, 8'h20, 8'h69
    };
    localparam [7:0] MSG_SUCKS [0:10] = '{ 
        8'h54, 8'h68, 8'h6f, 8'h72, 8'h65, 8'h20, 8'h73, 8'h75,
        8'h63, 8'h6b, 8'h73
    };

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [6:0] name_count;
    reg [6:0] target_index;
    reg [6:0] current_index;
    reg [3:0] prefix_len;
    reg [3:0] output_index;
    reg [3:0] output_len;
    reg [7:0] names [0:99][0:13];
    reg [7:0] current_name [0:13];
    reg [3:0] current_char_index;
    reg found_target;
    reg has_thoreh_prefix;
    reg has_thore_prefix;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            name_count <= 7'd0;
            target_index <= 7'd0;
            current_index <= 7'd0;
            prefix_len <= 4'd0;
            output_index <= 4'd0;
            output_len <= 4'd0;
            found_target <= 1'b0;
            has_thoreh_prefix <= 1'b0;
            has_thore_prefix <= 1'b0;
            result_char <= 8'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            is_first <= 1'b0;
            has_thoreh_above <= 1'b0;
            has_thore_above <= 1'b0;

            // Initialize name storage
            integer i, j;
            for (i = 0; i < 100; i = i + 1) begin
                for (j = 0; j < 14; j = j + 1) begin
                    names[i][j] <= 8'd0;
                end
            end

            // Initialize current name
            for (j = 0; j < 14; j = j + 1) begin
                current_name[j] <= 8'd0;
            end
            current_char_index <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_NAMES;
                    cycle_count = 8'd0;
                    name_count = 7'd0;
                    current_index = 7'd0;
                    current_char_index = 4'd0;
                    found_target = 1'b0;
                    has_thoreh_prefix = 1'b0;
                    has_thore_prefix = 1'b0;
                    is_first = 1'b0;
                    has_thoreh_above = 1'b0;
                    has_thore_above = 1'b0;
                end
            end

            READ_NAMES: begin
                if (name_valid) begin
                    // Store current character
                    if (current_char_index < 14) begin
                        current_name[current_char_index] = name_char;
                        current_char_index = current_char_index + 1;
                    end

                    // Check if this is the last character of current name
                    if (!name_valid || name_index != current_index) begin
                        // Store completed name
                        integer j;
                        for (j = 0; j < 14; j = j + 1) begin
                            names[current_index][j] = current_name[j];
                        end

                        // Check if this is "ThoreHusfeldt"
                        reg match;
                        match = 1'b1;
                        for (j = 0; j < 13; j = j + 1) begin
                            if (current_name[j] != REF_NAME[j]) begin
                                match = 1'b0;
                            end
                        end

                        if (match) begin
                            target_index = current_index;
                            found_target = 1'b1;
                        end

                        // Move to next name
                        current_index = current_index + 1;
                        current_char_index = 4'd0;
                        name_count = name_count + 1;
                    end

                    // Check if all names processed
                    if (name_count >= MAX_NAMES || cycle_count >= MAX_CYCLES - 1) begin
                        next_state = FIND_INDEX;
                    end
                end
            end

            FIND_INDEX: begin
                if (found_target) begin
                    // Check if target is first
                    if (target_index == 0) begin
                        is_first = 1'b1;
                        output_len = 7;
                        next_state = OUTPUT_RESULT;
                    end else begin
                        // Check for "ThoreHusfeld" prefix above
                        integer i, j;
                        has_thoreh_prefix = 1'b0;
                        has_thore_prefix = 1'b0;

                        for (i = 0; i < target_index; i = i + 1) begin
                            reg prefix_match;
                            prefix_match = 1'b1;

                            // Check for "ThoreHusfeld" (13 chars)
                            for (j = 0; j < 13; j = j + 1) begin
                                if (names[i][j] != REF_NAME[j]) begin
                                    prefix_match = 1'b0;
                                end
                            end

                            if (prefix_match) begin
                                has_thoreh_prefix = 1'b1;
                                has_thoreh_above = 1'b1;
                            end

                            // Check for "Thore" (5 chars)
                            prefix_match = 1'b1;
                            for (j = 0; j < 5; j = j + 1) begin
                                if (names[i][j] != REF_NAME[j]) begin
                                    prefix_match = 1'b0;
                                end
                            end

                            if (prefix_match) begin
                                has_thore_prefix = 1'b1;
                                has_thore_above = 1'b1;
                            end
                        end

                        if (has_thoreh_prefix) begin
                            output_len = 11;
                        end else if (has_thore_prefix) begin
                            // Find smallest k
                            prefix_len = 1;
                            while (prefix_len <= 14) begin
                                reg unique;
                                unique = 1'b1;

                                for (i = 0; i < target_index; i = i + 1) begin
                                    reg match;
                                    match = 1'b1;

                                    for (j = 0; j < prefix_len; j = j + 1) begin
                                        if (names[i][j] != REF_NAME[j]) begin
                                            match = 1'b0;
                                        end
                                    end

                                    if (match) begin
                                        unique = 1'b0;
                                    end
                                end

                                if (unique) begin
                                    break;
                                end
                                prefix_len = prefix_len + 1;
                            end
                            output_len = prefix_len;
                        end
                        next_state = OUTPUT_RESULT;
                    end
                end else begin
                    // No target found - output nothing
                    done = 1'b1;
                    next_state = IDLE;
                end
            end

            OUTPUT_RESULT: begin
                if (output_index < output_len) begin
                    if (is_first) begin
                        result_char = MSG_AWESOME[output_index];
                    end else if (has_thoreh_prefix) begin
                        result_char = MSG_SUCKS[output_index];
                    end else begin
                        result_char = REF_NAME[output_index];
                    end
                    result_valid = 1'b1;
                    output_index = output_index + 1;
                end else begin
                    result_valid = 1'b0;
                    done = 1'b1;
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter
    always @(posedge clk) begin
        if (state != IDLE) begin
            cycle_count = cycle_count + 1;
            if (cycle_count >= MAX_CYCLES) begin
                done = 1'b1;
                state = IDLE;
            end
        end
    end

endmodule