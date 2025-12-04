module rectangle_extensions(
    input  clk,
    input  rst_n,
    input  start,
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] h,
    input  [31:0] w,
    input  [15:0][31:0] factors,
    input  [4:0]  num_factors,
    output reg [4:0] min_count,
    output reg      done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE    = 3'd0,
        SORT    = 3'd1,
        PROCESS = 3'd2,
        CHECK   = 3'd3,
        DONE_ST = 3'd4
    } state_t;

    state_t state, next_state;

    // Internal storage for sorted factors (descending)
    reg [31:0] sorted [15:0];
    reg [4:0]  sort_i;      // outer loop index
    reg [4:0]  sort_j;      // inner loop index
    reg        sort_done;

    // Bubble-sort single-swap temp
    reg [31:0] tmp_factor;

    // DP reachable sets
    // We maintain two sets (ping-pong) of reachable (h,w) pairs.
    // Each set is 16 entries (worst-case growth bounded by num_factors).
    typedef struct packed {
        logic        valid;
        logic [31:0] hh;
        logic [31:0] ww;
    } hw_t;

    hw_t cur_set [15:0];
    hw_t nxt_set [15:0];

    reg [4:0] cur_count;          // current extension count (1..num_factors)
    reg [4:0] cur_size;           // number of valid entries in cur_set
    reg [4:0] nxt_size;           // number of valid entries in nxt_set

    reg        success;           // any configuration satisfied target

    // Control flags
    reg start_d;                  // for edge detection
    wire start_pulse = start & ~start_d;

    //------------------------------------------------------------------------------
    // Sequential: state, start edge, and main registers
    //------------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            start_d    <= 1'b0;
        end else begin
            state      <= next_state;
            start_d    <= start;
        end
    end

    //------------------------------------------------------------------------------
    // Bubble sort over multiple cycles (descending order)
    // One compare-swap per cycle for simplicity.
    //------------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_i    <= 5'd0;
            sort_j    <= 5'd0;
            sort_done <= 1'b0;
        end else begin
            if (state == IDLE) begin
                sort_i    <= 5'd0;
                sort_j    <= 5'd0;
                sort_done <= 1'b0;
            end else if (state == SORT && !sort_done) begin
                if (num_factors <= 1) begin
                    sort_done <= 1'b1;
                end else begin
                    if (sort_i < num_factors) begin
                        if (sort_j + 1 < num_factors - sort_i) begin
                            // compare sorted[sort_j] and sorted[sort_j+1]
                            if (sorted[sort_j] < sorted[sort_j+1]) begin
                                tmp_factor              <= sorted[sort_j];
                                sorted[sort_j]         <= sorted[sort_j+1];
                                sorted[sort_j+1]       <= tmp_factor;
                            end
                            sort_j <= sort_j + 1'b1;
                        end else begin
                            sort_j <= 5'd0;
                            sort_i <= sort_i + 1'b1;
                        end
                    end else begin
                        sort_done <= 1'b1;
                    end
                end
            end
        end
    end

    //------------------------------------------------------------------------------
    // Main datapath and control
    //------------------------------------------------------------------------------
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal regs
            done      <= 1'b0;
            min_count <= 5'd31;
            cur_count <= 5'd0;
            cur_size  <= 5'd0;
            nxt_size  <= 5'd0;
            success   <= 1'b0;

            for (i = 0; i < 16; i = i + 1) begin
                sorted[i]       <= 32'd0;
                cur_set[i].valid<= 1'b0;
                cur_set[i].hh   <= 32'd0;
                cur_set[i].ww   <= 32'd0;
                nxt_set[i].valid<= 1'b0;
                nxt_set[i].hh   <= 32'd0;
                nxt_set[i].ww   <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done      <= 1'b0;
                    min_count <= 5'd31;
                    success   <= 1'b0;

                    if (start_pulse) begin
                        // Load factors into sorted buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < num_factors)
                                sorted[i] <= factors[i];
                            else
                                sorted[i] <= 32'd0;
                        end

                        // Initialize reachable set with (h,w) and (w,h)
                        for (i = 0; i < 16; i = i + 1) begin
                            cur_set[i].valid <= 1'b0;
                            nxt_set[i].valid <= 1'b0;
                            cur_set[i].hh    <= 32'd0;
                            cur_set[i].ww    <= 32'd0;
                            nxt_set[i].hh    <= 32'd0;
                            nxt_set[i].ww    <= 32'd0;
                        end

                        cur_set[0].valid <= 1'b1;
                        cur_set[0].hh    <= h;
                        cur_set[0].ww    <= w;

                        if (h != w) begin
                            cur_set[1].valid <= 1'b1;
                            cur_set[1].hh    <= w;
                            cur_set[1].ww    <= h;
                            cur_size         <= 5'd2;
                        end else begin
                            cur_size         <= 5'd1;
                        end

                        cur_count <= 5'd0;
                    end
                end

                SORT: begin
                    // Sorting progresses in dedicated always above
                    // Nothing extra here
                end

                PROCESS: begin
                    // Use factor for this step (index cur_count)
                    // cur_count is count BEFORE applying this factor
                    // Next count = cur_count + 1
                    // Build nxt_set from cur_set

                    // Clear next set
                    for (i = 0; i < 16; i = i + 1) begin
                        nxt_set[i].valid <= 1'b0;
                        nxt_set[i].hh    <= 32'd0;
                        nxt_set[i].ww    <= 32'd0;
                    end

                    nxt_size <= 5'd0;

                    if (cur_size != 0 && cur_count < num_factors) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (cur_set[i].valid) begin
                                // Apply current factor to either dimension
                                // Factor index: cur_count (0-based)
                                // New1: (hh * f, ww)
                                // New2: (hh, ww * f)
                                // Limit total unique entries to 16 with simple duplicate check
                                automatic logic [31:0] f;
                                automatic logic [31:0] nh1, nw1, nh2, nw2;
                                automatic integer k;

                                f   = sorted[cur_count];
                                nh1 = cur_set[i].hh * f;
                                nw1 = cur_set[i].ww;
                                nh2 = cur_set[i].hh;
                                nw2 = cur_set[i].ww * f;

                                // Insert (nh1,nw1)
                                if (nxt_size < 16) begin
                                    automatic bit dup1;
                                    dup1 = 1'b0;
                                    for (k = 0; k < 16; k = k + 1) begin
                                        if (nxt_set[k].valid &&
                                            nxt_set[k].hh == nh1 &&
                                            nxt_set[k].ww == nw1)
                                            dup1 = 1'b1;
                                    end
                                    if (!dup1) begin
                                        nxt_set[nxt_size].valid <= 1'b1;
                                        nxt_set[nxt_size].hh    <= nh1;
                                        nxt_set[nxt_size].ww    <= nw1;
                                        nxt_size                <= nxt_size + 1'b1;
                                    end
                                end

                                // Insert (nh2,nw2)
                                if (nxt_size < 16) begin
                                    automatic bit dup2;
                                    dup2 = 1'b0;
                                    for (k = 0; k < 16; k = k + 1) begin
                                        if (nxt_set[k].valid &&
                                            nxt_set[k].hh == nh2 &&
                                            nxt_set[k].ww == nw2)
                                            dup2 = 1'b1;
                                    end
                                    if (!dup2) begin
                                        nxt_set[nxt_size].valid <= 1'b1;
                                        nxt_set[nxt_size].hh    <= nh2;
                                        nxt_set[nxt_size].ww    <= nw2;
                                        nxt_size                <= nxt_size + 1'b1;
                                    end
                                end
                            end
                        end
                    end

                    // After building nxt_set, bump count and move it into cur_set in CHECK state
                    cur_count <= cur_count + 1'b1;
                end

                CHECK: begin
                    // Move nxt_set into cur_set
                    integer j;
                    for (j = 0; j < 16; j = j + 1) begin
                        cur_set[j].valid <= nxt_set[j].valid;
                        cur_set[j].hh    <= nxt_set[j].hh;
                        cur_set[j].ww    <= nxt_set[j].ww;
                    end
                    cur_size <= nxt_size;

                    // Check success condition on updated cur_set
                    success <= 1'b0;
                    if (nxt_size != 0) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (nxt_set[j].valid) begin
                                if ((nxt_set[j].hh >= a && nxt_set[j].ww >= b) ||
                                    (nxt_set[j].hh >= b && nxt_set[j].ww >= a)) begin
                                    success <= 1'b1;
                                end
                            end
                        end
                    end

                    // Latch min_count if success in this step
                    if (!success && (cur_count >= num_factors || nxt_size == 0)) begin
                        // no solution
                        min_count <= 5'd31;
                    end else if (success && min_count == 5'd31) begin
                        // record first success as minimal count
                        min_count <= cur_count;
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                end

                default: begin
                    // do nothing
                end
            endcase
        end
    end

    //------------------------------------------------------------------------------
    // Next state logic
    //------------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_pulse)
                    next_state = SORT;
            end

            SORT: begin
                if (sort_done)
                    next_state = PROCESS;
            end

            PROCESS: begin
                // After generating next set for current factor, go to CHECK
                next_state = CHECK;
            end

            CHECK: begin
                if (success || (cur_count >= num_factors) || (nxt_size == 0)) begin
                    next_state = DONE_ST;
                end else begin
                    next_state = PROCESS;
                end
            end

            DONE_ST: begin
                // Wait for start to be deasserted then asserted again
                if (!start)
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule