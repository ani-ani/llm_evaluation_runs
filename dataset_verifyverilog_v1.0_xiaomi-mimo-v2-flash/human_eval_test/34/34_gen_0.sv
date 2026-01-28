module sort_dedup (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg [3:0] out_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] SORT       = 3'd2;
    localparam [2:0] DEDUP      = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] buffer [0:7];      // Internal buffer for sorting
    reg [2:0] i, j;              // Loop counters
    reg [3:0] temp_len;          // Temporary length during processing
    reg [2:0] pass_count;        // Bubble sort pass counter
    reg [2:0] bubble_idx;        // Bubble sort index
    reg [2:0] dedup_idx;         // Deduplication index
    reg [7:0] prev_val;          // Previous value for duplicate check
    reg [2:0] cycle_count;       // Prevent infinite loops
    localparam [2:0] MAX_CYCLES = 3'd6;  // Max iterations per state

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_len <= 4'd0;
            temp_len <= 4'd0;
            pass_count <= 3'd0;
            bubble_idx <= 3'd0;
            dedup_idx <= 3'd0;
            prev_val <= 8'd0;
            cycle_count <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
                buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        // Initialize all registers
                        temp_len <= len;
                        pass_count <= 3'd0;
                        bubble_idx <= 3'd0;
                        dedup_idx <= 3'd0;
                        prev_val <= 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            buffer[i] <= 8'd0;
                            result[i] <= 8'd0;
                        end
                        out_len <= 4'd0;
                    end
                end

                READ_INPUT: begin
                    if (cycle_count < 3'd7) begin
                        if (cycle_count < len) begin
                            buffer[cycle_count] <= arr[cycle_count];
                        end
                        cycle_count <= cycle_count + 3'd1;
                    end
                end

                SORT: begin
                    if (pass_count < temp_len - 3'd1) begin
                        if (bubble_idx < temp_len - 3'd1 - pass_count) begin
                            if (buffer[bubble_idx] > buffer[bubble_idx + 3'd1]) begin
                                buffer[bubble_idx] <= buffer[bubble_idx + 3'd1];
                                buffer[bubble_idx + 3'd1] <= buffer[bubble_idx];
                            end
                            bubble_idx <= bubble_idx + 3'd1;
                        end else begin
                            pass_count <= pass_count + 3'd1;
                            bubble_idx <= 3'd0;
                        end
                    end
                end

                DEDUP: begin
                    if (dedup_idx < temp_len) begin
                        if (dedup_idx == 3'd0) begin
                            result[0] <= buffer[0];
                            out_len <= 4'd1;
                            prev_val <= buffer[0];
                        end else if (buffer[dedup_idx] != prev_val) begin
                            result[out_len] <= buffer[dedup_idx];
                            out_len <= out_len + 4'd1;
                            prev_val <= buffer[dedup_idx];
                        end
                        dedup_idx <= dedup_idx + 3'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (len == 4'd0) begin
                        next_state = FINISH;  // Empty input - go directly to finish
                    end else begin
                        next_state = READ_INPUT;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            READ_INPUT: begin
                if (cycle_count >= 3'd7) begin
                    if (temp_len <= 4'd1) begin
                        next_state = DEDUP;  // No sorting needed for 0-1 elements
                    end else begin
                        next_state = SORT;
                    end
                end else begin
                    next_state = READ_INPUT;
                end
            end

            SORT: begin
                if (pass_count >= temp_len - 3'd1) begin
                    next_state = DEDUP;
                end else begin
                    next_state = SORT;
                end
            end

            DEDUP: begin
                if (dedup_idx >= temp_len) begin
                    next_state = FINISH;
                end else begin
                    next_state = DEDUP;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule