module StringFilter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] strings [0:7],
    input wire [127:0] substring,
    input wire [3:0] str_len,
    output reg result_valid,
    output reg [3:0] result_count,
    output reg [127:0] result_strings [0:7]
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] OUTPUT    = 3'd2;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Processing variables
    reg [2:0] current_string;
    reg [3:0] substring_pos;
    reg [3:0] string_pos;
    reg [3:0] match_count;
    reg [7:0] substring_len;
    reg [7:0] string_length;
    reg [7:0] i, j;
    reg match_found;
    reg [7:0] result_index;

    // Convert str_len to actual length (0-15)
    always @(*) begin
        substring_len = substring[127:120] === 8'd0 ? 8'd1 : 
                       substring[127:112] === 16'd0 ? 8'd1 : 
                       substring[127:104] === 24'd0 ? 8'd1 : 
                       substring[127:96]  === 32'd0 ? 8'd1 : 
                       substring[127:88]  === 40'd0 ? 8'd1 : 
                       substring[127:80]  === 48'd0 ? 8'd1 : 
                       substring[127:72]  === 56'd0 ? 8'd1 : 
                       substring[127:64]  === 64'd0 ? 8'd1 : 
                       substring[127:56]  === 72'd0 ? 8'd1 : 
                       substring[127:48]  === 80'd0 ? 8'd1 : 
                       substring[127:40]  === 88'd0 ? 8'd1 : 
                       substring[127:32]  === 96'd0 ? 8'd1 : 
                       substring[127:24]  === 104'd0 ? 8'd1 : 
                       substring[127:16]  === 112'd0 ? 8'd1 : 
                       substring[127:8]   === 120'd0 ? 8'd1 : 
                       substring[127:0]   === 128'd0 ? 8'd0 : 8'd16;
        
        // If substring_len is 0, set to 1 (minimum length)
        substring_len = (substring_len == 8'd0) ? 8'd1 : substring_len;
        
        // String length from input (0-15)
        string_length = str_len + 4'd1;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_string <= 3'd0;
            substring_pos <= 4'd0;
            string_pos <= 4'd0;
            match_count <= 4'd0;
            match_found <= 1'b0;
            result_index <= 8'd0;
            result_valid <= 1'b0;
            result_count <= 4'd0;
            
            // Initialize result strings to 0
            for (i = 0; i < 8; i = i + 1) begin
                result_strings[i] <= 128'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    current_string <= 3'd0;
                    substring_pos <= 4'd0;
                    string_pos <= 4'd0;
                    match_count <= 4'd0;
                    match_found <= 1'b0;
                    result_index <= 8'd0;
                    result_count <= 4'd0;
                    
                    // Initialize result strings to 0
                    for (i = 0; i < 8; i = i + 1) begin
                        result_strings[i] <= 128'd0;
                    end
                    
                    if (start) begin
                        next_state <= PROCESS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all strings
                    if (current_string == 3'd7 && match_found) begin
                        // Move to output state
                        next_state <= OUTPUT;
                    
                    // Process current string
                    else if (!match_found) begin
                        // Check if substring matches at current position
                        if (strings[current_string][(string_pos+1)*8-1:string_pos*8] == 
                            substring[substring_pos*8+7:substring_pos*8]) begin
                            substring_pos <= substring_pos + 4'd1;
                            
                            // Check if full substring matched
                            if (substring_pos == substring_len - 4'd1) begin
                                match_found <= 1'b1;
                                
                                // Store the matching string
                                result_strings[result_index] <= strings[current_string];
                                result_index <= result_index + 8'd1;
                                
                                // Increment match count
                                match_count <= match_count + 4'd1;
                                
                                // Move to next string
                                current_string <= current_string + 3'd1;
                                substring_pos <= 4'd0;
                                string_pos <= 4'd0;
                                match_found <= 1'b0;
                            end
                        end else begin
                            substring_pos <= 4'd0;
                            string_pos <= string_pos + 4'd1;
                            
                            // Check if we've reached end of string
                            if (string_pos == string_length - substring_len) begin
                                // No match found, move to next string
                                current_string <= current_string + 3'd1;
                                substring_pos <= 4'd0;
                                string_pos <= 4'd0;
                                match_found <= 1'b0;
                            end
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_valid <= 1'b1;
                    result_count <= match_count;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PROCESS : IDLE;
            PROCESS: next_state = (current_string == 3'd7 && match_found) ? OUTPUT : PROCESS;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule