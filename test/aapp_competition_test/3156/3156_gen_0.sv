module store_path_detector(
    input  clk,
    input  rst_n,
    input  start,
    input  [1:0] num_stores,
    input  [3:0][1:0] store_ids,
    input  [3:0][1:0] item_ids,
    input  [3:0][1:0] bought_list,
    input  [1:0] num_bought,
    output reg [1:0] result,
    output reg       done
);

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE    = 3'd0,
        S_LOAD    = 3'd1,
        S_INITDP  = 3'd2,
        S_PROC_DP = 3'd3,
        S_DONE    = 3'd4
    } state_t;

    state_t state, next_state;

    // Internal storage for inventory
    // For store index s (0..3), store_mask[s][i] = 1 if store s sells item i
    reg [3:0] store_mask [0:3];

    // Latched inputs
    reg [1:0] num_stores_q;
    reg [1:0] num_bought_q;
    reg [3:0][1:0] bought_list_q;

    // DP over stores: ways[s] = number of ways to be at store s after processing prefix
    // We only need two bits per store: 0,1,>=2 (clamped at 2)
    reg [1:0] ways [0:3];
    reg [1:0] new_ways [0:3];

    reg [1:0] item_idx;          // current bought item index

    integer i, j;

    // Clamp add: a,b in {0,1,2} => res in {0,1,2}, where 2 means >=2
    function automatic [1:0] add_clamp2(input [1:0] a, input [1:0] b);
        reg [2:0] sum;
        begin
            sum = a + b;
            if (sum >= 3'd2) add_clamp2 = 2'd2;
            else             add_clamp2 = sum[1:0];
        end
    endfunction

    // Next-state / control FSM
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start) next_state = S_LOAD;
            end
            S_LOAD: begin
                next_state = S_INITDP;
            end
            S_INITDP: begin
                next_state = S_PROC_DP;
            end
            S_PROC_DP: begin
                if (item_idx == num_bought_q) next_state = S_DONE;
                else                          next_state = S_PROC_DP;
            end
            S_DONE: begin
                // stay done until next start
                if (start) next_state = S_LOAD;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            num_stores_q  <= 2'd0;
            num_bought_q  <= 2'd0;
            bought_list_q <= '{default:'0};
            for (i = 0; i < 4; i = i + 1) begin
                store_mask[i] <= 4'b0000;
                ways[i]       <= 2'd0;
                new_ways[i]   <= 2'd0;
            end
            item_idx <= 2'd0;
            result   <= 2'b00;
            done     <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done   <= 1'b0;
                    result <= 2'b00;
                    if (start) begin
                        // Latch inputs
                        num_stores_q  <= num_stores;
                        num_bought_q  <= num_bought;
                        bought_list_q <= bought_list;

                        // Build store_mask from store_ids/item_ids
                        for (i = 0; i < 4; i = i + 1) begin
                            store_mask[i] <= 4'b0000;
                        end
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i < num_stores) begin
                                // valid inventory entry
                                store_mask[store_ids[i]][item_ids[i]] <= 1'b1;
                            end
                        end
                    end
                end

                S_LOAD: begin
                    // Ensure done low, prep for DP init
                    done <= 1'b0;
                end

                S_INITDP: begin
                    // Initialize DP for prefix length 0: ways[0]=1, others=0
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i == 0) ways[i] <= 2'd1;
                        else        ways[i] <= 2'd0;
                    end
                    item_idx <= 2'd0;
                end

                S_PROC_DP: begin
                    if (item_idx < num_bought_q) begin
                        // Compute next ways for current item
                        for (j = 0; j < 4; j = j + 1) begin
                            new_ways[j] <= 2'd0;
                        end

                        for (j = 0; j < 4; j = j + 1) begin
                            if (ways[j] != 2'd0) begin
                                // Can continue at store k >= j that sells item
                                integer k;
                                for (k = j; k < 4; k = k + 1) begin
                                    if (store_mask[k][bought_list_q[item_idx]]) begin
                                        new_ways[k] <= add_clamp2(new_ways[k], ways[j]);
                                    end
                                end
                            end
                        end

                        // Update ways and advance item index
                        for (j = 0; j < 4; j = j + 1) begin
                            ways[j] <= new_ways[j];
                        end

                        item_idx <= item_idx + 2'd1;
                    end
                end

                S_DONE: begin
                    // Summarize ways: total_paths in {0,1,>=2}
                    reg [1:0] total;
                    total = 2'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        total = add_clamp2(total, ways[i]);
                    end

                    if (total == 2'd0)      result <= 2'b00; // impossible
                    else if (total == 2'd1) result <= 2'b01; // unique
                    else                    result <= 2'b10; // ambiguous

                    done <= 1'b1;

                    // If a new start comes, re-latch in S_IDLE/S_LOAD path next cycle
                end

                default: begin
                    // Should not happen, reset-like behavior
                    done   <= 1'b0;
                    result <= 2'b00;
                end
            endcase
        end
    end

endmodule