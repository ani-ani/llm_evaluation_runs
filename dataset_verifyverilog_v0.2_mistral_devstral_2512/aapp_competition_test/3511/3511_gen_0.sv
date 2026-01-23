module pokenom_go (
    input clk,
    input rst_n,
    input start,
    input [1:0] query_type,
    input [3:0] u,
    input [3:0] v,
    output reg [63:0] result,
    output reg done
);

    // Constants
    localparam M = 64'd1000000007;
    localparam N = 8;
    localparam Q = 16;

    // Precomputed modular inverses for lengths 1-8
    localparam [63:0] inv_len [9] = '{64'd1, 64'd500000004, 64'd333333336, 64'd250000002, 64'd400000003, 64'd166666668, 64'd142857144, 64'd125000001, 64'd111111112};

    // State machine
    typedef enum logic [1:0] {IDLE, UPDATE, SUM, DONE} state_t;
    state_t state, next_state;

    // Registers for E and E2
    reg [63:0] E [1:N];
    reg [63:0] E2 [1:N];

    // Internal registers
    reg [3:0] current_box;
    reg [63:0] temp_E;
    reg [63:0] temp_E2;
    reg [63:0] accumulator;
    reg [3:0] len;
    reg [63:0] inv_l;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            current_box <= 0;
            accumulator <= 0;
            for (int i = 1; i <= N; i++) begin
                E[i] <= 0;
                E2[i] <= 0;
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
                if (start) begin
                    if (query_type == 2'b01) begin
                        next_state = UPDATE;
                    end else if (query_type == 2'b10) begin
                        next_state = SUM;
                    end
                end
            end
            UPDATE: begin
                if (current_box == v) begin
                    next_state = IDLE;
                end
            end
            SUM: begin
                if (current_box == N) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && query_type == 2'b01) begin
                        len = v - u + 1;
                        inv_l = inv_len[len];
                        current_box <= u;
                    end else if (start && query_type == 2'b10) begin
                        current_box <= 1;
                        accumulator <= 0;
                    end
                end
                UPDATE: begin
                    temp_E = E[current_box];
                    temp_E2 = E2[current_box];
                    E[current_box] <= (temp_E + inv_l) % M;
                    E2[current_box] <= (temp_E2 + 2 * temp_E + inv_l) % M;
                    if (current_box == v) begin
                        current_box <= u;
                    end else begin
                        current_box <= current_box + 1;
                    end
                end
                SUM: begin
                    accumulator <= (accumulator + E2[current_box]) % M;
                    if (current_box == N) begin
                        result <= accumulator;
                    end else begin
                        current_box <= current_box + 1;
                    end
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule