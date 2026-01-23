module sheldon_counter(
    input clk,
    input rst_n,
    input start,
    input [63:0] range_start,
    input [63:0] range_end,
    output reg [31:0] count,
    output reg done
);

    // State machine states
    typedef enum logic [3:0] {
        IDLE,
        INIT,
        GEN_N,
        GEN_M,
        GEN_LEN,
        GEN_NUM,
        CHECK,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Counters and parameters
    reg [3:0] n_counter; // N from 1 to 16
    reg [3:0] m_counter; // M from 1 to 16
    reg [5:0] len_counter; // Total length from (N+M) to 64
    reg [63:0] candidate_num;
    reg [31:0] temp_count;

    // Helper function to generate Sheldon number
    function automatic [63:0] generate_sheldon_num;
        input [3:0] N;
        input [3:0] M;
        input [5:0] total_len;
        reg [63:0] num;
        integer i, j, k;
        integer ones_block, zeros_block;
        integer num_blocks;
        
        ones_block = N;
        zeros_block = M;
        num_blocks = total_len / (ones_block + zeros_block);
        
        num = 0;
        for (k = 0; k < num_blocks; k = k + 1) begin
            // Add ones
            for (i = 0; i < ones_block; i = i + 1) begin
                num = {num[62:0], 1'b1};
            end
            // Add zeros
            for (j = 0; j < zeros_block; j = j + 1) begin
                num = {num[62:0], 1'b0};
            end
        end
        
        // Add remaining ones if any
        if (total_len % (ones_block + zeros_block) != 0) begin
            for (i = 0; i < (total_len % (ones_block + zeros_block)); i = i + 1) begin
                num = {num[62:0], 1'b1};
            end
        end
        
        generate_sheldon_num = num;
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count <= 0;
            done <= 0;
            n_counter <= 0;
            m_counter <= 0;
            len_counter <= 0;
            temp_count <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                temp_count = 0;
                n_counter = 1;
                m_counter = 1;
                len_counter = n_counter + m_counter;
                next_state = GEN_NUM;
            end
            GEN_NUM: begin
                candidate_num = generate_sheldon_num(n_counter, m_counter, len_counter);
                next_state = CHECK;
            end
            CHECK: begin
                if (candidate_num >= range_start && candidate_num <= range_end) begin
                    temp_count = temp_count + 1;
                end
                // Move to next length
                if (len_counter < 64) begin
                    len_counter = len_counter + 1;
                    next_state = GEN_NUM;
                end else begin
                    // Move to next M
                    if (m_counter < 16) begin
                        m_counter = m_counter + 1;
                        len_counter = n_counter + m_counter;
                        next_state = GEN_NUM;
                    end else begin
                        // Move to next N
                        if (n_counter < 16) begin
                            n_counter = n_counter + 1;
                            m_counter = 1;
                            len_counter = n_counter + m_counter;
                            next_state = GEN_NUM;
                        end else begin
                            next_state = DONE;
                        end
                    end
                end
            end
            DONE: begin
                count = temp_count;
                done = 1;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule