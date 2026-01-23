module CriticOrderSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [13:0] k,
    input wire [3:0] a0, a1, a2, a3, a4, a5, a6, a7,
    output reg done,
    output reg possible,
    output reg [3:0] p0, p1, p2, p3, p4, p5, p6, p7,
    output reg [3:0] valid_indices
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_COND = 3'd1;
    localparam [2:0] SORT_INIT  = 3'd2;
    localparam [2:0] SORT_LOOP  = 3'd3;
    localparam [2:0] BUILD_PERM = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] x;
    reg [3:0] i, j;
    reg [3:0] sorted_a [0:7];
    reg [3:0] sorted_idx [0:7];
    reg [3:0] temp_val;
    reg [3:0] temp_idx;
    reg [3:0] perm_count;
    reg [2:0] sort_pass;
    reg swap_needed;

    // Combinational logic
    wire k_mod_m_zero;
    wire k_in_range;
    wire x_valid;
    
    assign k_mod_m_zero = (m != 0) && ((k % m) == 0);
    assign k_in_range = (k >= m) && (k <= n * m) && (k != 0);
    assign x_valid = (m != 0) && (k / m <= n);

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CHECK_COND;
            CHECK_COND: begin
                if (!k_mod_m_zero || !k_in_range || !x_valid) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SORT_INIT;
                end
            end
            SORT_INIT: next_state = SORT_LOOP;
            SORT_LOOP: begin
                if (sort_pass >= n) begin
                    next_state = BUILD_PERM;
                end else if (i >= n - 1) begin
                    next_state = SORT_INIT;
                end else begin
                    next_state = SORT_LOOP;
                end
            end
            BUILD_PERM: next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            possible <= 1'b0;
            valid_indices <= 4'd0;
            p0 <= 4'd0; p1 <= 4'd0; p2 <= 4'd0; p3 <= 4'd0;
            p4 <= 4'd0; p5 <= 4'd0; p6 <= 4'd0; p7 <= 4'd0;
            x <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            sort_pass <= 3'd0;
            swap_needed <= 1'b0;
            perm_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    valid_indices <= 4'd0;
                    p0 <= 4'd0; p1 <= 4'd0; p2 <= 4'd0; p3 <= 4'd0;
                    p4 <= 4'd0; p5 <= 4'd0; p6 <= 4'd0; p7 <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    sort_pass <= 3'd0;
                    perm_count <= 4'd0;
                end
                CHECK_COND: begin
                    x <= k / m;
                end
                SORT_INIT: begin
                    // Initialize sorted arrays from input
                    sorted_a[0] <= a0; sorted_idx[0] <= 0;
                    sorted_a[1] <= a1; sorted_idx[1] <= 1;
                    sorted_a[2] <= a2; sorted_idx[2] <= 2;
                    sorted_a[3] <= a3; sorted_idx[3] <= 3;
                    sorted_a[4] <= a4; sorted_idx[4] <= 4;
                    sorted_a[5] <= a5; sorted_idx[5] <= 5;
                    sorted_a[6] <= a6; sorted_idx[6] <= 6;
                    sorted_a[7] <= a7; sorted_idx[7] <= 7;
                    i <= 4'd0;
                    j <= 4'd0;
                end
                SORT_LOOP: begin
                    // Bubble sort - single pass per cycle
                    if (i < n - 1) begin
                        if (sorted_a[i] < sorted_a[i + 1]) begin
                            // Swap values
                            temp_val <= sorted_a[i];
                            sorted_a[i] <= sorted_a[i + 1];
                            sorted_a[i + 1] <= temp_val;
                            // Swap indices
                            temp_idx <= sorted_idx[i];
                            sorted_idx[i] <= sorted_idx[i + 1];
                            sorted_idx[i + 1] <= temp_idx;
                        end
                        i <= i + 1;
                    end else begin
                        sort_pass <= sort_pass + 1;
                        i <= 4'd0;
                    end
                end
                BUILD_PERM: begin
                    // Build permutation based on x givers
                    if (perm_count < n) begin
                        if (perm_count < x) begin
                            // First x critics give m each
                            case (perm_count)
                                4'd0: p0 <= sorted_idx[0] + 1;
                                4'd1: p1 <= sorted_idx[1] + 1;
                                4'd2: p2 <= sorted_idx[2] + 1;
                                4'd3: p3 <= sorted_idx[3] + 1;
                                4'd4: p4 <= sorted_idx[4] + 1;
                                4'd5: p5 <= sorted_idx[5] + 1;
                                4'd6: p6 <= sorted_idx[6] + 1;
                                4'd7: p7 <= sorted_idx[7] + 1;
                            endcase
                        end else begin
                            // Remaining critics get 0
                            case (perm_count)
                                4'd0: p0 <= 4'd0;
                                4'd1: p1 <= 4'd0;
                                4'd2: p2 <= 4'd0;
                                4'd3: p3 <= 4'd0;
                                4'd4: p4 <= 4'd0;
                                4'd5: p5 <= 4'd0;
                                4'd6: p6 <= 4'd0;
                                4'd7: p7 <= 4'd0;
                            endcase
                        end
                        perm_count <= perm_count + 1;
                    end else begin
                        possible <= 1'b1;
                        valid_indices <= n;
                        done <= 1'b1;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b0;
                    perm_count <= 4'd0;
                    sort_pass <= 3'd0;
                end
            endcase
        end
    end

endmodule