module SubsequenceHash (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,        // Number of valid elements (1-8)
    input wire [7:0] K,        // Number of hashes to output (1-255)
    input wire [15:0] B,       // Base for hash
    input wire [15:0] M,       // Modulus for hash
    input wire [7:0] a0, a1, a2, a3, a4, a5, a6, a7, // Array elements
    output reg [15:0] hash,    // Output hash value
    output reg valid,          // Valid output (high for 1 cycle per hash)
    output reg done            // Done signal (high for 1 cycle after all outputs)
);

// State declarations
localparam [3:0] IDLE       = 4'd0;
localparam [3:0] GEN_SEQ    = 4'd1;
localparam [3:0] GEN_HASH   = 4'd2;
localparam [3:0] STORE      = 4'd3;
localparam [3:0] SORT_COMP  = 4'd4;
localparam [3:0] SORT_SWAP  = 4'd5;
localparam [3:0] OUTPUT     = 4'd6;
localparam [3:0] FINISH     = 4'd7;

reg [3:0] state, next_state;

// Internal registers and wires
reg [7:0] subseq_idx;        // Index for generating subsequences
reg [7:0] seq_count;         // Number of subsequences generated
reg [7:0] subseq[0:254];     // Subsequence data
reg [15:0] subseq_hash[0:254]; // Hash for each subsequence
reg [7:0] output_count;      // Number of hashes outputted
reg [7:0] i_index;           // Index for bubble sort outer loop
reg [7:0] j_index;           // Index for bubble sort inner loop
reg [15:0] hash_temp;        // Temporary hash calculation
reg [7:0] elem_count;        // Counter for hash calculation loop
reg [15:0] temp_hash;        // Hash computation accumulator
reg swap_flag;               // Flag to indicate swap needed
reg [7:0] cycle_count;       // Cycle counter to prevent infinite loops
localparam [7:0] MAX_CYCLES = 8'd200;

// For subsequence generation
reg [2:0] seq_elem_idx;      // Element index within current sequence
integer i; // General purpose loop index

// Instantiate arrays to store sequence bits
reg seq_bits[0:7]; // Indicates if element i is in current subsequence

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        hash <= 16'd0;
        valid <= 1'b0;
        done <= 1'b0;
        subseq_idx <= 8'd0;
        seq_count <= 8'd0;
        output_count <= 8'd0;
        i_index <= 8'd0;
        j_index <= 8'd0;
        hash_temp <= 16'd0;
        elem_count <= 8'd0;
        temp_hash <= 16'd0;
        swap_flag <= 1'b0;
        cycle_count <= 8'd0;
        seq_elem_idx <= 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            seq_bits[i] <= 1'b0;
            subseq[i] <= 8'd0;
            subseq_hash[i] <= 16'd0;
        end
        for (i = 8; i < 255; i = i + 1) begin
            subseq[i] <= 8'd0;
            subseq_hash[i] <= 16'd0;
        end
    end else begin
        valid <= 1'b0;
        done <= 1'b0;
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            IDLE: begin
                cycle_count <= 8'd0;
                done <= 1'b0;
                if (start) begin
                    state <= GEN_SEQ;
                    subseq_idx <= 8'd1; // Start from 1 (skip 0)
                    seq_count <= 8'd0;
                    // Initialize seq_bits to all 0
                    for (i = 0; i < 8; i = i + 1) begin
                        seq_bits[i] <= 1'b0;
                    end
                    seq_elem_idx <= 3'd0;
                end
            end
            
            GEN_SEQ: begin
                // Generate next subsequence mask
                // Stop if subseq_idx reaches 2^N (256 is out of bounds, stop at 255)
                // Or if generated enough (K * 2? No, just generate all up to 255)
                if (subseq_idx >= 8'd255 || (N > 0 && subseq_idx >= (8'd1 << N))) begin
                    state <= SORT_COMP;
                    i_index <= 8'd0;
                    j_index <= 8'd0;
                end else begin
                    // Check if subseq_idx is a valid subsequence (bits set within N)
                    // Convert subseq_idx binary to bits in seq_bits
                    reg is_valid;
                    is_valid = 1'b1;
                    for (i = 0; i < 8; i = i + 1) begin
                        seq_bits[i] <= subseq_idx[i];
                        if (i >= N && subseq_idx[i]) is_valid = 1'b0;
                    end
                    
                    if (is_valid) begin
                        state <= GEN_HASH;
                        elem_count <= 8'd0;
                        temp_hash <= 16'd0;
                    end else begin
                        subseq_idx <= subseq_idx + 8'd1;
                    end
                end
            end
            
            GEN_HASH: begin
                // Calculate hash for current subsequence
                if (elem_count >= N) begin
                    subseq_hash[seq_count] <= temp_hash;
                    // Store subsequence mask for reference (though not strictly needed for output)
                    subseq[seq_count] <= subseq_idx;
                    seq_count <= seq_count + 8'd1;
                    subseq_idx <= subseq_idx + 8'd1;
                    state <= GEN_SEQ;
                end else begin
                    if (seq_bits[elem_count]) begin
                        reg [15:0] elem_val;
                        // Select element based on index
                        case (elem_count)
                            3'd0: elem_val = {8'd0, a0};
                            3'd1: elem_val = {8'd0, a1};
                            3'd2: elem_val = {8'd0, a2};
                            3'd3: elem_val = {8'd0, a3};
                            3'd4: elem_val = {8'd0, a4};
                            3'd5: elem_val = {8'd0, a5};
                            3'd6: elem_val = {8'd0, a6};
                            3'd7: elem_val = {8'd0, a7};
                            default: elem_val = 16'd0;
                        endcase
                        temp_hash <= (temp_hash * B + elem_val) % M;
                    end
                    elem_count <= elem_count + 8'd1;
                end
            end
            
            SORT_COMP: begin
                // Bubble sort
                if (i_index >= seq_count - 8'd1) begin
                    // Sorting done, prepare to output
                    output_count <= 8'd0;
                    state <= OUTPUT;
                    j_index <= 8'd0;
                end else if (j_index >= seq_count - i_index - 8'd1) begin
                    j_index <= 8'd0;
                    i_index <= i_index + 8'd1;
                end else begin
                    // Compare subseq_hash[j] and subseq_hash[j+1]
                    if (subseq_hash[j_index] > subseq_hash[j_index + 8'd1]) begin
                        swap_flag <= 1'b1;
                        state <= SORT_SWAP;
                    end else begin
                        j_index <= j_index + 8'd1;
                    end
                end
            end
            
            SORT_SWAP: begin
                // Perform swap
                swap_flag <= 1'b0;
                // Swap hashes
                subseq_hash[j_index] <= subseq_hash[j_index + 8'd1];
                subseq_hash[j_index + 8'd1] <= subseq_hash[j_index];
                // Swap subsequence masks
                subseq[j_index] <= subseq[j_index + 8'd1];
                subseq[j_index + 8'd1] <= subseq[j_index];
                j_index <= j_index + 8'd1;
                state <= SORT_COMP;
            end
            
            OUTPUT: begin
                // Output K hashes
                if (output_count >= K) begin
                    state <= FINISH;
                end else if (output_count < seq_count) begin
                    hash <= subseq_hash[output_count];
                    valid <= 1'b1;
                    output_count <= output_count + 8'd1;
                end else begin
                    // Fewer subsequences than K requested, just finish
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
        
        // Timeout safety
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            state <= FINISH;
        end
    end
end

endmodule