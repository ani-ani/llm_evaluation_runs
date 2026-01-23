module tarot_knight_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] card_r [0:3],
    input [7:0] card_c [0:3],
    input [7:0] card_a [0:3],
    input [7:0] card_b [0:3],
    input [7:0] card_p [0:3],
    output reg [15:0] min_cost,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PERMUTE,
        TRACE_PATH,
        FINISH
    } state_t;
    state_t state, next_state;

    // Permutation generation
    reg [4:0] perm_counter;
    reg [1:0] perm [0:3];
    reg [1:0] perm_index;

    // Path tracing
    reg [7:0] current_r, current_c;
    reg [7:0] owned_a [0:3];
    reg [7:0] owned_b [0:3];
    reg [15:0] current_cost;
    reg [1:0] card_index;
    reg valid_path;

    // GCD calculation
    reg [7:0] gcd_a, gcd_b;
    reg [7:0] gcd_result;
    reg [2:0] gcd_state;
    reg [7:0] gcd_temp;

    // Reachability check
    reg [7:0] dr, dc;
    reg reachable;

    // Minimum cost tracking
    reg [15:0] temp_min_cost;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            perm_counter <= 0;
            perm_index <= 0;
            card_index <= 0;
            current_cost <= 0;
            valid_path <= 1;
            min_cost <= 16'hFFFF;
            done <= 0;
            gcd_state <= 0;
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
                    next_state = PERMUTE;
                    perm_counter = 0;
                    perm_index = 0;
                    card_index = 0;
                    current_cost = 0;
                    valid_path = 1;
                    min_cost = 16'hFFFF;
                    done = 0;
                end
            end
            PERMUTE: begin
                if (perm_index == 3) begin
                    next_state = TRACE_PATH;
                    card_index = 0;
                    current_r = card_r[0];
                    current_c = card_c[0];
                    owned_a[0] = card_a[0];
                    owned_b[0] = card_b[0];
                    current_cost = 0;
                    valid_path = 1;
                end
            end
            TRACE_PATH: begin
                if (card_index == 3) begin
                    // Check reachability to (0,0)
                    dr = 0 - current_r;
                    dc = 0 - current_c;
                    // Calculate GCD of owned moves
                    gcd_a = owned_a[0];
                    gcd_b = owned_b[0];
                    gcd_state = 1;
                    // Wait for GCD result
                    if (gcd_state == 0) begin
                        if (gcd_result != 0 && (dr % gcd_result == 0) && (dc % gcd_result == 0)) begin
                            if (current_cost < min_cost) begin
                                min_cost = current_cost;
                            end
                        end
                        // Move to next permutation
                        perm_counter = perm_counter + 1;
                        if (perm_counter == 24) begin
                            next_state = FINISH;
                        end else begin
                            next_state = PERMUTE;
                            perm_index = 0;
                        end
                    end
                end else begin
                    // Check reachability to next card
                    dr = card_r[perm[card_index]] - current_r;
                    dc = card_c[perm[card_index]] - current_c;
                    // Calculate GCD of owned moves
                    gcd_a = owned_a[0];
                    gcd_b = owned_b[0];
                    gcd_state = 1;
                    // Wait for GCD result
                    if (gcd_state == 0) begin
                        if (gcd_result != 0 && (dr % gcd_result == 0) && (dc % gcd_result == 0)) begin
                            // Update position and cost
                            current_r = card_r[perm[card_index]];
                            current_c = card_c[perm[card_index]];
                            current_cost = current_cost + card_p[perm[card_index]];
                            owned_a[card_index + 1] = card_a[perm[card_index]];
                            owned_b[card_index + 1] = card_b[perm[card_index]];
                            card_index = card_index + 1;
                        end else begin
                            valid_path = 0;
                            // Skip to next permutation
                            perm_counter = perm_counter + 1;
                            if (perm_counter == 24) begin
                                next_state = FINISH;
                            end else begin
                                next_state = PERMUTE;
                                perm_index = 0;
                            end
                        end
                    end
                end
            end
            FINISH: begin
                done = 1;
            end
        endcase
    end

    // Permutation generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            perm_counter <= 0;
            perm_index <= 0;
        end else if (state == PERMUTE) begin
            if (perm_index < 4) begin
                case (perm_counter)
                    0: perm <= '{1, 2, 3, 0};
                    1: perm <= '{1, 3, 2, 0};
                    2: perm <= '{2, 1, 3, 0};
                    3: perm <= '{2, 3, 1, 0};
                    4: perm <= '{3, 1, 2, 0};
                    5: perm <= '{3, 2, 1, 0};
                    default: perm <= '{0, 0, 0, 0};
                endcase
                perm_index = perm_index + 1;
            end
        end
    end

    // GCD calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_state <= 0;
            gcd_result <= 0;
        end else if (gcd_state != 0) begin
            case (gcd_state)
                1: begin
                    if (gcd_a == 0) begin
                        gcd_result = gcd_b;
                        gcd_state = 0;
                    end else if (gcd_b == 0) begin
                        gcd_result = gcd_a;
                        gcd_state = 0;
                    end else begin
                        gcd_temp = gcd_a % gcd_b;
                        gcd_state = 2;
                    end
                end
                2: begin
                    gcd_a = gcd_b;
                    gcd_b = gcd_temp;
                    gcd_state = 1;
                end
            endcase
        end
    end

endmodule