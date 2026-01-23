module longest_repeated_substring (
    input clk,
    input rst_n,
    input start,
    input [4:0] char_in [0:15],
    output reg [4:0] max_len,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_LEN,
        CHECK_DUPLICATES,
        NEXT_LEN,
        OUTPUT
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] current_len;
    reg [3:0] i, j, k;
    reg [4:0] char_i, char_j;
    reg match_found;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_len <= 0;
            done <= 0;
            current_len <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            match_found <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CHECK_LEN;
            end
            CHECK_LEN: begin
                next_state = CHECK_DUPLICATES;
            end
            CHECK_DUPLICATES: begin
                if (match_found) begin
                    next_state = OUTPUT;
                end else if (j == 16 - current_len) begin
                    next_state = NEXT_LEN;
                end
            end
            NEXT_LEN: begin
                if (current_len == 0) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = CHECK_DUPLICATES;
                end
            end
            OUTPUT: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_len <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            match_found <= 0;
        end else begin
            case (current_state)
                CHECK_LEN: begin
                    current_len <= 15;
                    i <= 0;
                    j <= 0;
                    k <= 0;
                    match_found <= 0;
                end
                CHECK_DUPLICATES: begin
                    if (k == current_len - 1) begin
                        if (char_i == char_j) begin
                            match_found <= 1;
                            max_len <= current_len;
                        end
                        k <= 0;
                        j <= j + 1;
                        if (j == i + 1) j <= j + 1;
                        if (j >= 16 - current_len + 1) begin
                            i <= i + 1;
                            j <= 0;
                        end
                    end else begin
                        k <= k + 1;
                    end
                end
                NEXT_LEN: begin
                    current_len <= current_len - 1;
                    i <= 0;
                    j <= 0;
                    k <= 0;
                    match_found <= 0;
                end
                OUTPUT: begin
                    done <= 1;
                end
                default: begin
                    done <= 0;
                end
            endcase
        end
    end

    // Character comparison logic
    assign char_i = char_in[i + k];
    assign char_j = char_in[j + k];

endmodule