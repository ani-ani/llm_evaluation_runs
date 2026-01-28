module encoding_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] i_str [0:15],
    input wire [7:0] o_str [0:15],
    input wire [7:0] i_len,
    input wire [7:0] o_len,
    output reg [1:0] status,
    output reg [127:0] result_plus,
    output reg [127:0] result_minus,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_STRINGS = 3'd1;
    localparam [2:0] FIND_LENGTHS = 3'd2;
    localparam [2:0] CHECK_ENCODING = 3'd3;
    localparam [2:0] OUTPUT_RESULTS = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [7:0] i_ram [0:15];
    reg [7:0] o_ram [0:15];
    reg [7:0] current_i_len, current_o_len;
    reg [3:0] len_plus, len_minus;
    reg [7:0] plus_counter, minus_counter;
    reg [7:0] i_index, o_index;
    reg [7:0] plus_index, minus_index;
    reg [7:0] cycle_count;
    reg [7:0] max_cycles;
    reg match_found;
    reg [127:0] temp_plus, temp_minus;

    // Initialize max cycles
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_cycles <= 8'd256;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            status <= 2'd0;
            done <= 1'b0;
            valid_out <= 1'b0;
            result_plus <= 128'd0;
            result_minus <= 128'd0;
            cycle_count <= 8'd0;
            match_found <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_STRINGS;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_STRINGS: begin
                next_state = FIND_LENGTHS;
            end

            FIND_LENGTHS: begin
                if (cycle_count >= max_cycles) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CHECK_ENCODING;
                end
            end

            CHECK_ENCODING: begin
                if (match_found) begin
                    next_state = OUTPUT_RESULTS;
                end else if (cycle_count >= max_cycles) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = FIND_LENGTHS;
                end
            end

            OUTPUT_RESULTS: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load strings into RAM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_i_len <= 8'd0;
            current_o_len <= 8'd0;
            plus_counter <= 8'd0;
            minus_counter <= 8'd0;
            i_index <= 8'd0;
            o_index <= 8'd0;
            plus_index <= 8'd0;
            minus_index <= 8'd0;
            len_plus <= 4'd0;
            len_minus <= 4'd0;
            match_found <= 1'b0;
            temp_plus <= 128'd0;
            temp_minus <= 128'd0;
        end else begin
            case (state)
                LOAD_STRINGS: begin
                    current_i_len <= i_len;
                    current_o_len <= o_len;
                    // Copy input strings to internal RAM
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        i_ram[i] <= i_str[i];
                        o_ram[i] <= o_str[i];
                    end
                    // Count '+' and '-' in input string
                    plus_counter <= 8'd0;
                    minus_counter <= 8'd0;
                    for (i = 0; i < current_i_len; i = i + 1) begin
                        if (i_ram[i] == 8'd43) begin  // '+' ASCII
                            plus_counter <= plus_counter + 8'd1;
                        end else if (i_ram[i] == 8'd45) begin  // '-' ASCII
                            minus_counter <= minus_counter + 8'd1;
                        end
                    end
                    next_state = FIND_LENGTHS;
                end

                FIND_LENGTHS: begin
                    // Calculate expected output length
                    reg [7:0] expected_len;
                    expected_len = current_i_len - plus_counter - minus_counter + len_plus + len_minus;
                    if (expected_len == current_o_len) begin
                        next_state = CHECK_ENCODING;
                    end else begin
                        // Increment lengths
                        if (len_minus < 4'd16) begin
                            len_minus <= len_minus + 4'd1;
                        end else begin
                            len_minus <= 4'd0;
                            if (len_plus < 4'd16) begin
                                len_plus <= len_plus + 4'd1;
                            end else begin
                                len_plus <= 4'd0;
                                cycle_count <= cycle_count + 8'd1;
                            end
                        end
                    end
                end

                CHECK_ENCODING: begin
                    // Reset indices
                    i_index <= 8'd0;
                    o_index <= 8'd0;
                    plus_index <= 8'd0;
                    minus_index <= 8'd0;
                    match_found <= 1'b1;
                    // Check character by character
                    integer i;
                    for (i = 0; i < current_i_len; i = i + 1) begin
                        if (i_ram[i] == 8'd43) begin  // '+' ASCII
                            // Copy len_plus characters from o_ram to temp_plus
                            integer j;
                            for (j = 0; j < len_plus; j = j + 1) begin
                                temp_plus[(plus_index * 8) +: 8] <= o_ram[o_index];
                                plus_index <= plus_index + 8'd1;
                                o_index <= o_index + 8'd1;
                            end
                        end else if (i_ram[i] == 8'd45) begin  // '-' ASCII
                            // Copy len_minus characters from o_ram to temp_minus
                            integer j;
                            for (j = 0; j < len_minus; j = j + 1) begin
                                temp_minus[(minus_index * 8) +: 8] <= o_ram[o_index];
                                minus_index <= minus_index + 8'd1;
                                o_index <= o_index + 8'd1;
                            end
                        end else begin
                            if (i_ram[i] != o_ram[o_index]) begin
                                match_found <= 1'b0;
                            end
                            o_index <= o_index + 8'd1;
                        end
                    end
                    if (match_found) begin
                        result_plus <= temp_plus;
                        result_minus <= temp_minus;
                        valid_out <= 1'b1;
                    end
                    // Increment lengths
                    if (len_minus < 4'd16) begin
                        len_minus <= len_minus + 4'd1;
                    end else begin
                        len_minus <= 4'd0;
                        if (len_plus < 4'd16) begin
                            len_plus <= len_plus + 4'd1;
                        end else begin
                            len_plus <= 4'd0;
                            cycle_count <= cycle_count + 8'd1;
                        end
                    end
                end

                OUTPUT_RESULTS: begin
                    status <= 2'd2;
                    done <= 1'b1;
                end

                DONE_STATE: begin
                    if (!match_found) begin
                        status <= 2'd3;
                    end
                    done <= 1'b1;
                end

                default: begin
                    status <= 2'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Status update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status <= 2'd0;
        end else begin
            case (state)
                IDLE: status <= 2'd0;
                LOAD_STRINGS: status <= 2'd1;
                FIND_LENGTHS: status <= 2'd1;
                CHECK_ENCODING: status <= 2'd1;
                OUTPUT_RESULTS: status <= 2'd2;
                DONE_STATE: begin
                    if (match_found) begin
                        status <= 2'd2;
                    end else begin
                        status <= 2'd3;
                    end
                end
                default: status <= 2'd0;
            endcase
        end
    end

endmodule