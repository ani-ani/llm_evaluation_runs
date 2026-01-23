module occ_count #(parameter N=8, parameter WIDTH=8, parameter MAX_DISTINCT=8) (
    input clk,
    input rst_n,
    input start,
    input [N-1:0][WIDTH-1:0] data_in_0, // First element of each pair
    input [N-1:0][WIDTH-1:0] data_in_1, // Second element of each pair
    output reg [MAX_DISTINCT-1:0][WIDTH*2-1:0] out_keys, // Unique sorted pairs
    output reg [MAX_DISTINCT-1:0][3:0] out_counts, // Counts (max 15 for 4 bits)
    output reg done,
    output reg valid
);

    // State machine states
    localparam IDLE = 2'b00;
    localparam NORMALIZE = 2'b01;
    localparam COUNT = 2'b10;
    localparam FINISH = 2'b11;

    reg [1:0] state, next_state;
    reg [3:0] idx, next_idx; // Index for processing input array
    reg [3:0] k_idx, next_k_idx; // Index for distinct keys array
    reg [WIDTH*2-1:0] norm_pair [0:N-1]; // Normalized (sorted) pairs
    reg [WIDTH*2-1:0] temp_pair;
    reg [3:0] count_reg [0:MAX_DISTINCT-1]; // Count storage
    reg [WIDTH*2-1:0] key_reg [0:MAX_DISTINCT-1]; // Key storage
    reg found;
    reg [3:0] j;

    // Next state logic
    always @(*) begin
        next_state = state;
        next_idx = idx;
        next_k_idx = k_idx;
        case (state)
            IDLE: if (start) next_state = NORMALIZE;
            NORMALIZE: begin
                if (idx < N) next_state = NORMALIZE;
                else begin
                    next_idx = 0;
                    next_state = COUNT;
                end
            end
            COUNT: begin
                if (idx < N) next_state = COUNT;
                else next_state = FINISH;
            end
            FINISH: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 0;
            k_idx <= 0;
            done <= 0;
            valid <= 0;
            for (i = 0; i < MAX_DISTINCT; i = i + 1) begin
                count_reg[i] <= 0;
                key_reg[i] <= 0;
            end
            for (i = 0; i < N; i = i + 1) norm_pair[i] <= 0;
        end else begin
            state <= next_state;
            idx <= next_idx;
            k_idx <= next_k_idx;

            case (state)
                NORMALIZE: begin
                    if (idx < N) begin
                        // Sort the pair (min, max) to normalize
                        if (data_in_0[idx] < data_in_1[idx]) 
                            norm_pair[idx] <= {data_in_0[idx], data_in_1[idx]};
                        else 
                            norm_pair[idx] <= {data_in_1[idx], data_in_0[idx]};
                        next_idx <= idx + 1;
                    end
                end
                COUNT: begin
                    if (idx < N) begin
                        // Check if normalized pair exists in key_reg
                        found = 0;
                        for (j = 0; j < k_idx; j = j + 1) begin
                            if (key_reg[j] == norm_pair[idx]) begin
                                count_reg[j] <= count_reg[j] + 1;
                                found = 1;
                            end
                        end
                        // If not found and space available, add new key
                        if (!found && (k_idx < MAX_DISTINCT)) begin
                            key_reg[k_idx] <= norm_pair[idx];
                            count_reg[k_idx] <= 1;
                            next_k_idx <= k_idx + 1;
                        end
                        next_idx <= idx + 1;
                    end
                end
                FINISH: begin
                    done <= 1;
                    valid <= 1;
                    // Assign outputs
                    for (i = 0; i < MAX_DISTINCT; i = i + 1) begin
                        out_keys[i] <= key_reg[i];
                        out_counts[i] <= count_reg[i];
                    end
                end
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                end
            endcase
        end
    end

endmodule