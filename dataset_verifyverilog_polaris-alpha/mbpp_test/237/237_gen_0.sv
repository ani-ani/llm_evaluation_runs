module tuple_counter(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,
    input  logic [7:0]           tuples [0:7][1:0],
    input  logic [3:0]           tuple_count,
    output logic [7:0]           unique_tuples [0:7][1:0],
    output logic [3:0]           counts [0:7],
    output logic [3:0]           unique_count,
    output logic                 done
);

    // Internal state
    typedef enum logic [1:0] {
        S_IDLE  = 2'd0,
        S_INIT  = 2'd1,
        S_PROC  = 2'd2,
        S_DONE  = 2'd3
    } state_t;

    state_t          state, next_state;

    logic [3:0]      cur_idx;       // index of tuple being processed (0-8)
    logic [3:0]      u_count;       // internal unique count

    // Local storage for unique tuples and counts
    logic [7:0]      uniq_tuples_r [0:7][1:0];
    logic [3:0]      counts_r      [0:7];

    // For search through unique list
    logic [2:0]      search_idx;    // 0-7
    logic            search_match;
    logic [2:0]      match_idx;
    logic            search_done;

    // Current sorted tuple from input being processed
    logic [7:0]      cur_a, cur_b;
    logic [7:0]      sorted0, sorted1;

    // Latch of start to detect pulse
    logic            start_d;

    // Combinational: sort current tuple
    always_comb begin
        if (cur_a <= cur_b) begin
            sorted0 = cur_a;
            sorted1 = cur_b;
        end else begin
            sorted0 = cur_b;
            sorted1 = cur_a;
        end
    end

    // Search control: one comparison per cycle
    always_comb begin
        search_match = 1'b0;
        search_done  = 1'b0;
        match_idx    = 3'd0;

        if (state == S_PROC && cur_idx < tuple_count && u_count != 4'd0) begin
            if (search_idx < u_count[2:0]) begin
                if (uniq_tuples_r[search_idx][0] == sorted0 &&
                    uniq_tuples_r[search_idx][1] == sorted1) begin
                    search_match = 1'b1;
                    match_idx    = search_idx;
                    search_done  = 1'b1;
                end else if (search_idx == (u_count[2:0] - 3'd1)) begin
                    // Last valid entry checked, no match
                    search_done = 1'b1;
                end
            end else begin
                // No valid unique entries to check
                search_done = 1'b1;
            end
        end
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            start_d     <= 1'b0;
        end else begin
            state       <= next_state;
            start_d     <= start;
        end
    end

    // Sequential main logic
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_idx      <= 4'd0;
            u_count      <= 4'd0;
            unique_count <= 4'd0;
            done         <= 1'b0;

            for (i = 0; i < 8; i = i + 1) begin
                uniq_tuples_r[i][0] <= 8'd0;
                uniq_tuples_r[i][1] <= 8'd0;
                counts_r[i]         <= 4'd0;
                unique_tuples[i][0] <= 8'd0;
                unique_tuples[i][1] <= 8'd0;
                counts[i]           <= 4'd0;
            end

            search_idx <= 3'd0;
            cur_a      <= 8'd0;
            cur_b      <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done         <= 1'b0;
                    cur_idx      <= 4'd0;
                    u_count      <= 4'd0;
                    unique_count <= 4'd0;
                    search_idx   <= 3'd0;

                    if (start && !start_d) begin
                        // Prepare for new run: clear local unique storage
                        for (i = 0; i < 8; i = i + 1) begin
                            uniq_tuples_r[i][0] <= 8'd0;
                            uniq_tuples_r[i][1] <= 8'd0;
                            counts_r[i]         <= 4'd0;
                        end
                    end
                end

                S_INIT: begin
                    // Already cleared in IDLE; just setup first tuple index
                    cur_idx    <= 4'd0;
                    search_idx <= 3'd0;
                end

                S_PROC: begin
                    done <= 1'b0;

                    if (cur_idx < tuple_count) begin
                        // Load current tuple only when starting processing of this index
                        if (search_idx == 3'd0 && (u_count == 4'd0 || (cur_a != tuples[cur_idx][0]) || (cur_b != tuples[cur_idx][1]))) begin
                            cur_a <= tuples[cur_idx][0];
                            cur_b <= tuples[cur_idx][1];
                        end

                        // After sorting (combinational) we search / update
                        if (u_count == 4'd0) begin
                            // First unique tuple
                            uniq_tuples_r[0][0] <= sorted0;
                            uniq_tuples_r[0][1] <= sorted1;
                            counts_r[0]         <= 4'd1;
                            u_count             <= 4'd1;
                            cur_idx             <= cur_idx + 4'd1;
                            search_idx          <= 3'd0;
                        end else begin
                            if (search_done) begin
                                if (search_match) begin
                                    // Increment count for existing tuple
                                    counts_r[match_idx] <= counts_r[match_idx] + 4'd1;
                                end else if (u_count < 4'd8) begin
                                    // Add new unique tuple
                                    uniq_tuples_r[u_count][0] <= sorted0;
                                    uniq_tuples_r[u_count][1] <= sorted1;
                                    counts_r[u_count]         <= 4'd1;
                                    u_count                   <= u_count + 4'd1;
                                end
                                // Move to next tuple
                                cur_idx    <= cur_idx + 4'd1;
                                search_idx <= 3'd0;
                            end else begin
                                // Continue searching next unique entry
                                if (search_idx < 3'd7)
                                    search_idx <= search_idx + 3'd1;
                            end
                        end
                    end
                end

                S_DONE: begin
                    done         <= 1'b1;
                    unique_count <= u_count;

                    // Drive outputs from internal storage
                    for (i = 0; i < 8; i = i + 1) begin
                        unique_tuples[i][0] <= uniq_tuples_r[i][0];
                        unique_tuples[i][1] <= uniq_tuples_r[i][1];
                        counts[i]           <= counts_r[i];
                    end
                end

                default: begin
                    // Should not occur
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start && !start_d)
                    next_state = S_INIT;
            end

            S_INIT: begin
                next_state = S_PROC;
            end

            S_PROC: begin
                if (cur_idx >= tuple_count)
                    next_state = S_DONE;
            end

            S_DONE: begin
                if (!start)
                    next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule