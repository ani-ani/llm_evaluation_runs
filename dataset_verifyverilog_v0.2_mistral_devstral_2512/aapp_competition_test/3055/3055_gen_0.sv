module thore_checker (
    input clk,
    input rst_n,
    input start,
    input [15:0] scoreboard_size,
    input [127:0] current_name,
    input [127:0] names_above [0:7],
    input [127:0] names_below [0:7],
    output reg [15:0] result_prefix,
    output reg [127:0] result_string,
    output reg done,
    output reg is_awesome,
    output reg sucks
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_FIRST,
        CHECK_SUCKS,
        FIND_PREFIX,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] prefix_len;
    reg [3:0] above_idx;
    reg [3:0] byte_idx;
    reg match_found;
    reg sucks_match;

    // Helper function to compare two byte arrays up to a certain length
    function automatic logic [127:0] compare_bytes;
        input [127:0] a;
        input [127:0] b;
        input [3:0] len;
        integer i;
        begin
            for (i = 0; i < len; i = i + 1) begin
                if (a[8*i +: 8] != b[8*i +: 8]) begin
                    compare_bytes = 1'b0;
                    return;
                end
            end
            compare_bytes = 1'b1;
        end
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result_prefix <= 0;
            result_string <= 0;
            done <= 0;
            is_awesome <= 0;
            sucks <= 0;
            prefix_len <= 0;
            above_idx <= 0;
            byte_idx <= 0;
            match_found <= 0;
            sucks_match <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        done = 0;
        is_awesome = 0;
        sucks = 0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_FIRST;
                end
            end

            CHECK_FIRST: begin
                if (scoreboard_size == 0 || names_above[0] == 0) begin
                    is_awesome = 1;
                    next_state = DONE;
                end else begin
                    next_state = CHECK_SUCKS;
                end
            end

            CHECK_SUCKS: begin
                if (sucks_match) begin
                    sucks = 1;
                    next_state = DONE;
                end else if (above_idx == scoreboard_size - 1) begin
                    next_state = FIND_PREFIX;
                end else begin
                    next_state = CHECK_SUCKS;
                end
            end

            FIND_PREFIX: begin
                if (match_found) begin
                    if (prefix_len == 13) begin
                        next_state = DONE;
                    end else begin
                        next_state = FIND_PREFIX;
                    end
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                done = 1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Combinational logic for state actions
    always @(*) begin
        case (current_state)
            CHECK_SUCKS: begin
                if (above_idx < scoreboard_size) begin
                    if (compare_bytes(names_above[above_idx], current_name, 12)) begin
                        sucks_match = 1;
                    end else begin
                        above_idx = above_idx + 1;
                    end
                end
            end

            FIND_PREFIX: begin
                if (prefix_len < 13) begin
                    match_found = 0;
                    for (int i = 0; i < scoreboard_size; i = i + 1) begin
                        if (compare_bytes(names_above[i], current_name, prefix_len + 1)) begin
                            match_found = 1;
                            break;
                        end
                    end

                    if (!match_found) begin
                        result_prefix = prefix_len + 1;
                        result_string = current_name[127: 8*(16 - (prefix_len + 1))];
                    end else begin
                        prefix_len = prefix_len + 1;
                    end
                end
            end
        endcase
    end

endmodule