module histogram_module(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_done,
    output reg [127:0] result_letters,
    output reg [63:0] result_counts,
    output reg [3:0] result_len,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FIND_MAX = 3'd2;
    localparam [2:0] PACK_RESULTS = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Letter count array (26 letters a-z)
    reg [3:0] letter_counts [0:25];
    reg [7:0] current_char;
    reg [3:0] max_count;
    reg [3:0] current_count;
    reg [3:0] result_index;
    reg [3:0] letter_index;
    reg [3:0] letter_pos;
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            ready <= 1'b1;
            result_len <= 4'd0;
            result_letters <= 128'd0;
            result_counts <= 64'd0;
            current_char <= 8'd0;
            max_count <= 4'd0;
            current_count <= 4'd0;
            result_index <= 4'd0;
            letter_index <= 4'd0;
            letter_pos <= 4'd0;
            cycle_count <= 8'd0;

            // Initialize letter counts
            integer i;
            for (i = 0; i < 26; i = i + 1) begin
                letter_counts[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        ready <= 1'b0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    ready <= 1'b1;

                    if (char_valid && !char_done) begin
                        current_char <= char_in;
                        // Check if lowercase letter (a-z)
                        if (current_char >= 8'd97 && current_char <= 8'd122) begin
                            letter_pos <= current_char - 8'd97;
                            letter_counts[letter_pos] <= letter_counts[letter_pos] + 4'd1;
                        end
                    end

                    if (char_done) begin
                        state <= FIND_MAX;
                        ready <= 1'b0;
                        letter_index <= 4'd0;
                        max_count <= 4'd0;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                FIND_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    ready <= 1'b0;

                    if (letter_index < 4'd26) begin
                        current_count <= letter_counts[letter_index];
                        if (current_count > max_count) begin
                            max_count <= current_count;
                        end
                        letter_index <= letter_index + 4'd1;
                    end else begin
                        state <= PACK_RESULTS;
                        result_index <= 4'd0;
                        letter_index <= 4'd0;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                PACK_RESULTS: begin
                    cycle_count <= cycle_count + 8'd1;
                    ready <= 1'b0;

                    if (letter_index < 4'd26 && result_index < 4'd16) begin
                        current_count <= letter_counts[letter_index];
                        if (current_count == max_count && max_count > 4'd0) begin
                            // Pack letter and count
                            result_letters[(result_index * 8) +: 8] <= 8'd97 + letter_index;
                            result_counts[(result_index * 4) +: 4] <= current_count;
                            result_index <= result_index + 4'd1;
                        end
                        letter_index <= letter_index + 4'd1;
                    end else begin
                        result_len <= result_index;
                        state <= DONE_STATE;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    ready <= 1'b1;
                end
            endcase
        end
    end

endmodule