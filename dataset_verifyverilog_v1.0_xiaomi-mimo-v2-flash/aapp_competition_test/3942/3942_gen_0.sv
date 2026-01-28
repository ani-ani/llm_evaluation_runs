module TreasureMap(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire valid_in,
    output reg [15:0] result,
    output reg result_valid,
    output reg done,
    output reg failure
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESSING = 3'd1;
    localparam [2:0] CALC_FINAL = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] ERROR = 3'd4;
    localparam [2:0] DONE = 3'd5;
    
    // Registers and variables
    reg [2:0] state, next_state;
    reg signed [31:0] balance;
    reg [3:0] hash_count;
    reg [3:0] last_hash_pos;
    reg [3:0] hash_outputs [0:15];
    reg [3:0] current_hash_idx;
    reg [7:0] cycle_counter;
    reg [3:0] output_idx;
    
    integer i;
    
    // Control signals
    wire balance_negative;
    assign balance_negative = (balance < 32'sd0);
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            balance <= 32'sd0;
            hash_count <= 4'd0;
            last_hash_pos <= 4'd0;
            current_hash_idx <= 4'd0;
            cycle_counter <= 8'd0;
            output_idx <= 4'd0;
            result <= 16'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            failure <= 1'b0;
            // Initialize hash_outputs array
            for (i = 0; i < 16; i = i + 1) begin
                hash_outputs[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            // Default outputs
            result_valid <= 1'b0;
            done <= 1'b0;
            
            // State-specific operations
            case (state)
                IDLE: begin
                    // Clear outputs when idle
                    failure <= 1'b0;
                    if (start) begin
                        // Reset processing state (but not failure flag yet)
                        balance <= 32'sd0;
                        hash_count <= 4'd0;
                        last_hash_pos <= 4'd0;
                        current_hash_idx <= 4'd0;
                        cycle_counter <= 8'd0;
                        output_idx <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            hash_outputs[i] <= 4'd0;
                        end
                    end
                end
                
                PROCESSING: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (valid_in) begin
                        case (char_in)
                            8'h28: begin // '('
                                balance <= balance + 32'sd1;
                            end
                            8'h29: begin // ')'
                                balance <= balance - 32'sd1;
                            end
                            8'h23: begin // '#'
                                if (hash_count < 4'd15) begin
                                    hash_count <= hash_count + 4'd1;
                                    last_hash_pos <= hash_count;
                                    hash_outputs[hash_count] <= 4'd1;
                                    balance <= balance - 32'sd1;
                                end
                            end
                        endcase
                    end
                end
                
                CALC_FINAL: begin
                    // Calculate remaining for last hash
                    if (hash_count > 4'd0 && !failure) begin
                        // remaining = balance + 1
                        // Store in hash_outputs at last_hash_pos
                        hash_outputs[last_hash_pos] <= balance[3:0] + 4'd1;
                    end
                end
                
                OUTPUT: begin
                    if (output_idx < hash_count) begin
                        result <= {12'd0, hash_outputs[output_idx]};
                        result_valid <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                    end
                end
                
                ERROR: begin
                    result <= 16'hFFFF; // -1
                    result_valid <= 1'b1;
                    failure <= 1'b1;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end
            end
            
            PROCESSING: begin
                // Transition conditions
                if (balance_negative) begin
                    next_state = ERROR;
                end else if (cycle_counter >= 8'd255) begin
                    // Timeout safety
                    next_state = ERROR;
                end else if (!valid_in && (cycle_counter > 8'd0)) begin
                    // End of input (assuming no more valid_in after last character)
                    next_state = CALC_FINAL;
                end else begin
                    next_state = PROCESSING;
                end
            end
            
            CALC_FINAL: begin
                // Check if final calculation is valid
                if (hash_count > 4'd0) begin
                    // remaining = balance + 1
                    if ((balance + 32'sd1) <= 32'sd0) begin
                        next_state = ERROR;
                    end else begin
                        next_state = OUTPUT;
                    end
                end else begin
                    // No hashes, just finish
                    next_state = DONE;
                end
            end
            
            OUTPUT: begin
                if (output_idx >= hash_count) begin
                    next_state = DONE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            ERROR: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule