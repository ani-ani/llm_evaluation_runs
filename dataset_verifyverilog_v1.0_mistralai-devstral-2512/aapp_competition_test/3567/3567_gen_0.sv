module OptimalVectorFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    input wire [4:0] k_in,
    input wire [31:0] data_in,
    input wire data_valid,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam [4:0] K_MAX = 5'd20;
    localparam [7:0] N_MAX = 8'd8;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_VECTORS = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // State register
    reg [2:0] state, next_state;

    // Control registers
    reg [7:0] n_reg;
    reg [4:0] k_reg;
    reg [7:0] vector_count;
    reg [19:0] candidate;
    reg [19:0] best_candidate;
    reg [4:0] min_max_similarity;
    reg [4:0] current_max_similarity;
    reg [4:0] current_similarity;

    // Vector storage (N_MAX vectors, each K_MAX bits)
    reg [19:0] stored_vectors [0:N_MAX-1];

    // Popcount LUT for 8-bit values
    reg [3:0] popcount_lut [0:255];

    // Popcount LUT initialization
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            popcount_lut[i] = 0;
            if (i[0]) popcount_lut[i] = popcount_lut[i] + 1;
            if (i[1]) popcount_lut[i] = popcount_lut[i] + 1;
            if (i[2]) popcount_lut[i] = popcount_lut[i] + 1;
            if (i[3]) popcount_lut[i] = popcount_lut[i] + 1;
            if (i[4]) popcount_lut[i] = popcount_lut[i] + 1;
            if (i[5]) popcount_lut[i] = popcount_lut[i] + 1;
            if (i[6]) popcount_lut[i] = popcount_lut[i] + 1;
            if (i[7]) popcount_lut[i] = popcount_lut[i] + 1;
        end
    end

    // Popcount function for up to 20 bits
    function [4:0] compute_popcount;
        input [19:0] value;
        reg [4:0] count;
        integer j;
        begin
            count = 5'd0;
            for (j = 0; j < 20; j = j + 8) begin
                if (j + 8 <= 20) begin
                    count = count + popcount_lut[value[j+7:j]];
                end else begin
                    count = count + popcount_lut[value[19:j]];
                end
            end
            compute_popcount = count;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 8'd0;
            k_reg <= 5'd0;
            vector_count <= 8'd0;
            candidate <= 20'd0;
            best_candidate <= 20'd0;
            min_max_similarity <= 5'd20;
            current_max_similarity <= 5'd0;
            current_similarity <= 5'd0;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = STORE_VECTORS;
                end
            end

            STORE_VECTORS: begin
                if (vector_count == n_reg - 1 && data_valid) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                if (candidate == (1 << k_reg) - 1) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        vector_count <= 8'd0;
                        min_max_similarity <= 5'd20;
                        best_candidate <= 20'd0;
                    end
                end

                STORE_VECTORS: begin
                    if (data_valid) begin
                        stored_vectors[vector_count] <= data_in[19:0];
                        vector_count <= vector_count + 1;
                    end
                end

                COMPUTE: begin
                    if (candidate == 0) begin
                        current_max_similarity <= 5'd0;
                    end

                    // Compute similarity for current candidate
                    current_similarity <= k_reg - compute_popcount(candidate ^ stored_vectors[vector_count]);

                    // Update max similarity
                    if (current_similarity > current_max_similarity) begin
                        current_max_similarity <= current_similarity;
                    end

                    // Check if we've processed all vectors for this candidate
                    if (vector_count == n_reg - 1) begin
                        // Update best candidate if needed
                        if (current_max_similarity < min_max_similarity) begin
                            min_max_similarity <= current_max_similarity;
                            best_candidate <= candidate;
                        end
                        candidate <= candidate + 1;
                        vector_count <= 8'd0;
                    end else begin
                        vector_count <= vector_count + 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= best_candidate;
                end

                default: begin
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule