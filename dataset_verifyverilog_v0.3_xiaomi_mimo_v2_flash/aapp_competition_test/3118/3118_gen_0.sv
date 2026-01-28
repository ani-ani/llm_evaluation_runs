module shuffle_count(
    input clk,
    input rst_n,
    input start,
    input [2:0] a [0:7],
    input [2:0] b [0:7],
    output reg [7:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMP_A_INV = 3'd1;
    localparam [2:0] COMP_X = 3'd2;
    localparam [2:0] FIND_ORDER = 3'd3;
    localparam [2:0] FIND_D = 3'd4;
    localparam [2:0] COMPUTE_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    localparam [7:0] INF = 8'd255;
    localparam [7:0] MAX_ITER = 8'd16;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] a_inv [0:7];
    reg [2:0] x [0:7];
    reg [2:0] current_power [0:7];
    reg [2:0] next_power [0:7];
    reg [7:0] order;
    reg [7:0] d;
    reg d_found;
    reg [7:0] step;
    reg [7:0] even_candidate;
    reg [7:0] odd_candidate;
    reg [7:0] temp_result;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                a_inv[i] <= 3'd0;
                x[i] <= 3'd0;
                current_power[i] <= 3'd0;
                next_power[i] <= 3'd0;
            end
            order <= 8'd0;
            d <= 8'd0;
            d_found <= 1'b0;
            step <= 8'd0;
            even_candidate <= 8'd0;
            odd_candidate <= 8'd0;
            temp_result <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMP_A_INV;
                    end
                end

                COMP_A_INV: begin
                    // Compute A_inv: find j where a[j] = i
                    for (i = 0; i < 8; i = i + 1) begin
                        if (a[i] == 3'd0) a_inv[0] <= i[2:0];
                        if (a[i] == 3'd1) a_inv[1] <= i[2:0];
                        if (a[i] == 3'd2) a_inv[2] <= i[2:0];
                        if (a[i] == 3'd3) a_inv[3] <= i[2:0];
                        if (a[i] == 3'd4) a_inv[4] <= i[2:0];
                        if (a[i] == 3'd5) a_inv[5] <= i[2:0];
                        if (a[i] == 3'd6) a_inv[6] <= i[2:0];
                        if (a[i] == 3'd7) a_inv[7] <= i[2:0];
                    end
                    state <= COMP_X;
                end

                COMP_X: begin
                    // Compute X = B ∘ A: x[i] = b[a[i]]
                    for (i = 0; i < 8; i = i + 1) begin
                        case (a[i])
                            3'd0: x[i] <= b[0];
                            3'd1: x[i] <= b[1];
                            3'd2: x[i] <= b[2];
                            3'd3: x[i] <= b[3];
                            3'd4: x[i] <= b[4];
                            3'd5: x[i] <= b[5];
                            3'd6: x[i] <= b[6];
                            3'd7: x[i] <= b[7];
                            default: x[i] <= 3'd0;
                        endcase
                    end
                    step <= 8'd0;
                    // Initialize current_power to identity
                    for (i = 0; i < 8; i = i + 1) begin
                        current_power[i] <= i[2:0];
                    end
                    state <= FIND_ORDER;
                end

                FIND_ORDER: begin
                    // Compute next = X ∘ current_power
                    for (i = 0; i < 8; i = i + 1) begin
                        case (current_power[i])
                            3'd0: next_power[i] <= x[0];
                            3'd1: next_power[i] <= x[1];
                            3'd2: next_power[i] <= x[2];
                            3'd3: next_power[i] <= x[3];
                            3'd4: next_power[i] <= x[4];
                            3'd5: next_power[i] <= x[5];
                            3'd6: next_power[i] <= x[6];
                            3'd7: next_power[i] <= x[7];
                            default: next_power[i] <= 3'd0;
                        endcase
                    end
                    step <= step + 8'd1;
                    // Check if next_power equals identity
                    if (next_power[0] == 3'd0 && next_power[1] == 3'd1 && next_power[2] == 3'd2 && next_power[3] == 3'd3 && next_power[4] == 3'd4 && next_power[5] == 3'd5 && next_power[6] == 3'd6 && next_power[7] == 3'd7) begin
                        order <= step + 8'd1;
                        step <= 8'd0;
                        // Reset current_power to identity for next phase
                        for (i = 0; i < 8; i = i + 1) begin
                            current_power[i] <= i[2:0];
                        end
                        state <= FIND_D;
                    end else if (step >= MAX_ITER) begin
                        // Should not happen for valid permutations, but safety
                        order <= MAX_ITER;
                        step <= 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            current_power[i] <= i[2:0];
                        end
                        state <= FIND_D;
                    end else begin
                        // Update current_power to next_power
                        for (i = 0; i < 8; i = i + 1) begin
                            current_power[i] <= next_power[i];
                        end
                        state <= FIND_ORDER;
                    end
                end

                FIND_D: begin
                    // Check if current_power == A_inv
                    if (current_power[0] == a_inv[0] && current_power[1] == a_inv[1] && current_power[2] == a_inv[2] && current_power[3] == a_inv[3] && current_power[4] == a_inv[4] && current_power[5] == a_inv[5] && current_power[6] == a_inv[6] && current_power[7] == a_inv[7]) begin
                        d <= step;
                        d_found <= 1'b1;
                        state <= COMPUTE_RESULT;
                    end else if (step >= order) begin
                        // Did not find A_inv within order
                        d_found <= 1'b0;
                        state <= COMPUTE_RESULT;
                    end else begin
                        // Compute next power
                        for (i = 0; i < 8; i = i + 1) begin
                            case (current_power[i])
                                3'd0: next_power[i] <= x[0];
                                3'd1: next_power[i] <= x[1];
                                3'd2: next_power[i] <= x[2];
                                3'd3: next_power[i] <= x[3];
                                3'd4: next_power[i] <= x[4];
                                3'd5: next_power[i] <= x[5];
                                3'd6: next_power[i] <= x[6];
                                3'd7: next_power[i] <= x[7];
                                default: next_power[i] <= 3'd0;
                            endcase
                        end
                        step <= step + 8'd1;
                        for (i = 0; i < 8; i = i + 1) begin
                            current_power[i] <= next_power[i];
                        end
                        state <= FIND_D;
                    end
                end

                COMPUTE_RESULT: begin
                    even_candidate <= (order << 1); // 2 * order
                    if (d_found) begin
                        odd_candidate <= (d << 1) + 8'd1; // 2*d + 1
                    end else begin
                        odd_candidate <= INF;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    if (even_candidate < odd_candidate) begin
                        temp_result <= even_candidate;
                    end else begin
                        temp_result <= odd_candidate;
                    end
                    result <= (even_candidate < odd_candidate) ? even_candidate : odd_candidate;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule