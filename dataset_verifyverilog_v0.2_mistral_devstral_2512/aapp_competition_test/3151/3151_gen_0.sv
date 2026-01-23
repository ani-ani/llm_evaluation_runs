module swimming_hall(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] m,
    output reg [7:0] k,
    output reg valid,
    output reg impossible,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        CHECK_FACTOR,
        FOUND,
        IMPOSSIBLE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] m_temp;
    reg [7:0] k_temp;
    reg found;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            i <= 0;
            j <= 0;
            m <= 0;
            k <= 0;
            valid <= 0;
            impossible <= 0;
            done <= 0;
            found <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == CHECK_FACTOR && next_state == CHECK_FACTOR) begin
                i <= i + 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_FACTOR;
                    i = 1;
                    found = 0;
                    valid = 0;
                    impossible = 0;
                    done = 0;
                end
            end
            CHECK_FACTOR: begin
                if (i < n) begin
                    if (n % i == 0) begin
                        j = n / i;
                        if ((i + j) % 2 == 0 && (j - i) % 2 == 0) begin
                            m_temp = (i + j) / 2;
                            k_temp = (j - i) / 2;
                            found = 1;
                            next_state = FOUND;
                        end
                    end
                end else begin
                    if (!found) begin
                        next_state = IMPOSSIBLE;
                    end
                end
            end
            FOUND: begin
                next_state = IDLE;
                done = 1;
            end
            IMPOSSIBLE: begin
                next_state = IDLE;
                done = 1;
            end
        endcase
    end

    // Output logic
    always @(*) begin
        case (current_state)
            FOUND: begin
                m = m_temp;
                k = k_temp;
                valid = 1;
                impossible = 0;
            end
            IMPOSSIBLE: begin
                m = 0;
                k = 0;
                valid = 0;
                impossible = 1;
            end
            default: begin
                valid = 0;
                impossible = 0;
            end
        endcase
    end

endmodule