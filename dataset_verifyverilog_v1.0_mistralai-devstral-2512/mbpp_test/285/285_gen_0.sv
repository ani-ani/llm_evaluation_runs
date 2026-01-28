module pattern_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:15],
    input [3:0] length,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;
    
    // Pattern detection states
    localparam [2:0] WAIT_A = 3'd0;
    localparam [2:0] WAIT_B1 = 3'd1;
    localparam [2:0] WAIT_B2 = 3'd2;
    localparam [2:0] WAIT_B3 = 3'd3;
    
    reg [2:0] state;
    reg [2:0] pattern_state;
    reg [3:0] index;
    reg [7:0] current_char;
    reg [7:0] pattern_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pattern_state <= WAIT_A;
            index <= 4'd0;
            current_char <= 8'd0;
            pattern_found <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SCAN;
                        pattern_state <= WAIT_A;
                        index <= 4'd0;
                        pattern_found <= 8'd0;
                    end
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Read current character
                    current_char <= text[index];
                    
                    // Pattern detection FSM
                    case (pattern_state)
                        WAIT_A: begin
                            if (current_char == 8'd97) begin  // 'a'
                                pattern_state <= WAIT_B1;
                            end
                        end
                        
                        WAIT_B1: begin
                            if (current_char == 8'd98) begin  // 'b'
                                pattern_state <= WAIT_B2;
                            else begin
                                pattern_state <= WAIT_A;
                            end
                        end
                        
                        WAIT_B2: begin
                            if (current_char == 8'd98) begin  // 'b'
                                pattern_state <= WAIT_B3;
                                pattern_found <= 8'd1;  // Found 'abb'
                            else begin
                                pattern_state <= WAIT_A;
                            end
                        end
                        
                        WAIT_B3: begin
                            if (current_char == 8'd98) begin  // 'b'
                                pattern_found <= 8'd1;  // Found 'abbb'
                                pattern_state <= WAIT_A;
                            else begin
                                pattern_state <= WAIT_A;
                            end
                        end
                        
                        default: pattern_state <= WAIT_A;
                    endcase
                    
                    // Move to next character
                    if (index < length - 1) begin
                        index <= index + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                    
                    // Early termination if pattern found
                    if (pattern_found) begin
                        state <= DONE_STATE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= pattern_found;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule