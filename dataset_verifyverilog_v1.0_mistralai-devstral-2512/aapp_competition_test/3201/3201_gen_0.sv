module SubsequenceHashGenerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] B,
    input wire [15:0] M,
    input wire [9:0] K,
    input wire [7:0] arr [0:9],
    output reg [31:0] hash_out,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE = 3'd1;
    localparam [2:0] COMPUTE_HASH = 3'd2;
    localparam [2:0] INSERT_BUFFER = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Control signals
    reg [9:0] mask_counter;
    reg [9:0] current_mask;
    reg [9:0] buffer_index;
    reg [9:0] output_index;
    reg [9:0] compare_index;
    reg [9:0] hash_index;

    // Buffer for storing top K subsequences
    reg [31:0] hash_buffer [0:9];
    reg [9:0] mask_buffer [0:9];
    reg [9:0] buffer_size;

    // Hash computation registers
    reg [31:0] hash_accumulator;
    reg [31:0] power_accumulator;
    reg [15:0] current_power;

    // Comparison registers
    reg [7:0] seq_a [0:9];
    reg [7:0] seq_b [0:9];
    reg [9:0] seq_a_len;
    reg [9:0] seq_b_len;
    reg comparison_result;

    // Cycle counter for timeout
    reg [19:0] cycle_count;
    localparam [19:0] MAX_CYCLES = 20'd100000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            mask_counter <= 10'd0;
            current_mask <= 10'd0;
            buffer_index <= 10'd0;
            output_index <= 10'd0;
            compare_index <= 10'd0;
            hash_index <= 10'd0;
            buffer_size <= 10'd0;
            hash_accumulator <= 32'd0;
            power_accumulator <= 32'd0;
            current_power <= 16'd0;
            seq_a_len <= 10'd0;
            seq_b_len <= 10'd0;
            comparison_result <= 1'b0;
            cycle_count <= 20'd0;
            valid <= 1'b0;
            done <= 1'b0;
            hash_out <= 32'd0;

            // Initialize buffer
            integer i;
            for (i = 0; i < 10; i = i + 1) begin
                hash_buffer[i] <= 32'd0;
                mask_buffer[i] <= 10'd0;
            end

            // Initialize sequence arrays
            for (i = 0; i < 10; i = i + 1) begin
                seq_a[i] <= 8'd0;
                seq_b[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 20'd0;
                    if (start) begin
                        next_state <= GENERATE;
                        mask_counter <= 10'd1;
                        current_mask <= 10'd1;
                        buffer_size <= 10'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                GENERATE: begin
                    cycle_count <= cycle_count + 20'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else if (mask_counter == 10'd1023) begin
                        next_state <= OUTPUT;
                        output_index <= 10'd0;
                    end else begin
                        next_state <= COMPUTE_HASH;
                        hash_accumulator <= 32'd0;
                        power_accumulator <= 32'd1;
                        current_power <= 16'd0;
                        hash_index <= 10'd0;
                    end
                end

                COMPUTE_HASH: begin
                    if (hash_index == 10'd10) begin
                        next_state <= INSERT_BUFFER;
                        buffer_index <= 10'd0;
                    end else begin
                        if (current_mask[hash_index]) begin
                            hash_accumulator <= (hash_accumulator + (arr[hash_index] * power_accumulator)) % M;
                            power_accumulator <= (power_accumulator * B) % M;
                        end
                        hash_index <= hash_index + 10'd1;
                    end
                end

                INSERT_BUFFER: begin
                    if (buffer_size < K) begin
                        hash_buffer[buffer_size] <= hash_accumulator;
                        mask_buffer[buffer_size] <= current_mask;
                        buffer_size <= buffer_size + 10'd1;
                        next_state <= GENERATE;
                        mask_counter <= mask_counter + 10'd1;
                        current_mask <= mask_counter;
                    end else begin
                        if (buffer_index == 10'd10) begin
                            next_state <= GENERATE;
                            mask_counter <= mask_counter + 10'd1;
                            current_mask <= mask_counter;
                        end else begin
                            next_state <= INSERT_BUFFER;
                            // Compare current_mask with buffer[buffer_index]
                            compare_index <= 10'd0;
                            seq_a_len <= 10'd0;
                            seq_b_len <= 10'd0;

                            // Extract sequences
                            integer i;
                            for (i = 0; i < 10; i = i + 1) begin
                                if (current_mask[i]) begin
                                    seq_a[seq_a_len] <= arr[i];
                                    seq_a_len <= seq_a_len + 10'd1;
                                end
                                if (mask_buffer[buffer_index][i]) begin
                                    seq_b[seq_b_len] <= arr[i];
                                    seq_b_len <= seq_b_len + 10'd1;
                                end
                            end

                            // Compare sequences
                            comparison_result <= 1'b0;
                            if (seq_a_len < seq_b_len) begin
                                comparison_result <= 1'b1;
                            end else if (seq_a_len > seq_b_len) begin
                                comparison_result <= 1'b0;
                            end else begin
                                for (i = 0; i < seq_a_len; i = i + 1) begin
                                    if (seq_a[i] < seq_b[i]) begin
                                        comparison_result <= 1'b1;
                                        break;
                                    end else if (seq_a[i] > seq_b[i]) begin
                                        comparison_result <= 1'b0;
                                        break;
                                    end
                                end
                            end

                            // Insert into buffer if smaller
                            if (comparison_result) begin
                                // Shift buffer elements
                                for (i = buffer_size - 1; i > buffer_index; i = i - 1) begin
                                    hash_buffer[i] <= hash_buffer[i - 1];
                                    mask_buffer[i] <= mask_buffer[i - 1];
                                end
                                hash_buffer[buffer_index] <= hash_accumulator;
                                mask_buffer[buffer_index] <= current_mask;
                                buffer_index <= 10'd10;
                            end else begin
                                buffer_index <= buffer_index + 10'd1;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    if (output_index == K) begin
                        next_state <= DONE_STATE;
                    end else begin
                        hash_out <= hash_buffer[output_index];
                        valid <= 1'b1;
                        output_index <= output_index + 10'd1;
                    end
                end

                DONE_STATE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule