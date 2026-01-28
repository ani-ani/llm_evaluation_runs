module BestSolutionSequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] seq_data [0:127],
    input wire [3:0] seq_lens [0:7],
    input wire [7:0] total_len,
    output reg [7:0] out_val,
    output reg out_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] output_counter;
    reg [3:0] seq_ptr [0:7];
    reg [7:0] current_min_val;
    reg [2:0] current_min_seq;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            output_counter <= 8'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                seq_ptr[i] <= 4'd0;
            end
            current_min_val <= 8'd0;
            current_min_seq <= 3'd0;
            cycle_count <= 8'd0;
            out_val <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = COMPARE;
            end

            COMPARE: begin
                next_state = OUTPUT;
            end

            OUTPUT: begin
                if (output_counter == total_len - 8'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPARE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_counter <= 8'd0;
        end else if (state == OUTPUT) begin
            output_counter <= output_counter + 8'd1;
        end
    end

    // Sequence pointer update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                seq_ptr[i] <= 4'd0;
            end
        end else if (state == OUTPUT) begin
            seq_ptr[current_min_seq] <= seq_ptr[current_min_seq] + 4'd1;
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE) begin
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Comparison logic (combinational)
    always @(*) begin
        reg [7:0] min_val = 8'd255;
        reg [2:0] min_seq = 3'd0;
        reg [7:0] val_a, val_b;
        reg [3:0] ptr_a, ptr_b;
        reg [7:0] lookahead_a, lookahead_b;
        reg [7:0] lookahead_depth;

        // Find the sequence with minimum value using lookahead
        for (integer i = 0; i < 8; i = i + 1) begin
            if (seq_ptr[i] < seq_lens[i]) begin
                val_a = seq_data[i * 16 + seq_ptr[i]];
                ptr_a = seq_ptr[i];

                for (integer j = 0; j < 8; j = j + 1) begin
                    if (seq_ptr[j] < seq_lens[j] && i != j) begin
                        val_b = seq_data[j * 16 + seq_ptr[j]];
                        ptr_b = seq_ptr[j];

                        // Direct comparison
                        if (val_a < val_b) begin
                            min_val = val_a;
                            min_seq = i;
                        end else if (val_a > val_b) begin
                            min_val = val_b;
                            min_seq = j;
                        end else begin
                            // Lookahead comparison (max 4 elements)
                            lookahead_depth = 8'd0;
                            while (lookahead_depth < 8'd4 && 
                                  (ptr_a + lookahead_depth + 8'd1 < seq_lens[i]) &&
                                  (ptr_b + lookahead_depth + 8'd1 < seq_lens[j])) begin
                                lookahead_a = seq_data[i * 16 + ptr_a + lookahead_depth + 8'd1];
                                lookahead_b = seq_data[j * 16 + ptr_b + lookahead_depth + 8'd1];

                                if (lookahead_a < lookahead_b) begin
                                    min_val = val_a;
                                    min_seq = i;
                                    break;
                                end else if (lookahead_a > lookahead_b) begin
                                    min_val = val_b;
                                    min_seq = j;
                                    break;
                                end
                                lookahead_depth = lookahead_depth + 8'd1;
                            end

                            // If all compared elements are equal, choose the shorter sequence
                            if (lookahead_depth == 8'd4 ||
                               (ptr_a + lookahead_depth + 8'd1 >= seq_lens[i]) ||
                               (ptr_b + lookahead_depth + 8'd1 >= seq_lens[j])) begin
                                if (seq_lens[i] < seq_lens[j]) begin
                                    min_val = val_a;
                                    min_seq = i;
                                end else begin
                                    min_val = val_b;
                                    min_seq = j;
                                end
                            end
                        end
                    end
                end
            end
        end

        current_min_val = min_val;
        current_min_seq = min_seq;
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_val <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end

                INIT: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end

                COMPARE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end

                OUTPUT: begin
                    out_val <= current_min_val;
                    out_valid <= 1'b1;
                    done <= 1'b0;
                end

                DONE: begin
                    out_val <= 8'd0;
                    out_valid <= 1'b0;
                    done <= 1'b1;
                end

                default: begin
                    out_val <= 8'd0;
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety: Force done if cycle count exceeds maximum
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            done <= 1'b1;
            next_state <= IDLE;
        end
    end

endmodule