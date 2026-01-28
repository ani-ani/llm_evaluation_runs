module StringFilter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] strings [0:7],
    input wire [7:0] prefix,
    input wire [7:0] valid_strings,
    output reg [7:0] result_str [0:7],
    output reg [7:0] result_valid,
    output reg [3:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_PREFIX = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] COPY = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [2:0] string_index;
    reg [2:0] char_index;
    reg [7:0] prefix_length;
    reg [7:0] current_string [0:7];
    reg [7:0] current_result_str [0:7];
    reg [7:0] current_result_valid;
    reg [3:0] current_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            string_index <= 3'd0;
            char_index <= 3'd0;
            prefix_length <= 8'd0;
            current_count <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_count <= 4'd0;
            result_valid <= 8'd0;
            
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    current_string[i][j] <= 8'd0;
                    current_result_str[i][j] <= 8'd0;
                    result_str[i][j] <= 8'd0;
                end
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                current_result_valid[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_PREFIX;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_PREFIX: begin
                    // Calculate prefix length
                    if (prefix[char_index] == 8'd0) begin
                        prefix_length <= char_index;
                        char_index <= 3'd0;
                        string_index <= 3'd0;
                        next_state <= COMPARE;
                    end else begin
                        char_index <= char_index + 3'd1;
                        next_state <= LOAD_PREFIX;
                    end
                end

                COMPARE: begin
                    // Load current string
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        current_string[string_index][i] <= strings[string_index][i];
                    end
                    
                    // Check if string is valid
                    if (valid_strings[string_index]) begin
                        // Compare prefix
                        reg match;
                        match = 1'b1;
                        
                        integer j;
                        for (j = 0; j < prefix_length; j = j + 1) begin
                            if (current_string[string_index][j] != prefix[j]) begin
                                match = 1'b0;
                            end
                        end
                        
                        if (match) begin
                            next_state <= COPY;
                        end else begin
                            string_index <= string_index + 3'd1;
                            if (string_index == 3'd7) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= COMPARE;
                            end
                        end
                    end else begin
                        string_index <= string_index + 3'd1;
                        if (string_index == 3'd7) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= COMPARE;
                        end
                    end
                end

                COPY: begin
                    // Copy string to result
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        current_result_str[current_count][i] <= current_string[string_index][i];
                    end
                    current_result_valid[current_count] <= 1'b1;
                    current_count <= current_count + 4'd1;
                    
                    string_index <= string_index + 3'd1;
                    if (string_index == 3'd7) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= COMPARE;
                    end
                end

                DONE_STATE: begin
                    // Copy results to output
                    integer i, j;
                    for (i = 0; i < 8; i = i + 1) begin
                        result_valid[i] <= current_result_valid[i];
                        for (j = 0; j < 8; j = j + 1) begin
                            result_str[i][j] <= current_result_str[i][j];
                        end
                    end
                    result_count <= current_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule