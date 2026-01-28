module IPv4BlacklistOptimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire input_valid,
    input wire [7:0] input_ip,
    input wire [3:0] input_len,
    input wire input_is_black,
    input wire input_last,
    output reg output_valid,
    output reg [7:0] output_ip,
    output reg [3:0] output_len,
    output reg error,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_INPUTS = 3'd1;
    localparam [2:0] CHECK_CONFLICTS = 3'd2;
    localparam [2:0] GENERATE_OUTPUTS = 3'd3;
    localparam [2:0] FINISHED = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Input storage (max 16 subnets)
    reg [7:0] black_ip [0:15];
    reg [3:0] black_len [0:15];
    reg [7:0] white_ip [0:15];
    reg [3:0] white_len [0:15];
    reg [3:0] black_count, white_count;
    reg [3:0] input_index;
    
    // Conflict check variables
    reg [3:0] white_idx, black_idx;
    reg conflict_detected;
    
    // Output generation variables
    reg [3:0] output_idx;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Clear input storage
            for (input_index = 0; input_index < 16; input_index = input_index + 1) begin
                black_ip[input_index] <= 8'd0;
                black_len[input_index] <= 4'd0;
                white_ip[input_index] <= 8'd0;
                white_len[input_index] <= 4'd0;
            end
            
            black_count <= 4'd0;
            white_count <= 4'd0;
            input_index <= 4'd0;
            
            // Clear conflict check variables
            white_idx <= 4'd0;
            black_idx <= 4'd0;
            conflict_detected <= 1'b0;
            
            // Clear output generation variables
            output_idx <= 4'd0;
            
            // Clear outputs
            output_valid <= 1'b0;
            output_ip <= 8'd0;
            output_len <= 4'd0;
            error <= 1'b0;
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
                    next_state = READ_INPUTS;
                end
            end
            
            READ_INPUTS: begin
                if (input_valid) begin
                    if (input_is_black) begin
                        if (black_count < 16) begin
                            black_ip[black_count] = input_ip;
                            black_len[black_count] = input_len;
                            black_count = black_count + 1;
                        end
                    end else begin
                        if (white_count < 16) begin
                            white_ip[white_count] = input_ip;
                            white_len[white_count] = input_len;
                            white_count = white_count + 1;
                        end
                    end
                    
                    if (input_last) begin
                        next_state = CHECK_CONFLICTS;
                    end
                end
            end
            
            CHECK_CONFLICTS: begin
                if (white_idx < white_count) begin
                    if (black_idx < black_count) begin
                        // Check if current white subnet is covered by current black subnet
                        if (check_coverage(white_ip[white_idx], white_len[white_idx], 
                                          black_ip[black_idx], black_len[black_idx])) begin
                            conflict_detected = 1'b1;
                        end
                        black_idx = black_idx + 1;
                    end else begin
                        black_idx = 4'd0;
                        white_idx = white_idx + 1;
                    end
                end else begin
                    if (conflict_detected) begin
                        error = 1'b1;
                        next_state = FINISHED;
                    end else begin
                        next_state = GENERATE_OUTPUTS;
                    end
                end
            end
            
            GENERATE_OUTPUTS: begin
                if (output_idx < black_count) begin
                    output_valid = 1'b1;
                    output_ip = black_ip[output_idx];
                    output_len = black_len[output_idx];
                    output_idx = output_idx + 1;
                end else begin
                    output_valid = 1'b0;
                    next_state = FINISHED;
                end
            end
            
            FINISHED: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Function to check if white subnet is covered by black subnet
    function check_coverage;
        input [7:0] white_ip;
        input [3:0] white_len;
        input [7:0] black_ip;
        input [3:0] black_len;
        
        reg [7:0] mask;
        reg [7:0] masked_white;
        reg [7:0] masked_black;
        
        begin
            // Create mask based on black_len
            mask = (black_len == 4'd0) ? 8'd0 : (8'd255 << (8 - black_len));
            
            // Apply mask to both IPs
            masked_white = white_ip & mask;
            masked_black = black_ip & mask;
            
            // Check if white subnet is covered by black subnet
            if ((masked_white == masked_black) && (black_len <= white_len)) begin
                check_coverage = 1'b1;
            end else begin
                check_coverage = 1'b0;
            end
        end
    endfunction
    
endmodule