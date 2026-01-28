module max_independent_set (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [255:0] adj_matrix,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers
    reg [1:0] state;
    reg [7:0] mask;
    reg [7:0] max_size;
    reg [7:0] current_size;
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] bit_count;
    reg [7:0] cycle_count;
    reg valid;
    reg mask_done;
    reg pair_done;

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            max_size <= 8'd0;
            current_size <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            bit_count <= 8'd0;
            cycle_count <= 8'd0;
            valid <= 1'b1;
            mask_done <= 1'b0;
            pair_done <= 1'b0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        mask <= 8'd0;
                        max_size <= 8'd0;
                        mask_done <= 1'b0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Initialize for new mask
                    if (!mask_done) begin
                        current_size <= 8'd0;
                        i <= 8'd0;
                        j <= 8'd0;
                        valid <= 1'b1;
                        pair_done <= 1'b0;
                        mask_done <= 1'b0;

                        // Count bits in mask
                        bit_count <= 8'd0;
                        for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                            if (mask[bit_count]) begin
                                current_size <= current_size + 8'd1;
                            end
                        end
                    end

                    // Check all pairs in mask
                    if (!pair_done && valid) begin
                        if (j < n && i < n) begin
                            if (mask[i] && mask[j] && i != j) begin
                                if (adj_matrix[i*16 + j]) begin
                                    valid <= 1'b0;
                                end
                            end
                            j <= j + 8'd1;
                            if (j >= n) begin
                                j <= 8'd0;
                                i <= i + 8'd1;
                            end
                        end else begin
                            pair_done <= 1'b1;
                        end
                    end

                    // Update max_size if valid
                    if (pair_done && !mask_done) begin
                        if (valid && current_size > max_size) begin
                            max_size <= current_size;
                        end
                        mask_done <= 1'b1;
                    end

                    // Move to next mask
                    if (mask_done) begin
                        mask <= mask + 8'd1;
                        if (mask >= (1 << n) || cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= max_size;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule