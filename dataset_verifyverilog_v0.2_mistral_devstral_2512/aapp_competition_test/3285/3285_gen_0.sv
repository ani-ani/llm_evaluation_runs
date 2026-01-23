module sds_finder (
    input clk,
    input rst_n,
    input start,
    input [15:0] r,
    input [27:0] m,
    output reg [13:0] result,
    output reg done,
    output reg found
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_EXISTING = 3'b010;
    localparam COMPUTE_NEXT = 3'b011;
    localparam UPDATE_SET = 3'b100;
    localparam CHECK_COMPLETE = 3'b101;
    localparam DONE = 3'b110;

    // State register
    reg [2:0] state, next_state;

    // Sequence tracking
    reg [13:0] n;
    reg [15:0] A_prev;
    reg [15:0] A_next;
    reg [15:0] d;

    // Set S tracking (values and differences)
    reg [19:0] set_S [0:15]; // Track up to 16 sequence values
    reg [19:0] diff_S [0:15]; // Track differences between values
    reg [19:0] current_diffs [0:15]; // Temporary storage for new differences

    // Control signals
    reg [15:0] d_counter;
    reg d_found;
    reg m_in_S;
    reg [13:0] temp_result;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            found <= 0;
            result <= 0;
            n <= 0;
            A_prev <= 0;
            d <= 0;
            d_counter <= 0;
            d_found <= 0;
            m_in_S <= 0;
            for (int i = 0; i < 16; i++) begin
                set_S[i] <= 0;
                diff_S[i] <= 0;
                current_diffs[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = CHECK_EXISTING;
            end
            CHECK_EXISTING: begin
                if (m_in_S) next_state = DONE;
                else next_state = COMPUTE_NEXT;
            end
            COMPUTE_NEXT: begin
                if (d_found) next_state = UPDATE_SET;
            end
            UPDATE_SET: begin
                next_state = CHECK_COMPLETE;
            end
            CHECK_COMPLETE: begin
                if (n > 10000 || m_in_S) next_state = DONE;
                else next_state = COMPUTE_NEXT;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State actions
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (state)
                INIT: begin
                    // Initialize sequence
                    A_prev <= r;
                    n <= 1;
                    set_S[0] <= r;
                    // Check if m is r
                    m_in_S <= (m == r);
                end
                CHECK_EXISTING: begin
                    // Check if m is in set_S or diff_S
                    m_in_S <= 0;
                    for (int i = 0; i < 16; i++) begin
                        if (set_S[i] == m || diff_S[i] == m) begin
                            m_in_S <= 1;
                            temp_result <= n;
                        end
                    end
                end
                COMPUTE_NEXT: begin
                    // Find smallest d not in S
                    d_found <= 0;
                    if (d_counter < 16'hFFFF) begin
                        d_counter <= d_counter + 1;
                        // Check if d_counter is in set_S or diff_S
                        d_found <= 1;
                        for (int i = 0; i < 16; i++) begin
                            if (set_S[i] == d_counter || diff_S[i] == d_counter) begin
                                d_found <= 0;
                            end
                        end
                        if (d_found) d <= d_counter;
                    end
                end
                UPDATE_SET: begin
                    // Compute next term
                    A_next <= A_prev + d;
                    // Update set_S (shift and add new value)
                    for (int i = 15; i > 0; i--) begin
                        set_S[i] <= set_S[i-1];
                    end
                    set_S[0] <= A_next;
                    // Compute new differences
                    for (int i = 0; i < 16; i++) begin
                        if (set_S[i] != 0) begin
                            current_diffs[i] <= (A_next > set_S[i]) ? (A_next - set_S[i]) : (set_S[i] - A_next);
                        end else begin
                            current_diffs[i] <= 0;
                        end
                    end
                    // Update diff_S with new differences
                    for (int i = 0; i < 16; i++) begin
                        if (current_diffs[i] != 0) begin
                            // Shift and add
                            for (int j = 15; j > 0; j--) begin
                                diff_S[j] <= diff_S[j-1];
                            end
                            diff_S[0] <= current_diffs[i];
                        end
                    end
                    // Update for next iteration
                    A_prev <= A_next;
                    n <= n + 1;
                    d_counter <= 0;
                end
                CHECK_COMPLETE: begin
                    // Check if m is in set_S or diff_S
                    m_in_S <= 0;
                    for (int i = 0; i < 16; i++) begin
                        if (set_S[i] == m || diff_S[i] == m) begin
                            m_in_S <= 1;
                            temp_result <= n;
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                    found <= m_in_S;
                    result <= temp_result;
                end
            endcase
        end
    end

endmodule