module StringRearranger(
    input clk,
    input rst_n,
    input start,
    input [127:0] str_in,
    input [3:0] N,
    output reg [127:0] str_out,
    output reg result_valid,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CHECK_IMPOSSIBLE = 3'd2;
    localparam [2:0] TRY_ORIGINAL = 3'd3;
    localparam [2:0] TRY_REVERSED = 3'd4;
    localparam [2:0] TRY_SORTED = 3'd5;
    localparam [2:0] OUTPUT = 3'd6;
    localparam [2:0] DONE = 3'd7;

    reg [2:0] state, next_state;
    reg [7:0] char_buffer [0:15];
    reg [7:0] candidate [0:15];
    reg [7:0] sorted_buffer [0:15];
    reg [7:0] reversed_buffer [0:15];
    reg [15:0] substring_hashes [0:15];
    reg [7:0] freq [0:255];
    reg [7:0] max_freq;
    reg impossible_flag;
    reg found_solution;
    reg [9:0] cycle_count;
    reg [3:0] attempt;
    reg [3:0] i, j, k;
    reg [3:0] substring_start;
    reg [15:0] current_hash;
    reg [15:0] temp_hash;
    reg hash_collision;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 10'd0;
            attempt <= 4'd0;
            found_solution <= 1'b0;
            impossible_flag <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 8'd0;
                candidate[i] <= 8'd0;
                sorted_buffer[i] <= 8'd0;
                reversed_buffer[i] <= 8'd0;
                substring_hashes[i] <= 16'd0;
            end
            for (i = 0; i < 256; i = i + 1) begin
                freq[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                next_state = CHECK_IMPOSSIBLE;
            end

            CHECK_IMPOSSIBLE: begin
                next_state = TRY_ORIGINAL;
            end

            TRY_ORIGINAL: begin
                if (found_solution || impossible_flag) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = TRY_REVERSED;
                end
            end

            TRY_REVERSED: begin
                if (found_solution || impossible_flag) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = TRY_SORTED;
                end
            end

            TRY_SORTED: begin
                if (found_solution || impossible_flag) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 10'd0;
        end else if (state == LOAD) begin
            // Load input string into buffer
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= str_in[i*8 +: 8];
            end
            cycle_count <= 10'd0;
        end else if (state == CHECK_IMPOSSIBLE) begin
            // Calculate frequency of each character
            for (i = 0; i < 256; i = i + 1) begin
                freq[i] <= 8'd0;
            end
            for (i = 0; i < N; i = i + 1) begin
                freq[char_buffer[i]] <= freq[char_buffer[i]] + 8'd1;
            end
            max_freq <= 8'd0;
            for (i = 0; i < 256; i = i + 1) begin
                if (freq[i] > max_freq) begin
                    max_freq <= freq[i];
                end
            end
            if (max_freq > (N/2) + 1) begin
                impossible_flag <= 1'b1;
            end else begin
                impossible_flag <= 1'b0;
            end
            cycle_count <= 10'd0;
        end else if (state == TRY_ORIGINAL) begin
            // Try original string
            for (i = 0; i < N; i = i + 1) begin
                candidate[i] <= char_buffer[i];
            end
            attempt <= 4'd0;
            cycle_count <= 10'd0;
        end else if (state == TRY_REVERSED) begin
            // Try reversed string
            for (i = 0; i < N; i = i + 1) begin
                reversed_buffer[i] <= char_buffer[N - 1 - i];
            end
            for (i = 0; i < N; i = i + 1) begin
                candidate[i] <= reversed_buffer[i];
            end
            attempt <= 4'd1;
            cycle_count <= 10'd0;
        end else if (state == TRY_SORTED) begin
            // Try sorted string (simple bubble sort)
            for (i = 0; i < N; i = i + 1) begin
                sorted_buffer[i] <= char_buffer[i];
            end
            for (i = 0; i < N - 1; i = i + 1) begin
                for (j = 0; j < N - i - 1; j = j + 1) begin
                    if (sorted_buffer[j] > sorted_buffer[j + 1]) begin
                        temp_hash <= sorted_buffer[j];
                        sorted_buffer[j] <= sorted_buffer[j + 1];
                        sorted_buffer[j + 1] <= temp_hash;
                    end
                end
            end
            for (i = 0; i < N; i = i + 1) begin
                candidate[i] <= sorted_buffer[i];
            end
            attempt <= 4'd2;
            cycle_count <= 10'd0;
        end else if (state == OUTPUT) begin
            if (found_solution) begin
                // Pack candidate into str_out
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < N) begin
                        str_out[i*8 +: 8] <= candidate[i];
                    end else begin
                        str_out[i*8 +: 8] <= 8'd0;
                    end
                end
                impossible <= 1'b0;
            end else begin
                // Output -1 for all characters
                for (i = 0; i < 16; i = i + 1) begin
                    str_out[i*8 +: 8] <= 8'hFF;
                end
                impossible <= 1'b1;
            end
            result_valid <= 1'b1;
            cycle_count <= 10'd0;
        end else if (state == DONE) begin
            result_valid <= 1'b0;
            cycle_count <= 10'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            found_solution <= 1'b0;
        end else if (state == TRY_ORIGINAL || state == TRY_REVERSED || state == TRY_SORTED) begin
            // Check all substrings of length N/2
            hash_collision <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                substring_hashes[i] <= 16'd0;
            end
            for (substring_start = 0; substring_start <= N - N/2; substring_start = substring_start + 1) begin
                current_hash <= 16'd0;
                for (j = 0; j < N/2; j = j + 1) begin
                    current_hash <= current_hash + candidate[substring_start + j];
                end
                // Check for collision
                for (k = 0; k < substring_start; k = k + 1) begin
                    if (substring_hashes[k] == current_hash) begin
                        hash_collision <= 1'b1;
                    end
                end
                substring_hashes[substring_start] <= current_hash;
            end
            if (!hash_collision) begin
                found_solution <= 1'b1;
            end else if (attempt == 4'd2) begin
                found_solution <= 1'b0;
            end
            cycle_count <= cycle_count + 10'd1;
        end
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 10'd0;
        end else if (state != IDLE && state != DONE) begin
            cycle_count <= cycle_count + 10'd1;
            if (cycle_count >= 10'd1000) begin
                state <= OUTPUT;
                impossible_flag <= 1'b1;
                found_solution <= 1'b0;
            end
        end
    end

endmodule