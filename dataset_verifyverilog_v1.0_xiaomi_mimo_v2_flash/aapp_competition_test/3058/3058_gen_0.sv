module EvolutionaryPaths(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] current_species,
    input wire [7:0][15:0] fossils,
    input wire [7:0][2:0] fossil_lengths,
    input wire [2:0] current_length,
    output reg possible,
    output reg [7:0] assignment,
    output reg done
);

    // Parameters
    localparam [3:0] NUM_FOSSILS = 4'd8;
    localparam [3:0] MAX_STRING_LEN = 4'd8;
    localparam [1:0] CHAR_WIDTH = 2'd2;
    localparam [5:0] DATA_WIDTH = 6'd16;
    localparam [2:0] INDEX_WIDTH = 3'd3;
    localparam [5:0] NUM_CHECKS = 6'd72;
    localparam [7:0] NUM_ASSIGNMENTS = 8'd255;
    localparam [6:0] MAX_CYCLES = 7'd100;

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] PRECOMPUTE    = 4'd1;
    localparam [3:0] CHECK_ASSIGN  = 4'd2;
    localparam [3:0] VERIFY_CH1    = 4'd3;
    localparam [3:0] VERIFY_CH2    = 4'd4;
    localparam [3:0] VALID         = 4'd5;
    localparam [3:0] DONE          = 4'd6;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;

    // Current assignment counter
    reg [7:0] current_assign;

    // Precomputation results: 8 fossils * 8 current chars = 64 bits
    reg [63:0] subseq_result;
    reg [6:0] check_counter;  // 72 checks
    reg [2:0] fossil_idx;
    reg [2:0] current_idx;

    // Sorting and verification registers
    reg [2:0] chain1 [0:7];  // Indices for chain 1
    reg [2:0] chain2 [0:7];  // Indices for chain 2
    reg [2:0] len1 [0:7];    // Lengths for chain 1
    reg [2:0] len2 [0:7];    // Lengths for chain 2
    reg [3:0] size1;         // Number of elements in chain 1
    reg [3:0] size2;         // Number of elements in chain 2

    // Sorting temp variables
    reg [2:0] i_sort, j_sort;
    reg [2:0] temp_idx;
    reg [2:0] temp_len;
    reg swap_flag;

    // Subsequence check temp vars
    reg [15:0] seq_str;
    reg [15:0] sub_seq;
    reg [2:0] seq_len;
    reg [2:0] sub_len;
    reg [3:0] si, sj;
    reg match_flag;
    reg subseq_match;

    // Verification temp vars
    reg [3:0] v_i;
    reg verify_flag;
    reg ch1_valid;
    reg ch2_valid;

    integer i, j;  // General purpose integers for loops

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            possible <= 1'b0;
            assignment <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_assign <= 8'd0;
            subseq_result <= 64'd0;
            check_counter <= 7'd0;
            fossil_idx <= 3'd0;
            current_idx <= 3'd0;
            size1 <= 4'd0;
            size2 <= 4'd0;
            i_sort <= 3'd0;
            j_sort <= 3'd0;
            swap_flag <= 1'b0;
            si <= 4'd0;
            sj <= 4'd0;
            match_flag <= 1'b0;
            subseq_match <= 1'b0;
            verify_flag <= 1'b0;
            ch1_valid <= 1'b0;
            ch2_valid <= 1'b0;
            seq_str <= 16'd0;
            sub_seq <= 16'd0;
            seq_len <= 3'd0;
            sub_len <= 3'd0;
            temp_idx <= 3'd0;
            temp_len <= 3'd0;
            v_i <= 4'd0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                chain1[i] <= 3'd0;
                chain2[i] <= 3'd0;
                len1[i] <= 3'd0;
                len2[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    current_assign <= 8'd0;
                    check_counter <= 7'd0;
                    subseq_result <= 64'd0;
                    possible <= 1'b0;
                    assignment <= 8'd0;
                    size1 <= 4'd0;
                    size2 <= 4'd0;
                    verify_flag <= 1'b0;
                    ch1_valid <= 1'b0;
                    ch2_valid <= 1'b0;
                    if (start) begin
                        state <= PRECOMPUTE;
                    end
                end

                PRECOMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    check_counter <= check_counter + 7'd1;
                    
                    // Extract current character
                    sub_seq <= current_species;
                    sub_len <= current_length;
                    
                    // Extract fossil character
                    seq_str <= fossils[fossil_idx];
                    seq_len <= fossil_lengths[fossil_idx];
                    
                    // Perform subsequence check
                    match_flag <= 1'b0;
                    si <= 4'd0;  // sub index
                    sj <= 4'd0;  // seq index
                    
                    // Start matching
                    if (seq_len > 0 && sub_len > 0) begin
                        if (seq_str[1:0] == sub_seq[1:0] && si < sub_len) begin
                            si <= si + 4'd1;
                        end
                        sj <= 4'd1;
                    end
                    
                    // Move to next iteration
                    if (fossil_idx < NUM_FOSSILS - 1) begin
                        fossil_idx <= fossil_idx + 3'd1;
                    end else begin
                        fossil_idx <= 3'd0;
                        current_idx <= current_idx + 3'd1;
                        if (current_idx >= current_length - 1) begin
                            current_idx <= 3'd0;
                        end
                    end
                    
                    // Check if done with all precomputations
                    if (check_counter >= NUM_CHECKS) begin
                        state <= CHECK_ASSIGN;
                        check_counter <= 7'd0;
                        fossil_idx <= 3'd0;
                        current_idx <= 3'd0;
                    end
                end

                CHECK_ASSIGN: begin
                    cycle_count <= cycle_count + 8'd1;
                    current_assign <= current_assign + 8'd1;
                    
                    // Reset chains
                    size1 <= 4'd0;
                    size2 <= 4'd0;
                    
                    // Build chains from assignment
                    for (i = 0; i < 8; i = i + 1) begin
                        if (!current_assign[i]) begin
                            chain1[size1] <= i[2:0];
                            len1[size1] <= fossil_lengths[i];
                            size1 <= size1 + 4'd1;
                        end else begin
                            chain2[size2] <= i[2:0];
                            len2[size2] <= fossil_lengths[i];
                            size2 <= size2 + 4'd1;
                        end
                    end
                    
                    // If both chains empty, skip (invalid)
                    if (size1 == 4'd0 && size2 == 4'd0) begin
                        if (current_assign > NUM_ASSIGNMENTS) begin
                            state <= DONE;
                        end else begin
                            state <= CHECK_ASSIGN;
                        end
                    end else begin
                        i_sort <= 3'd0;
                        j_sort <= 3'd0;
                        swap_flag <= 1'b0;
                        state <= VERIFY_CH1;
                    end
                end

                VERIFY_CH1: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort chain1 by length
                    if (size1 > 1) begin
                        if (i_sort < size1 - 1) begin
                            if (j_sort < size1 - i_sort - 1) begin
                                if (len1[j_sort] > len1[j_sort + 1]) begin
                                    // Swap
                                    temp_idx <= chain1[j_sort];
                                    temp_len <= len1[j_sort];
                                    chain1[j_sort] <= chain1[j_sort + 1];
                                    len1[j_sort] <= len1[j_sort + 1];
                                    chain1[j_sort + 1] <= temp_idx;
                                    len1[j_sort + 1] <= temp_len;
                                    swap_flag <= 1'b1;
                                end
                                j_sort <= j_sort + 3'd1;
                            end else begin
                                j_sort <= 3'd0;
                                i_sort <= i_sort + 3'd1;
                                if (swap_flag) begin
                                    swap_flag <= 1'b0;
                                end
                            end
                        end else begin
                            i_sort <= 3'd0;
                            j_sort <= 3'd0;
                            v_i <= 4'd0;
                            verify_flag <= 1'b1;
                        end
                    end else begin
                        v_i <= 4'd0;
                        verify_flag <= 1'b1;
                    end
                    
                    if (verify_flag) begin
                        // Verify chain1: each fossil subsequence of next
                        if (v_i < size1 - 1) begin
                            // Prepare for subsequence check
                            sub_seq <= fossils[chain1[v_i]];
                            sub_len <= fossil_lengths[chain1[v_i]];
                            seq_str <= fossils[chain1[v_i + 1]];
                            seq_len <= fossil_lengths[chain1[v_i + 1]];
                            si <= 4'd0;
                            sj <= 4'd0;
                            subseq_match <= 1'b0;
                            v_i <= v_i + 4'd1;
                            // Need cycle for checking
                            verify_flag <= 1'b0;
                        end else if (size1 > 0) begin
                            // Check last in chain against current species
                            sub_seq <= fossils[chain1[size1 - 1]];
                            sub_len <= fossil_lengths[chain1[size1 - 1]];
                            seq_str <= current_species;
                            seq_len <= current_length;
                            si <= 4'd0;
                            sj <= 4'd0;
                            subseq_match <= 1'b0;
                            ch1_valid <= 1'b0;
                            v_i <= v_i + 4'd1;
                            verify_flag <= 1'b0;
                        end else begin
                            // Empty chain is valid
                            ch1_valid <= 1'b1;
                            state <= VERIFY_CH2;
                            verify_flag <= 1'b0;
                        end
                    end else if (si < sub_len && sj < seq_len) begin
                        // Perform matching
                        if ((seq_str[15:14] >> (sj*2)) == (sub_seq[15:14] >> (si*2))) begin
                            si <= si + 3'd1;
                        end
                        sj <= sj + 3'd1;
                    end else begin
                        if (si == sub_len) begin
                            if (v_i <= 4'd8 && size1 > 0) begin
                                if (fossil_lengths[chain1[size1-1]] != 3'd0) begin
                                    ch1_valid <= 1'b1;
                                end else begin
                                    ch1_valid <= 1'b0;
                                end
                            end else begin
                                ch1_valid <= 1'b1;
                            end
                        end else begin
                            ch1_valid <= 1'b0;
                        end
                        state <= VERIFY_CH2;
                        verify_flag <= 1'b0;
                    end
                end

                VERIFY_CH2: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort chain2 by length
                    if (size2 > 1) begin
                        if (i_sort < size2 - 1) begin
                            if (j_sort < size2 - i_sort - 1) begin
                                if (len2[j_sort] > len2[j_sort + 1]) begin
                                    // Swap
                                    temp_idx <= chain2[j_sort];
                                    temp_len <= len2[j_sort];
                                    chain2[j_sort] <= chain2[j_sort + 1];
                                    len2[j_sort] <= len2[j_sort + 1];
                                    chain2[j_sort + 1] <= temp_idx;
                                    len2[j_sort + 1] <= temp_len;
                                    swap_flag <= 1'b1;
                                end
                                j_sort <= j_sort + 3'd1;
                            end else begin
                                j_sort <= 3'd0;
                                i_sort <= i_sort + 3'd1;
                                if (swap_flag) begin
                                    swap_flag <= 1'b0;
                                end
                            end
                        end else begin
                            i_sort <= 3'd0;
                            j_sort <= 3'd0;
                            v_i <= 4'd0;
                            verify_flag <= 1'b1;
                        end
                    end else begin
                        v_i <= 4'd0;
                        verify_flag <= 1'b1;
                    end
                    
                    if (verify_flag) begin
                        // Verify chain2: each fossil subsequence of next
                        if (v_i < size2 - 1) begin
                            sub_seq <= fossils[chain2[v_i]];
                            sub_len <= fossil_lengths[chain2[v_i]];
                            seq_str <= fossils[chain2[v_i + 1]];
                            seq_len <= fossil_lengths[chain2[v_i + 1]];
                            si <= 4'd0;
                            sj <= 4'd0;
                            subseq_match <= 1'b0;
                            v_i <= v_i + 4'd1;
                            verify_flag <= 1'b0;
                        end else if (size2 > 0) begin
                            sub_seq <= fossils[chain2[size2 - 1]];
                            sub_len <= fossil_lengths[chain2[size2 - 1]];
                            seq_str <= current_species;
                            seq_len <= current_length;
                            si <= 4'd0;
                            sj <= 4'd0;
                            subseq_match <= 1'b0;
                            ch2_valid <= 1'b0;
                            v_i <= v_i + 4'd1;
                            verify_flag <= 1'b0;
                        end else begin
                            ch2_valid <= 1'b1;
                            state <= VALID;
                            verify_flag <= 1'b0;
                        end
                    end else if (si < sub_len && sj < seq_len) begin
                        if ((seq_str[15:14] >> (sj*2)) == (sub_seq[15:14] >> (si*2))) begin
                            si <= si + 3'd1;
                        end
                        sj <= sj + 3'd1;
                    end else begin
                        if (si == sub_len) begin
                            if (v_i <= 4'd8 && size2 > 0) begin
                                if (fossil_lengths[chain2[size2-1]] != 3'd0) begin
                                    ch2_valid <= 1'b1;
                                end else begin
                                    ch2_valid <= 1'b0;
                                end
                            end else begin
                                ch2_valid <= 1'b1;
                            end
                        end else begin
                            ch2_valid <= 1'b0;
                        end
                        state <= VALID;
                        verify_flag <= 1'b0;
                    end
                end

                VALID: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (ch1_valid && ch2_valid) begin
                        possible <= 1'b1;
                        assignment <= current_assign;
                        state <= DONE;
                    end else begin
                        possible <= 1'b0;
                        if (current_assign > NUM_ASSIGNMENTS || cycle_count >= MAX_CYCLES) begin
                            state <= DONE;
                        end else begin
                            state <= CHECK_ASSIGN;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule