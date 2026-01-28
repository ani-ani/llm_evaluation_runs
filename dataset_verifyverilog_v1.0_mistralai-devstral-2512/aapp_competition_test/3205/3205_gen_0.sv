module DebtSettler(
    input clk,
    input rst_n,
    input start,
    input receipts_valid,
    input [2:0] receipts_a,
    input [2:0] receipts_b,
    input [15:0] receipts_p,
    input [3:0] m,
    input [7:0] n,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [7:0] receipt_count;
    reg [7:0] subset_count;
    reg [7:0] min_transactions;
    reg [7:0] current_transactions;
    reg [7:0] subset_mask;
    reg [15:0] balances [0:7];
    reg [7:0] zero_indices [0:7];
    reg [3:0] zero_count;
    reg [7:0] i, j, k;

    // Initialize all registers in reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            receipt_count <= 8'd0;
            subset_count <= 8'd0;
            min_transactions <= 8'd255;
            current_transactions <= 8'd0;
            subset_mask <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                balances[i] <= 16'd0;
                zero_indices[i] <= 8'd0;
            end
            zero_count <= 4'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        receipt_count <= 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            balances[i] <= 16'd0;
                        end
                    end
                end

                PARSE: begin
                    if (receipts_valid && receipt_count < n) begin
                        // Update balances: payer decreases, receiver increases
                        balances[receipts_a] <= balances[receipts_a] - receipts_p;
                        balances[receipts_b] <= balances[receipts_b] + receipts_p;
                        receipt_count <= receipt_count + 8'd1;
                    end
                    if (receipt_count == n) begin
                        state <= SEARCH;
                        subset_count <= 8'd0;
                        min_transactions <= 8'd255;
                        current_transactions <= 8'd0;
                        subset_mask <= 8'd0;
                        // Precompute zero indices
                        zero_count <= 4'd0;
                        for (i = 0; i < m; i = i + 1) begin
                            if (balances[i] == 16'd0) begin
                                zero_indices[zero_count] <= i;
                                zero_count <= zero_count + 4'd1;
                            end
                        end
                    end
                end

                SEARCH: begin
                    // Iterate through all possible subsets
                    if (subset_count < 256) begin
                        subset_mask <= subset_count;
                        // Check if this subset is a valid transaction group
                        reg [15:0] subset_sum;
                        reg [7:0] subset_size;
                        subset_sum <= 16'd0;
                        subset_size <= 8'd0;
                        for (i = 0; i < m; i = i + 1) begin
                            if (subset_mask[i]) begin
                                subset_sum <= subset_sum + balances[i];
                                subset_size <= subset_size + 8'd1;
                            end
                        end
                        // If sum is zero and subset is non-empty, it's a valid transaction
                        if (subset_sum == 16'd0 && subset_size > 8'd0) begin
                            // Check if this subset covers any non-zero balances
                            reg valid_subset;
                            valid_subset <= 1'b0;
                            for (i = 0; i < m; i = i + 1) begin
                                if (subset_mask[i] && balances[i] != 16'd0) begin
                                    valid_subset <= 1'b1;
                                end
                            end
                            if (valid_subset) begin
                                // Count how many non-zero balances this subset covers
                                reg [7:0] covered_count;
                                covered_count <= 8'd0;
                                for (i = 0; i < m; i = i + 1) begin
                                    if (subset_mask[i] && balances[i] != 16'd0) begin
                                        covered_count <= covered_count + 8'd1;
                                    end
                                end
                                // Update minimum transactions
                                if (covered_count > 8'd0) begin
                                    current_transactions <= current_transactions + 8'd1;
                                    if (current_transactions < min_transactions) begin
                                        min_transactions <= current_transactions;
                                    end
                                end
                            end
                        end
                        subset_count <= subset_count + 8'd1;
                    end else begin
                        state <= OUTPUT;
                        result <= min_transactions;
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule