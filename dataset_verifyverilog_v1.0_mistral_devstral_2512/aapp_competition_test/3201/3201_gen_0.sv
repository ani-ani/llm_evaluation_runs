module SubsequenceHash (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [7:0] K,
    input wire [15:0] B,
    input wire [15:0] M,
    input wire [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
    output reg [15:0] hash,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [7:0] hash_count;
    reg [7:0] output_count;
    reg [7:0] sort_i, sort_j;
    reg [7:0] compute_i, compute_j;
    reg [7:0] temp_hash;
    reg [7:0] temp_subseq;
    
    // Memory for storing hashes and subsequences
    reg [15:0] hash_mem [0:255];
    reg [7:0] subseq_mem [0:255];
    reg [7:0] num_hashes;
    
    // Array of input elements
    reg [7:0] arr [0:7];
    
    // Initialize arrays
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            hash_count <= 8'd0;
            output_count <= 8'd0;
            sort_i <= 8'd0;
            sort_j <= 8'd0;
            compute_i <= 8'd0;
            compute_j <= 8'd0;
            temp_hash <= 8'd0;
            temp_subseq <= 8'd0;
            num_hashes <= 8'd0;
            hash <= 16'd0;
            valid <= 1'b0;
            done <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                arr[i] <= 8'd0;
            end
            for (i = 0; i < 256; i = i + 1) begin
                hash_mem[i] <= 16'd0;
                subseq_mem[i] <= 8'd0;
            end
        end else begin
            // Update state
            state <= next_state;
            
            // Update arrays
            arr[0] <= a0;
            arr[1] <= a1;
            arr[2] <= a2;
            arr[3] <= a3;
            arr[4] <= a4;
            arr[5] <= a5;
            arr[6] <= a6;
            arr[7] <= a7;
            
            // State machine
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COMPUTE;
                        hash_count <= 8'd0;
                        compute_i <= 8'd0;
                        compute_j <= 8'd0;
                        num_hashes <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    // Compute all non-empty subsequences
                    if (compute_i < N) begin
                        if (compute_j < N) begin
                            // Compute hash for subsequence
                            temp_hash <= 8'd0;
                            temp_subseq <= 8'd0;
                            for (i = compute_i; i <= compute_j; i = i + 1) begin
                                temp_hash <= (temp_hash * B + arr[i]) % M;
                                temp_subseq <= temp_subseq | (1 << i);
                            end
                            
                            // Store hash and subsequence
                            hash_mem[hash_count] <= temp_hash;
                            subseq_mem[hash_count] <= temp_subseq;
                            hash_count <= hash_count + 8'd1;
                            
                            // Move to next subsequence
                            if (compute_j == N - 1) begin
                                compute_i <= compute_i + 8'd1;
                                compute_j <= compute_i;
                            end else begin
                                compute_j <= compute_j + 8'd1;
                            end
                        end else begin
                            compute_i <= compute_i + 8'd1;
                            compute_j <= compute_i;
                        end
                    end else begin
                        num_hashes <= hash_count;
                        next_state <= SORT;
                        sort_i <= 8'd0;
                        sort_j <= 8'd0;
                    end
                end
                
                SORT: begin
                    // Bubble sort
                    if (sort_i < num_hashes - 1) begin
                        if (sort_j < num_hashes - sort_i - 1) begin
                            if (subseq_mem[sort_j] > subseq_mem[sort_j + 1]) begin
                                // Swap
                                temp_hash <= hash_mem[sort_j];
                                temp_subseq <= subseq_mem[sort_j];
                                hash_mem[sort_j] <= hash_mem[sort_j + 1];
                                subseq_mem[sort_j] <= subseq_mem[sort_j + 1];
                                hash_mem[sort_j + 1] <= temp_hash;
                                subseq_mem[sort_j + 1] <= temp_subseq;
                            end
                            sort_j <= sort_j + 8'd1;
                        end else begin
                            sort_j <= 8'd0;
                            sort_i <= sort_i + 8'd1;
                        end
                    end else begin
                        next_state <= OUTPUT;
                        output_count <= 8'd0;
                    end
                end
                
                OUTPUT: begin
                    if (output_count < K && output_count < num_hashes) begin
                        hash <= hash_mem[output_count];
                        valid <= 1'b1;
                        output_count <= output_count + 8'd1;
                    end else begin
                        valid <= 1'b0;
                        next_state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule