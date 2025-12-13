module weight_identifier(
    input  clk,
    input  rst_n,
    input  start,
    input  [3:0]  n,
    input  [31:0] weights, // [31:28]=a7 ... [3:0]=a0
    output reg [3:0] result,
    output reg       done
);

    // Internal storage for 8 weights (4-bit each)
    reg [3:0] w [0:7];

    // Binomial lookup: C(cnt,k) for cnt<=8,k<=8.
    // We'll implement a function that returns 0 when k>cnt or out of range.
    function [7:0] binom;
        input [3:0] cnt;
        input [3:0] k;
        begin
            case ({cnt,k})
                // cnt=0
                8'h00: binom = 1;   // C(0,0)
                // cnt=1
                8'h10: binom = 1;   // C(1,0)
                8'h11: binom = 1;   // C(1,1)
                // cnt=2
                8'h20: binom = 1;
                8'h21: binom = 2;
                8'h22: binom = 1;
                // cnt=3
                8'h30: binom = 1;
                8'h31: binom = 3;
                8'h32: binom = 3;
                8'h33: binom = 1;
                // cnt=4
                8'h40: binom = 1;
                8'h41: binom = 4;
                8'h42: binom = 6;
                8'h43: binom = 4;
                8'h44: binom = 1;
                // cnt=5
                8'h50: binom = 1;
                8'h51: binom = 5;
                8'h52: binom = 10;
                8'h53: binom = 10;
                8'h54: binom = 5;
                8'h55: binom = 1;
                // cnt=6
                8'h60: binom = 1;
                8'h61: binom = 6;
                8'h62: binom = 15;
                8'h63: binom = 20;
                8'h64: binom = 15;
                8'h65: binom = 6;
                8'h66: binom = 1;
                // cnt=7
                8'h70: binom = 1;
                8'h71: binom = 7;
                8'h72: binom = 21;
                8'h73: binom = 35;
                8'h74: binom = 35;
                8'h75: binom = 21;
                8'h76: binom = 7;
                8'h77: binom = 1;
                // cnt=8
                8'h80: binom = 1;
                8'h81: binom = 8;
                8'h82: binom = 28;
                8'h83: binom = 56;
                8'h84: binom = 70;
                8'h85: binom = 56;
                8'h86: binom = 28;
                8'h87: binom = 8;
                8'h88: binom = 1;
                default: binom = 0;
            endcase
        end
    endfunction

    // FSM states
    typedef enum logic [2:0] {
        IDLE        = 3'd0,
        LOAD        = 3'd1,
        SEARCH_K    = 3'd2,
        CHECK_COUNT = 3'd3,
        NEXT_MASK   = 3'd4,
        UPDATE_RES  = 3'd5,
        WAIT_DONE   = 3'd6
    } state_t;

    state_t state, next_state;

    // Cycle counter for fixed 100-cycle latency
    reg [6:0] cycle_cnt; // up to 100

    // Search variables
    reg [3:0] k_cur;             // current k (1..n)
    reg [3:0] cnt_cur;           // current count (#weights considered as candidate set size)
    reg [7:0] subset_mask;       // iterates over subsets of size k_cur
    reg       valid_k;           // flag that all k-subset sums are uniquely identifiable
    reg [7:0] target_count;      // expected number of subsets C(cnt_cur, k_cur)
    reg [7:0] found_count;       // number of distinct subset sums found
    reg       first_subset;      // indicator for first subset of given k

    // Storage for subset sums for uniqueness checking: max C(8,4)=70 <128
    reg [7:0] sum_list [0:127];
    reg [6:0] sum_list_size;

    // Helper: popcount of 8-bit mask
    function [3:0] popcount8;
        input [7:0] v;
        begin
            popcount8 = v[0] + v[1] + v[2] + v[3] + v[4] + v[5] + v[6] + v[7];
        end
    endfunction

    // Compute subset sum for current mask using stored weights
    function [7:0] subset_sum;
        input [7:0] mask;
        reg [7:0] s;
        begin
            s = 8'd0;
            if (mask[0]) s = s + w[0];
            if (mask[1]) s = s + w[1];
            if (mask[2]) s = s + w[2];
            if (mask[3]) s = s + w[3];
            if (mask[4]) s = s + w[4];
            if (mask[5]) s = s + w[5];
            if (mask[6]) s = s + w[6];
            if (mask[7]) s = s + w[7];
            subset_sum = s;
        end
    endfunction

    // Check if sum already exists in list; if not, append.
    function automatic bit add_unique_sum;
        input [7:0] s;
        integer i;
        begin
            add_unique_sum = 1'b1;
            for (i = 0; i < sum_list_size; i = i + 1) begin
                if (sum_list[i] == s) begin
                    add_unique_sum = 1'b0; // duplicate found
                end
            end
            if (add_unique_sum) begin
                sum_list[sum_list_size] = s;
            end
        end
    endfunction

    // Next subset mask with same popcount using lexicographic next-combination
    function [7:0] next_comb;
        input [7:0] m;
        reg [7:0] x;
        reg [7:0] u;
        reg [7:0] v;
        begin
            x = m & -m;         // lowest set bit
            u = m + x;
            v = ((m ^ u) >> 2) / x;
            next_comb = u | v;
        end
    endfunction

    // Synchronous FSM
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            result      <= 4'd0;
            done        <= 1'b0;
            cycle_cnt   <= 7'd0;
            k_cur       <= 4'd0;
            cnt_cur     <= 4'd0;
            subset_mask <= 8'd0;
            valid_k     <= 1'b0;
            target_count<= 8'd0;
            found_count <= 8'd0;
            first_subset<= 1'b0;
            sum_list_size <= 7'd0;
            for (j = 0; j < 8; j = j + 1) begin
                w[j] <= 4'd0;
            end
        end else begin
            // cycle counter for 100-cycle latency
            if (state == IDLE) begin
                cycle_cnt <= 7'd0;
                done      <= 1'b0;
            end else if (cycle_cnt < 7'd100) begin
                cycle_cnt <= cycle_cnt + 7'd1;
            end else begin
                done <= 1'b1;
            end

            case (state)
                IDLE: begin
                    if (start) begin
                        // load weights from flattened input
                        w[0] <= weights[3:0];
                        w[1] <= weights[7:4];
                        w[2] <= weights[11:8];
                        w[3] <= weights[15:12];
                        w[4] <= weights[19:16];
                        w[5] <= weights[23:20];
                        w[6] <= weights[27:24];
                        w[7] <= weights[31:28];
                        result <= 4'd0;
                        k_cur  <= 4'd1;
                        cnt_cur<= n; // use provided n directly as count of weights
                        state  <= LOAD;
                    end
                end

                LOAD: begin
                    // Initialize search for current k
                    if (k_cur > cnt_cur || k_cur == 4'd0) begin
                        // no valid k, move to WAIT_DONE
                        state <= WAIT_DONE;
                    end else begin
                        // initialize subset enumeration for this k
                        // first mask: lowest k bits set
                        subset_mask   <= (8'hFF >> (8 - k_cur));
                        target_count  <= binom(cnt_cur, k_cur);
                        sum_list_size <= 7'd0;
                        found_count   <= 8'd0;
                        valid_k       <= 1'b1; // assume valid until conflict
                        first_subset  <= 1'b1;
                        state         <= CHECK_COUNT;
                    end
                end

                CHECK_COUNT: begin
                    // Process current subset_mask if popcount matches k_cur
                    if (popcount8(subset_mask) == k_cur) begin
                        // compute sum and attempt to add uniquely
                        reg [7:0] s;
                        reg       uniq;
                        s = subset_sum(subset_mask);
                        uniq = add_unique_sum(s);
                        if (!uniq) begin
                            valid_k <= 1'b0; // duplicate sum -> not uniquely identifiable
                        end else begin
                            sum_list_size <= sum_list_size + 7'd1;
                        end
                        found_count <= found_count + 8'd1;
                    end
                    state <= NEXT_MASK;
                end

                NEXT_MASK: begin
                    // Advance to next subset with same k; stop when overflow or counts reached
                    if (found_count >= target_count || !valid_k) begin
                        // evaluation of this k finished
                        state <= UPDATE_RES;
                    end else begin
                        // compute next combination; if exceeds 8-bit range or invalid, end
                        reg [7:0] next_m;
                        next_m = next_comb(subset_mask);
                        if (next_m == subset_mask || next_m == 8'd0 || next_m >= (1<<cnt_cur)) begin
                            state <= UPDATE_RES;
                        end else begin
                            subset_mask <= next_m;
                            state       <= CHECK_COUNT;
                        end
                    end
                end

                UPDATE_RES: begin
                    // If valid_k and we saw exact target_count unique sums, update result
                    if (valid_k && (found_count == target_count) && (k_cur <= cnt_cur)) begin
                        if (cnt_cur > result)
                            result <= cnt_cur;
                    end
                    // Try next k
                    if (k_cur < cnt_cur) begin
                        k_cur  <= k_cur + 4'd1;
                        state  <= LOAD;
                    end else begin
                        state <= WAIT_DONE;
                    end
                end

                WAIT_DONE: begin
                    // Stay here until 100 cycles elapsed; done already handled by counter logic
                    // Optionally allow restart when start is asserted again
                    if (done && !start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule