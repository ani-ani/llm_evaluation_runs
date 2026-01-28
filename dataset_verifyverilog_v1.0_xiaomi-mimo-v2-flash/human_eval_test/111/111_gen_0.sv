module histogram(
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
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INPUT_STATE   = 3'd1;
    localparam [2:0] SCAN_MAX      = 3'd2;
    localparam [2:0] FILTER        = 3'd3;
    localparam [2:0] PACK          = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // Registers for state machine
    reg [2:0] state, next_state;
    
    // 26-element counter array for letters a-z
    reg [3:0] counters [0:25];  // 4-bit counter per letter (max 15)
    
    // Temporary registers for scanning and filtering
    reg [4:0] scan_idx;  // 0-25 for scanning
    reg [3:0] max_count;
    reg [4:0] filter_idx;  // 0-25 for filtering
    reg [3:0] output_idx;  // 0-15 for packing
    reg [3:0] temp_len;
    
    // Cycle counter to prevent infinite loops
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd256;
    
    // Temporary storage for filtered results
    reg [7:0] temp_letters [0:15];
    reg [3:0] temp_counts [0:15];
    
    // Internal signals
    reg [3:0] letter_idx;
    reg [3:0] i;
    reg [3:0] j;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INPUT_STATE;
                else next_state = IDLE;
            end
            INPUT_STATE: begin
                if (char_done) next_state = SCAN_MAX;
                else next_state = INPUT_STATE;
            end
            SCAN_MAX: begin
                if (scan_idx >= 5'd26) next_state = FILTER;
                else next_state = SCAN_MAX;
            end
            FILTER: begin
                if (filter_idx >= 5'd26) next_state = PACK;
                else next_state = FILTER;
            end
            PACK: begin
                if (output_idx >= temp_len) next_state = FINISH;
                else next_state = PACK;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            cycle_count <= 9'd0;
            result_letters <= 128'd0;
            result_counts <= 64'd0;
            result_len <= 4'd0;
            scan_idx <= 5'd0;
            max_count <= 4'd0;
            filter_idx <= 5'd0;
            output_idx <= 4'd0;
            temp_len <= 4'd0;
            // Initialize counters
            for (i = 0; i < 26; i = i + 1) begin
                counters[i] <= 4'd0;
            end
            // Initialize temp arrays
            for (j = 0; j < 16; j = j + 1) begin
                temp_letters[j] <= 8'd0;
                temp_counts[j] <= 4'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 9'd1;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    cycle_count <= 9'd0;
                    done <= 1'b0;
                    result_letters <= 128'd0;
                    result_counts <= 64'd0;
                    result_len <= 4'd0;
                    scan_idx <= 5'd0;
                    filter_idx <= 5'd0;
                    output_idx <= 4'd0;
                    temp_len <= 4'd0;
                    max_count <= 4'd0;
                    // Clear counters
                    for (i = 0; i < 26; i = i + 1) begin
                        counters[i] <= 4'd0;
                    end
                    // Clear temp arrays
                    for (j = 0; j < 16; j = j + 1) begin
                        temp_letters[j] <= 8'd0;
                        temp_counts[j] <= 4'd0;
                    end
                end
                
                INPUT_STATE: begin
                    ready <= 1'b1;
                    if (char_valid && char_in >= 8'h61 && char_in <= 8'h7A) begin
                        // Valid lowercase letter: a-z (0x61-0x7A)
                        letter_idx <= char_in[4:0];  // a=0x61->1, but we want a=0
                        if (counters[char_in[4:0]] < 4'd15) begin
                            counters[char_in[4:0]] <= counters[char_in[4:0]] + 4'd1;
                        end
                    end
                    // Note: space and other chars are ignored
                end
                
                SCAN_MAX: begin
                    ready <= 1'b0;
                    if (scan_idx < 5'd26) begin
                        if (counters[scan_idx] > max_count) begin
                            max_count <= counters[scan_idx];
                        end
                        scan_idx <= scan_idx + 5'd1;
                    end
                end
                
                FILTER: begin
                    ready <= 1'b0;
                    if (filter_idx < 5'd26) begin
                        if (counters[filter_idx] == max_count && max_count > 4'd0) begin
                            // Store matching letter and count
                            temp_letters[temp_len] <= {3'b110, filter_idx};  // ASCII: 0x60 + idx
                            temp_counts[temp_len] <= counters[filter_idx];
                            temp_len <= temp_len + 4'd1;
                        end
                        filter_idx <= filter_idx + 5'd1;
                    end
                end
                
                PACK: begin
                    ready <= 1'b0;
                    if (output_idx < temp_len) begin
                        // Pack into result vectors
                        result_letters[output_idx*8 +: 8] <= temp_letters[output_idx];
                        result_counts[output_idx*4 +: 4] <= temp_counts[output_idx];
                        output_idx <= output_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    ready <= 1'b0;
                    done <= 1'b1;
                    result_len <= temp_len;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= FINISH;
            end
        end
    end

endmodule