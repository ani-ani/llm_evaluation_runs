module IPv4BlacklistOptimizer (
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
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] READ_INPUTS    = 3'd1;
    localparam [2:0] CHECK_CONFLICTS = 3'd2;
    localparam [2:0] GENERATE_OUTPUTS = 3'd3;
    localparam [2:0] FINISHED       = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Constants
    localparam [3:0] MAX_SUBNETS = 4'd16;
    localparam [3:0] MAX_IP_WIDTH = 4'd8;
    localparam [3:0] MAX_LEN_WIDTH = 4'd4;
    
    // Registers for input storage
    reg [3:0] num_subnets;
    reg [3:0] input_index;
    reg [3:0] output_index;
    
    // Arrays for storing subnets (16 entries of 12 bits: 8-bit IP + 4-bit len)
    // Using individual registers instead of arrays per Icarus Verilog compatibility
    reg [11:0] black_subnets [0:15];
    reg [11:0] white_subnets [0:15];
    reg [3:0] black_count;
    reg [3:0] white_count;
    
    // Conflict detection flags
    reg conflict_detected;
    
    // Output generation control
    reg [3:0] current_black_idx;
    
    // State machine sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            num_subnets <= 4'd0;
            input_index <= 4'd0;
            output_index <= 4'd0;
            black_count <= 4'd0;
            white_count <= 4'd0;
            conflict_detected <= 1'b0;
            current_black_idx <= 4'd0;
            output_valid <= 1'b0;
            output_ip <= 8'd0;
            output_len <= 4'd0;
            error <= 1'b0;
            done <= 1'b0;
            // Initialize all subnet entries
            black_subnets[0] <= 12'd0; black_subnets[1] <= 12'd0;
            black_subnets[2] <= 12'd0; black_subnets[3] <= 12'd0;
            black_subnets[4] <= 12'd0; black_subnets[5] <= 12'd0;
            black_subnets[6] <= 12'd0; black_subnets[7] <= 12'd0;
            black_subnets[8] <= 12'd0; black_subnets[9] <= 12'd0;
            black_subnets[10] <= 12'd0; black_subnets[11] <= 12'd0;
            black_subnets[12] <= 12'd0; black_subnets[13] <= 12'd0;
            black_subnets[14] <= 12'd0; black_subnets[15] <= 12'd0;
            white_subnets[0] <= 12'd0; white_subnets[1] <= 12'd0;
            white_subnets[2] <= 12'd0; white_subnets[3] <= 12'd0;
            white_subnets[4] <= 12'd0; white_subnets[5] <= 12'd0;
            white_subnets[6] <= 12'd0; white_subnets[7] <= 12'd0;
            white_subnets[8] <= 12'd0; white_subnets[9] <= 12'd0;
            white_subnets[10] <= 12'd0; white_subnets[11] <= 12'd0;
            white_subnets[12] <= 12'd0; white_subnets[13] <= 12'd0;
            white_subnets[14] <= 12'd0; white_subnets[15] <= 12'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    num_subnets <= 4'd0;
                    input_index <= 4'd0;
                    output_index <= 4'd0;
                    black_count <= 4'd0;
                    white_count <= 4'd0;
                    conflict_detected <= 1'b0;
                    current_black_idx <= 4'd0;
                    // Initialize all subnet entries
                    black_subnets[0] <= 12'd0; black_subnets[1] <= 12'd0;
                    black_subnets[2] <= 12'd0; black_subnets[3] <= 12'd0;
                    black_subnets[4] <= 12'd0; black_subnets[5] <= 12'd0;
                    black_subnets[6] <= 12'd0; black_subnets[7] <= 12'd0;
                    black_subnets[8] <= 12'd0; black_subnets[9] <= 12'd0;
                    black_subnets[10] <= 12'd0; black_subnets[11] <= 12'd0;
                    black_subnets[12] <= 12'd0; black_subnets[13] <= 12'd0;
                    black_subnets[14] <= 12'd0; black_subnets[15] <= 12'd0;
                    white_subnets[0] <= 12'd0; white_subnets[1] <= 12'd0;
                    white_subnets[2] <= 12'd0; white_subnets[3] <= 12'd0;
                    white_subnets[4] <= 12'd0; white_subnets[5] <= 12'd0;
                    white_subnets[6] <= 12'd0; white_subnets[7] <= 12'd0;
                    white_subnets[8] <= 12'd0; white_subnets[9] <= 12'd0;
                    white_subnets[10] <= 12'd0; white_subnets[11] <= 12'd0;
                    white_subnets[12] <= 12'd0; white_subnets[13] <= 12'd0;
                    white_subnets[14] <= 12'd0; white_subnets[15] <= 12'd0;
                end
                
                READ_INPUTS: begin
                    if (input_valid) begin
                        if (input_is_black) begin
                            if (black_count < MAX_SUBNETS) begin
                                black_subnets[black_count] <= {input_ip, input_len};
                                black_count <= black_count + 4'd1;
                            end
                        end else begin
                            if (white_count < MAX_SUBNETS) begin
                                white_subnets[white_count] <= {input_ip, input_len};
                                white_count <= white_count + 4'd1;
                            end
                        end
                    end
                end
                
                CHECK_CONFLICTS: begin
                    // Check for conflicts: white subnet covered by black subnet
                    if (white_count > 4'd0 && current_black_idx < black_count) begin
                        // Check current black subnet against all white subnets
                        if (white_subnets[input_index][11:8] == black_subnets[current_black_idx][11:8]) begin
                            // IPs match, check if black covers white
                            if (black_subnets[current_black_idx][3:0] <= white_subnets[input_index][3:0]) begin
                                conflict_detected <= 1'b1;
                            end
                        end
                        // Advance white index or black index based on counters
                        if (input_index < white_count - 4'd1) begin
                            input_index <= input_index + 4'd1;
                        end else begin
                            input_index <= 4'd0;
                            current_black_idx <= current_black_idx + 4'd1;
                        end
                    end else begin
                        // Reset indices for next phase
                        current_black_idx <= 4'd0;
                        input_index <= 4'd0;
                    end
                end
                
                GENERATE_OUTPUTS: begin
                    if (output_index < black_count && !conflict_detected) begin
                        output_valid <= 1'b1;
                        output_ip <= black_subnets[output_index][11:4];
                        output_len <= black_subnets[output_index][3:0];
                        output_index <= output_index + 4'd1;
                    end else begin
                        output_valid <= 1'b0;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    error <= conflict_detected;
                    output_valid <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_INPUTS;
                end
            end
            
            READ_INPUTS: begin
                if (input_last && input_valid) begin
                    next_state = CHECK_CONFLICTS;
                end
            end
            
            CHECK_CONFLICTS: begin
                if (white_count == 4'd0) begin
                    // No white subnets, skip conflict check
                    next_state = GENERATE_OUTPUTS;
                end else if (conflict_detected) begin
                    next_state = FINISHED;
                end else if (current_black_idx >= black_count) begin
                    // Finished checking all black subnets
                    next_state = GENERATE_OUTPUTS;
                end
            end
            
            GENERATE_OUTPUTS: begin
                if (output_index >= black_count) begin
                    next_state = FINISHED;
                end
            end
            
            FINISHED: begin
                if (start) begin
                    next_state = READ_INPUTS;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule