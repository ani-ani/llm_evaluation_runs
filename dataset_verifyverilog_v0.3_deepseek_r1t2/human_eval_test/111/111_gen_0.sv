module histogram (
    input clk,
    input rst_n,
    input start,
    input [7:0] str_in [0:7],
    input [2:0] valid_chars,
    output reg [7:0] result_char,
    output reg [7:0] result_count,
    output reg done
);
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] FIND_MAX = 3'd3;
    localparam [2:0] DONE = 3'd4;

    reg [2:0] state, next_state;
    reg [2:0] count_index;
    reg [4:0] find_max_counter;
    reg [7:0] freq [0:26];
    reg [2:0] first_pos [0:26];
    reg [7:0] current_max_count;
    reg [4:0] current_max_index;
    reg [2:0] current_min_first_pos;
    reg [7:0] current_char;
    reg [4:0] char_index;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_char <= 8'd0;
            result_count <= 8'd0;
            count_index <= 3'd0;
            find_max_counter <= 5'd0;
            current_max_count <= 8'd0;
            current_max_index <= 5'd0;
            current_min_first_pos <= 3'd7;
            for (i = 0; i <= 26; i = i + 1) begin
                freq[i] <= 8'd0;
                first_pos[i] <= 3'd7;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READ;
                        count_index <= 3'd0;
                    end
                end

                READ: begin
                    // Initialize tracking variables for new computation
                    current_max_count <= 8'd0;
                    current_max_index <= 5'd0;
                    current_min_first_pos <= 3'd7;
                    for (i = 0; i <= 26; i = i + 1) begin
                        freq[i] <= 8'd0;
                        first_pos[i] <= 3'd7;
                    end
                    state <= COUNT;
                end

                COUNT: begin
                    current_char = str_in[count_index];
                    char_index = 5'd27; // Default invalid
                    if (current_char == 8'h20) begin
                        char_index = 5'd0;
                    end else if (current_char >= 8'h61 && current_char <= 8'h7A) begin
                        char_index = (current_char - 8'h60);
                    end

                    if (char_index <= 5'd26) begin
                        // If this is the first occurrence, set first_pos
                        if (freq[char_index] == 8'd0) begin
                            first_pos[char_index] <= count_index;
                        end
                        freq[char_index] <= freq[char_index] + 8'd1;
                    end

                    if (count_index == (valid_chars - 3'd1) || valid_chars == 3'd0) begin
                        state <= FIND_MAX;
                        find_max_counter <= 5'd0;
                    end else begin
                        count_index <= count_index + 3'd1;
                    end
                end

                FIND_MAX: begin
                    if (find_max_counter <= 5'd26) begin
                        if (freq[find_max_counter] > current_max_count ||
                            (freq[find_max_counter] == current_max_count && first_pos[find_max_counter] < current_min_first_pos)) begin
                            if (freq[find_max_counter] != current_max_count || first_pos[find_max_counter] < current_min_first_pos) begin
                                current_min_first_pos <= first_pos[find_max_counter];
                            end
                            if (freq[find_max_counter] > current_max_count) begin
                                current_max_count <= freq[find_max_counter];
                                current_min_first_pos <= first_pos[find_max_counter];
                            end
                            current_max_index <= find_max_counter;
                        end
                        find_max_counter <= find_max_counter + 5'd1;
                    end else begin
                        state <= DONE;
                        // Map index back to ASCII
                        if (current_max_index == 5'd0) begin
                            result_char <= 8'h20;
                        end else begin
                            result_char <= (8'h60 + current_max_index);
                        end
                        result_count <= current_max_count;
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