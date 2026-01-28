module string_pair_processor(
    input clk,
    input rst_n,
    input start,
    input [7:0] pair_0_str_0 [0:7],
    input [7:0] pair_0_str_1 [0:7],
    input [7:0] pair_1_str_0 [0:7],
    input [7:0] pair_1_str_1 [0:7],
    input [7:0] pair_2_str_0 [0:7],
    input [7:0] pair_2_str_1 [0:7],
    input [7:0] pair_3_str_0 [0:7],
    input [7:0] pair_3_str_1 [0:7],
    output reg [31:0] result_pair_0_val_0,
    output reg [31:0] result_pair_0_val_1,
    output reg [31:0] result_pair_1_val_0,
    output reg [31:0] result_pair_1_val_1,
    output reg [31:0] result_pair_2_val_0,
    output reg [31:0] result_pair_2_val_1,
    output reg [31:0] result_pair_3_val_0,
    output reg [31:0] result_pair_3_val_1,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Current pair being processed
    reg [1:0] current_pair;
    
    // Intermediate results
    reg [31:0] temp_result_0_0, temp_result_0_1;
    reg [31:0] temp_result_1_0, temp_result_1_1;
    reg [31:0] temp_result_2_0, temp_result_2_1;
    reg [31:0] temp_result_3_0, temp_result_3_1;

    // Parser state for each string
    reg [2:0] parse_state_0_0, parse_state_0_1;
    reg [2:0] parse_state_1_0, parse_state_1_1;
    reg [2:0] parse_state_2_0, parse_state_2_1;
    reg [2:0] parse_state_3_0, parse_state_3_1;

    // Parser registers
    reg [7:0] char_index_0_0, char_index_0_1;
    reg [7:0] char_index_1_0, char_index_1_1;
    reg [7:0] char_index_2_0, char_index_2_1;
    reg [7:0] char_index_3_0, char_index_3_1;

    reg [9:0] int_part_0_0, int_part_0_1;
    reg [9:0] int_part_1_0, int_part_1_1;
    reg [9:0] int_part_2_0, int_part_2_1;
    reg [9:0] int_part_3_0, int_part_3_1;

    reg [6:0] frac_part_0_0, frac_part_0_1;
    reg [6:0] frac_part_1_0, frac_part_1_1;
    reg [6:0] frac_part_2_0, frac_part_2_1;
    reg [6:0] frac_part_3_0, frac_part_3_1;

    reg has_decimal_0_0, has_decimal_0_1;
    reg has_decimal_1_0, has_decimal_1_1;
    reg has_decimal_2_0, has_decimal_2_1;
    reg has_decimal_3_0, has_decimal_3_1;

    reg is_alpha_0_0, is_alpha_0_1;
    reg is_alpha_1_0, is_alpha_1_1;
    reg is_alpha_2_0, is_alpha_2_1;
    reg is_alpha_3_0, is_alpha_3_1;

    reg [7:0] first_alpha_0_0, first_alpha_0_1;
    reg [7:0] first_alpha_1_0, first_alpha_1_1;
    reg [7:0] first_alpha_2_0, first_alpha_2_1;
    reg [7:0] first_alpha_3_0, first_alpha_3_1;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_pair <= 2'd0;
            
            // Reset all outputs
            result_pair_0_val_0 <= 32'd0;
            result_pair_0_val_1 <= 32'd0;
            result_pair_1_val_0 <= 32'd0;
            result_pair_1_val_1 <= 32'd0;
            result_pair_2_val_0 <= 32'd0;
            result_pair_2_val_1 <= 32'd0;
            result_pair_3_val_0 <= 32'd0;
            result_pair_3_val_1 <= 32'd0;
            done <= 1'b0;
            
            // Reset parser states
            parse_state_0_0 <= 3'd0; parse_state_0_1 <= 3'd0;
            parse_state_1_0 <= 3'd0; parse_state_1_1 <= 3'd0;
            parse_state_2_0 <= 3'd0; parse_state_2_1 <= 3'd0;
            parse_state_3_0 <= 3'd0; parse_state_3_1 <= 3'd0;
            
            // Reset parser registers
            char_index_0_0 <= 8'd0; char_index_0_1 <= 8'd0;
            char_index_1_0 <= 8'd0; char_index_1_1 <= 8'd0;
            char_index_2_0 <= 8'd0; char_index_2_1 <= 8'd0;
            char_index_3_0 <= 8'd0; char_index_3_1 <= 8'd0;
            
            int_part_0_0 <= 10'd0; int_part_0_1 <= 10'd0;
            int_part_1_0 <= 10'd0; int_part_1_1 <= 10'd0;
            int_part_2_0 <= 10'd0; int_part_2_1 <= 10'd0;
            int_part_3_0 <= 10'd0; int_part_3_1 <= 10'd0;
            
            frac_part_0_0 <= 7'd0; frac_part_0_1 <= 7'd0;
            frac_part_1_0 <= 7'd0; frac_part_1_1 <= 7'd0;
            frac_part_2_0 <= 7'd0; frac_part_2_1 <= 7'd0;
            frac_part_3_0 <= 7'd0; frac_part_3_1 <= 7'd0;
            
            has_decimal_0_0 <= 1'b0; has_decimal_0_1 <= 1'b0;
            has_decimal_1_0 <= 1'b0; has_decimal_1_1 <= 1'b0;
            has_decimal_2_0 <= 1'b0; has_decimal_2_1 <= 1'b0;
            has_decimal_3_0 <= 1'b0; has_decimal_3_1 <= 1'b0;
            
            is_alpha_0_0 <= 1'b0; is_alpha_0_1 <= 1'b0;
            is_alpha_1_0 <= 1'b0; is_alpha_1_1 <= 1'b0;
            is_alpha_2_0 <= 1'b0; is_alpha_2_1 <= 1'b0;
            is_alpha_3_0 <= 1'b0; is_alpha_3_1 <= 1'b0;
            
            first_alpha_0_0 <= 8'd0; first_alpha_0_1 <= 8'd0;
            first_alpha_1_0 <= 8'd0; first_alpha_1_1 <= 8'd0;
            first_alpha_2_0 <= 8'd0; first_alpha_2_1 <= 8'd0;
            first_alpha_3_0 <= 8'd0; first_alpha_3_1 <= 8'd0;
            
            temp_result_0_0 <= 32'd0; temp_result_0_1 <= 32'd0;
            temp_result_1_0 <= 32'd0; temp_result_1_1 <= 32'd0;
            temp_result_2_0 <= 32'd0; temp_result_2_1 <= 32'd0;
            temp_result_3_0 <= 32'd0; temp_result_3_1 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        current_pair <= 2'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process all pairs in parallel
                    // Pair 0
                    if (parse_state_0_0 == 3'd0) begin
                        char_index_0_0 <= 8'd0;
                        int_part_0_0 <= 10'd0;
                        frac_part_0_0 <= 7'd0;
                        has_decimal_0_0 <= 1'b0;
                        is_alpha_0_0 <= 1'b0;
                        first_alpha_0_0 <= 8'd0;
                        parse_state_0_0 <= 3'd1;
                    end else if (parse_state_0_0 == 3'd1) begin
                        if (char_index_0_0 < 8'd8) begin
                            if (pair_0_str_0[char_index_0_0] == 8'd32) begin
                                // Space - skip
                                char_index_0_0 <= char_index_0_0 + 8'd1;
                            end else if (pair_0_str_0[char_index_0_0] >= 8'd48 && pair_0_str_0[char_index_0_0] <= 8'd57) begin
                                // Digit
                                if (has_decimal_0_0) begin
                                    frac_part_0_0 <= frac_part_0_0 * 10 + (pair_0_str_0[char_index_0_0] - 8'd48);
                                end else begin
                                    int_part_0_0 <= int_part_0_0 * 10 + (pair_0_str_0[char_index_0_0] - 8'd48);
                                end
                                char_index_0_0 <= char_index_0_0 + 8'd1;
                            end else if (pair_0_str_0[char_index_0_0] == 8'd46) begin
                                // Decimal point
                                has_decimal_0_0 <= 1'b1;
                                char_index_0_0 <= char_index_0_0 + 8'd1;
                            end else if (pair_0_str_0[char_index_0_0] >= 8'd97 && pair_0_str_0[char_index_0_0] <= 8'd122) begin
                                // Alpha character
                                is_alpha_0_0 <= 1'b1;
                                first_alpha_0_0 <= pair_0_str_0[char_index_0_0];
                                parse_state_0_0 <= 3'd2;
                            end else begin
                                char_index_0_0 <= char_index_0_0 + 8'd1;
                            end
                        end else begin
                            parse_state_0_0 <= 3'd2;
                        end
                    end else if (parse_state_0_0 == 3'd2) begin
                        if (is_alpha_0_0) begin
                            temp_result_0_0 <= {first_alpha_0_0, 24'd0};
                        end else begin
                            // Fixed-point conversion: (int_part * 100 + frac_part) * 65536 / 100
                            temp_result_0_0 <= ((int_part_0_0 * 10'd100 + frac_part_0_0) * 32'd65536) / 10'd100;
                        end
                        parse_state_0_0 <= 3'd3;
                    end
                    
                    // Pair 0 string 1
                    if (parse_state_0_1 == 3'd0) begin
                        char_index_0_1 <= 8'd0;
                        int_part_0_1 <= 10'd0;
                        frac_part_0_1 <= 7'd0;
                        has_decimal_0_1 <= 1'b0;
                        is_alpha_0_1 <= 1'b0;
                        first_alpha_0_1 <= 8'd0;
                        parse_state_0_1 <= 3'd1;
                    end else if (parse_state_0_1 == 3'd1) begin
                        if (char_index_0_1 < 8'd8) begin
                            if (pair_0_str_1[char_index_0_1] == 8'd32) begin
                                char_index_0_1 <= char_index_0_1 + 8'd1;
                            end else if (pair_0_str_1[char_index_0_1] >= 8'd48 && pair_0_str_1[char_index_0_1] <= 8'd57) begin
                                if (has_decimal_0_1) begin
                                    frac_part_0_1 <= frac_part_0_1 * 10 + (pair_0_str_1[char_index_0_1] - 8'd48);
                                end else begin
                                    int_part_0_1 <= int_part_0_1 * 10 + (pair_0_str_1[char_index_0_1] - 8'd48);
                                end
                                char_index_0_1 <= char_index_0_1 + 8'd1;
                            end else if (pair_0_str_1[char_index_0_1] == 8'd46) begin
                                has_decimal_0_1 <= 1'b1;
                                char_index_0_1 <= char_index_0_1 + 8'd1;
                            end else if (pair_0_str_1[char_index_0_1] >= 8'd97 && pair_0_str_1[char_index_0_1] <= 8'd122) begin
                                is_alpha_0_1 <= 1'b1;
                                first_alpha_0_1 <= pair_0_str_1[char_index_0_1];
                                parse_state_0_1 <= 3'd2;
                            end else begin
                                char_index_0_1 <= char_index_0_1 + 8'd1;
                            end
                        end else begin
                            parse_state_0_1 <= 3'd2;
                        end
                    end else if (parse_state_0_1 == 3'd2) begin
                        if (is_alpha_0_1) begin
                            temp_result_0_1 <= {first_alpha_0_1, 24'd0};
                        end else begin
                            temp_result_0_1 <= ((int_part_0_1 * 10'd100 + frac_part_0_1) * 32'd65536) / 10'd100;
                        end
                        parse_state_0_1 <= 3'd3;
                    end
                    
                    // Pair 1 string 0
                    if (parse_state_1_0 == 3'd0) begin
                        char_index_1_0 <= 8'd0;
                        int_part_1_0 <= 10'd0;
                        frac_part_1_0 <= 7'd0;
                        has_decimal_1_0 <= 1'b0;
                        is_alpha_1_0 <= 1'b0;
                        first_alpha_1_0 <= 8'd0;
                        parse_state_1_0 <= 3'd1;
                    end else if (parse_state_1_0 == 3'd1) begin
                        if (char_index_1_0 < 8'd8) begin
                            if (pair_1_str_0[char_index_1_0] == 8'd32) begin
                                char_index_1_0 <= char_index_1_0 + 8'd1;
                            end else if (pair_1_str_0[char_index_1_0] >= 8'd48 && pair_1_str_0[char_index_1_0] <= 8'd57) begin
                                if (has_decimal_1_0) begin
                                    frac_part_1_0 <= frac_part_1_0 * 10 + (pair_1_str_0[char_index_1_0] - 8'd48);
                                end else begin
                                    int_part_1_0 <= int_part_1_0 * 10 + (pair_1_str_0[char_index_1_0] - 8'd48);
                                end
                                char_index_1_0 <= char_index_1_0 + 8'd1;
                            end else if (pair_1_str_0[char_index_1_0] == 8'd46) begin
                                has_decimal_1_0 <= 1'b1;
                                char_index_1_0 <= char_index_1_0 + 8'd1;
                            end else if (pair_1_str_0[char_index_1_0] >= 8'd97 && pair_1_str_0[char_index_1_0] <= 8'd122) begin
                                is_alpha_1_0 <= 1'b1;
                                first_alpha_1_0 <= pair_1_str_0[char_index_1_0];
                                parse_state_1_0 <= 3'd2;
                            end else begin
                                char_index_1_0 <= char_index_1_0 + 8'd1;
                            end
                        end else begin
                            parse_state_1_0 <= 3'd2;
                        end
                    end else if (parse_state_1_0 == 3'd2) begin
                        if (is_alpha_1_0) begin
                            temp_result_1_0 <= {first_alpha_1_0, 24'd0};
                        end else begin
                            temp_result_1_0 <= ((int_part_1_0 * 10'd100 + frac_part_1_0) * 32'd65536) / 10'd100;
                        end
                        parse_state_1_0 <= 3'd3;
                    end
                    
                    // Pair 1 string 1
                    if (parse_state_1_1 == 3'd0) begin
                        char_index_1_1 <= 8'd0;
                        int_part_1_1 <= 10'd0;
                        frac_part_1_1 <= 7'd0;
                        has_decimal_1_1 <= 1'b0;
                        is_alpha_1_1 <= 1'b0;
                        first_alpha_1_1 <= 8'd0;
                        parse_state_1_1 <= 3'd1;
                    end else if (parse_state_1_1 == 3'd1) begin
                        if (char_index_1_1 < 8'd8) begin
                            if (pair_1_str_1[char_index_1_1] == 8'd32) begin
                                char_index_1_1 <= char_index_1_1 + 8'd1;
                            end else if (pair_1_str_1[char_index_1_1] >= 8'd48 && pair_1_str_1[char_index_1_1] <= 8'd57) begin
                                if (has_decimal_1_1) begin
                                    frac_part_1_1 <= frac_part_1_1 * 10 + (pair_1_str_1[char_index_1_1] - 8'd48);
                                end else begin
                                    int_part_1_1 <= int_part_1_1 * 10 + (pair_1_str_1[char_index_1_1] - 8'd48);
                                end
                                char_index_1_1 <= char_index_1_1 + 8'd1;
                            end else if (pair_1_str_1[char_index_1_1] == 8'd46) begin
                                has_decimal_1_1 <= 1'b1;
                                char_index_1_1 <= char_index_1_1 + 8'd1;
                            end else if (pair_1_str_1[char_index_1_1] >= 8'd97 && pair_1_str_1[char_index_1_1] <= 8'd122) begin
                                is_alpha_1_1 <= 1'b1;
                                first_alpha_1_1 <= pair_1_str_1[char_index_1_1];
                                parse_state_1_1 <= 3'd2;
                            end else begin
                                char_index_1_1 <= char_index_1_1 + 8'd1;
                            end
                        end else begin
                            parse_state_1_1 <= 3'd2;
                        end
                    end else if (parse_state_1_1 == 3'd2) begin
                        if (is_alpha_1_1) begin
                            temp_result_1_1 <= {first_alpha_1_1, 24'd0};
                        end else begin
                            temp_result_1_1 <= ((int_part_1_1 * 10'd100 + frac_part_1_1) * 32'd65536) / 10'd100;
                        end
                        parse_state_1_1 <= 3'd3;
                    end
                    
                    // Pair 2 string 0
                    if (parse_state_2_0 == 3'd0) begin
                        char_index_2_0 <= 8'd0;
                        int_part_2_0 <= 10'd0;
                        frac_part_2_0 <= 7'd0;
                        has_decimal_2_0 <= 1'b0;
                        is_alpha_2_0 <= 1'b0;
                        first_alpha_2_0 <= 8'd0;
                        parse_state_2_0 <= 3'd1;
                    end else if (parse_state_2_0 == 3'd1) begin
                        if (char_index_2_0 < 8'd8) begin
                            if (pair_2_str_0[char_index_2_0] == 8'd32) begin
                                char_index_2_0 <= char_index_2_0 + 8'd1;
                            end else if (pair_2_str_0[char_index_2_0] >= 8'd48 && pair_2_str_0[char_index_2_0] <= 8'd57) begin
                                if (has_decimal_2_0) begin
                                    frac_part_2_0 <= frac_part_2_0 * 10 + (pair_2_str_0[char_index_2_0] - 8'd48);
                                end else begin
                                    int_part_2_0 <= int_part_2_0 * 10 + (pair_2_str_0[char_index_2_0] - 8'd48);
                                end
                                char_index_2_0 <= char_index_2_0 + 8'd1;
                            end else if (pair_2_str_0[char_index_2_0] == 8'd46) begin
                                has_decimal_2_0 <= 1'b1;
                                char_index_2_0 <= char_index_2_0 + 8'd1;
                            end else if (pair_2_str_0[char_index_2_0] >= 8'd97 && pair_2_str_0[char_index_2_0] <= 8'd122) begin
                                is_alpha_2_0 <= 1'b1;
                                first_alpha_2_0 <= pair_2_str_0[char_index_2_0];
                                parse_state_2_0 <= 3'd2;
                            end else begin
                                char_index_2_0 <= char_index_2_0 + 8'd1;
                            end
                        end else begin
                            parse_state_2_0 <= 3'd2;
                        end
                    end else if (parse_state_2_0 == 3'd2) begin
                        if (is_alpha_2_0) begin
                            temp_result_2_0 <= {first_alpha_2_0, 24'd0};
                        end else begin
                            temp_result_2_0 <= ((int_part_2_0 * 10'd100 + frac_part_2_0) * 32'd65536) / 10'd100;
                        end
                        parse_state_2_0 <= 3'd3;
                    end
                    
                    // Pair 2 string 1
                    if (parse_state_2_1 == 3'd0) begin
                        char_index_2_1 <= 8'd0;
                        int_part_2_1 <= 10'd0;
                        frac_part_2_1 <= 7'd0;
                        has_decimal_2_1 <= 1'b0;
                        is_alpha_2_1 <= 1'b0;
                        first_alpha_2_1 <= 8'd0;
                        parse_state_2_1 <= 3'd1;
                    end else if (parse_state_2_1 == 3'd1) begin
                        if (char_index_2_1 < 8'd8) begin
                            if (pair_2_str_1[char_index_2_1] == 8'd32) begin
                                char_index_2_1 <= char_index_2_1 + 8'd1;
                            end else if (pair_2_str_1[char_index_2_1] >= 8'd48 && pair_2_str_1[char_index_2_1] <= 8'd57) begin
                                if (has_decimal_2_1) begin
                                    frac_part_2_1 <= frac_part_2_1 * 10 + (pair_2_str_1[char_index_2_1] - 8'd48);
                                end else begin
                                    int_part_2_1 <= int_part_2_1 * 10 + (pair_2_str_1[char_index_2_1] - 8'd48);
                                end
                                char_index_2_1 <= char_index_2_1 + 8'd1;
                            end else if (pair_2_str_1[char_index_2_1] == 8'd46) begin
                                has_decimal_2_1 <= 1'b1;
                                char_index_2_1 <= char_index_2_1 + 8'd1;
                            end else if (pair_2_str_1[char_index_2_1] >= 8'd97 && pair_2_str_1[char_index_2_1] <= 8'd122) begin
                                is_alpha_2_1 <= 1'b1;
                                first_alpha_2_1 <= pair_2_str_1[char_index_2_1];
                                parse_state_2_1 <= 3'd2;
                            end else begin
                                char_index_2_1 <= char_index_2_1 + 8'd1;
                            end
                        end else begin
                            parse_state_2_1 <= 3'd2;
                        end
                    end else if (parse_state_2_1 == 3'd2) begin
                        if (is_alpha_2_1) begin
                            temp_result_2_1 <= {first_alpha_2_1, 24'd0};
                        end else begin
                            temp_result_2_1 <= ((int_part_2_1 * 10'd100 + frac_part_2_1) * 32'd65536) / 10'd100;
                        end
                        parse_state_2_1 <= 3'd3;
                    end
                    
                    // Pair 3 string 0
                    if (parse_state_3_0 == 3'd0) begin
                        char_index_3_0 <= 8'd0;
                        int_part_3_0 <= 10'd0;
                        frac_part_3_0 <= 7'd0;
                        has_decimal_3_0 <= 1'b0;
                        is_alpha_3_0 <= 1'b0;
                        first_alpha_3_0 <= 8'd0;
                        parse_state_3_0 <= 3'd1;
                    end else if (parse_state_3_0 == 3'd1) begin
                        if (char_index_3_0 < 8'd8) begin
                            if (pair_3_str_0[char_index_3_0] == 8'd32) begin
                                char_index_3_0 <= char_index_3_0 + 8'd1;
                            end else if (pair_3_str_0[char_index_3_0] >= 8'd48 && pair_3_str_0[char_index_3_0] <= 8'd57) begin
                                if (has_decimal_3_0) begin
                                    frac_part_3_0 <= frac_part_3_0 * 10 + (pair_3_str_0[char_index_3_0] - 8'd48);
                                end else begin
                                    int_part_3_0 <= int_part_3_0 * 10 + (pair_3_str_0[char_index_3_0] - 8'd48);
                                end
                                char_index_3_0 <= char_index_3_0 + 8'd1;
                            end else if (pair_3_str_0[char_index_3_0] == 8'd46) begin
                                has_decimal_3_0 <= 1'b1;
                                char_index_3_0 <= char_index_3_0 + 8'd1;
                            end else if (pair_3_str_0[char_index_3_0] >= 8'd97 && pair_3_str_0[char_index_3_0] <= 8'd122) begin
                                is_alpha_3_0 <= 1'b1;
                                first_alpha_3_0 <= pair_3_str_0[char_index_3_0];
                                parse_state_3_0 <= 3'd2;
                            end else begin
                                char_index_3_0 <= char_index_3_0 + 8'd1;
                            end
                        end else begin
                            parse_state_3_0 <= 3'd2;
                        end
                    end else if (parse_state_3_0 == 3'd2) begin
                        if (is_alpha_3_0) begin
                            temp_result_3_0 <= {first_alpha_3_0, 24'd0};
                        end else begin
                            temp_result_3_0 <= ((int_part_3_0 * 10'd100 + frac_part_3_0) * 32'd65536) / 10'd100;
                        end
                        parse_state_3_0 <= 3'd3;
                    end
                    
                    // Pair 3 string 1
                    if (parse_state_3_1 == 3'd0) begin
                        char_index_3_1 <= 8'd0;
                        int_part_3_1 <= 10'd0;
                        frac_part_3_1 <= 7'd0;
                        has_decimal_3_1 <= 1'b0;
                        is_alpha_3_1 <= 1'b0;
                        first_alpha_3_1 <= 8'd0;
                        parse_state_3_1 <= 3'd1;
                    end else if (parse_state_3_1 == 3'd1) begin
                        if (char_index_3_1 < 8'd8) begin
                            if (pair_3_str_1[char_index_3_1] == 8'd32) begin
                                char_index_3_1 <= char_index_3_1 + 8'd1;
                            end else if (pair_3_str_1[char_index_3_1] >= 8'd48 && pair_3_str_1[char_index_3_1] <= 8'd57) begin
                                if (has_decimal_3_1) begin
                                    frac_part_3_1 <= frac_part_3_1 * 10 + (pair_3_str_1[char_index_3_1] - 8'd48);
                                end else begin
                                    int_part_3_1 <= int_part_3_1 * 10 + (pair_3_str_1[char_index_3_1] - 8'd48);
                                end
                                char_index_3_1 <= char_index_3_1 + 8'd1;
                            end else if (pair_3_str_1[char_index_3_1] == 8'd46) begin
                                has_decimal_3_1 <= 1'b1;
                                char_index_3_1 <= char_index_3_1 + 8'd1;
                            end else if (pair_3_str_1[char_index_3_1] >= 8'd97 && pair_3_str_1[char_index_3_1] <= 8'd122) begin
                                is_alpha_3_1 <= 1'b1;
                                first_alpha_3_1 <= pair_3_str_1[char_index_3_1];
                                parse_state_3_1 <= 3'd2;
                            end else begin
                                char_index_3_1 <= char_index_3_1 + 8'd1;
                            end
                        end else begin
                            parse_state_3_1 <= 3'd2;
                        end
                    end else if (parse_state_3_1 == 3'd2) begin
                        if (is_alpha_3_1) begin
                            temp_result_3_1 <= {first_alpha_3_1, 24'd0};
                        end else begin
                            temp_result_3_1 <= ((int_part_3_1 * 10'd100 + frac_part_3_1) * 32'd65536) / 10'd100;
                        end
                        parse_state_3_1 <= 3'd3;
                    end
                    
                    // Check if all parsers are done
                    if (parse_state_0_0 == 3'd3 && parse_state_0_1 == 3'd3 &&
                        parse_state_1_0 == 3'd3 && parse_state_1_1 == 3'd3 &&
                        parse_state_2_0 == 3'd3 && parse_state_2_1 == 3'd3 &&
                        parse_state_3_0 == 3'd3 && parse_state_3_1 == 3'd3) begin
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Output results
                    result_pair_0_val_0 <= temp_result_0_0;
                    result_pair_0_val_1 <= temp_result_0_1;
                    result_pair_1_val_0 <= temp_result_1_0;
                    result_pair_1_val_1 <= temp_result_1_1;
                    result_pair_2_val_0 <= temp_result_2_0;
                    result_pair_2_val_1 <= temp_result_2_1;
                    result_pair_3_val_0 <= temp_result_3_0;
                    result_pair_3_val_1 <= temp_result_3_1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule